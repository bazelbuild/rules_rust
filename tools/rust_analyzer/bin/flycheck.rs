//! On-save flycheck wrapper invoked by rust-analyzer.
//!
//! rust-analyzer's flycheck runnable spawns this with the saved file's
//! owning Bazel label and (optionally) the saved file path. We then:
//!
//!   1. Invoke `bazel build <label>` with rustc diagnostics turned on and
//!      `--build_event_json_file=<tmp>` so BEP can tell us where rustc
//!      wrote its JSON output.
//!   2. Parse BEP for the `rustc_output` output group, collecting every
//!      `.rustc-output` artifact produced by the build (one per rust
//!      action — bin, lib, test compilations are all separate).
//!   3. Concatenate the JSON contents to stdout for rust-analyzer to
//!      render as inline diagnostics.
//!
//! `--keep_going` keeps Bazel building even when rustc emits errors so all
//! diagnostics surface in one pass. The wrapper always emits whatever
//! `.rustc-output` files exist and forwards Bazel's exit code so
//! rust-analyzer can distinguish "build succeeded" from "build itself
//! failed" (e.g. BUILD-file syntax error).

use std::{
    env, fs,
    io::{self, Write},
    process::{Command, ExitCode},
};

use anyhow::{Context, Result};
use camino::{Utf8Path, Utf8PathBuf};
use clap::Parser;
use gen_rust_project_lib::{
    bep, install_dir, user_config, ToolchainInfoSidecar, TOOLCHAIN_INFO_SIDECAR,
};
use serde_json::Value;

#[derive(Parser, Debug)]
#[command(about = "rust-analyzer flycheck wrapper backed by `bazel build`")]
struct Args {
    /// Bazel label of the crate whose owning file rust-analyzer just saved.
    /// Required in "runnable mode" (invoked from rust-project.json's
    /// Flycheck runnable, where discover baked in the label). Omitted
    /// in "override mode" (invoked from `check.overrideCommand`) —
    /// pass `--saved-file <path>` instead and flycheck derives the
    /// label via the sidecar map or a `bazel query`.
    label: Option<String>,

    /// The file rust-analyzer just saved. Positional form for runnable
    /// mode (`<label> <saved_file>`). Ignored when `--saved-file` is set.
    #[clap(default_value = "")]
    saved_file: String,

    /// Saved file for override mode (invoked from RA's
    /// `check.overrideCommand`, which passes only `$saved_file` — no
    /// label). Mutually exclusive with the positional `label`.
    #[clap(long = "saved-file", conflicts_with = "label")]
    saved_file_arg: Option<Utf8PathBuf>,

    /// Path to the bazel binary.
    #[clap(long, default_value = "bazel")]
    bazel: Utf8PathBuf,

    /// Bazel `--output_user_root` for the flycheck server. Overrides
    /// the default (see [`default_output_user_root`]).
    #[clap(long)]
    output_user_root: Option<Utf8PathBuf>,
}

fn main() -> ExitCode {
    env_logger::init();
    match run() {
        Ok(code) => ExitCode::from(code),
        Err(e) => {
            eprintln!("flycheck: {e:#}");
            ExitCode::from(1)
        }
    }
}

fn run() -> Result<u8> {
    let args = Args::parse();

    let launcher_dir = install_dir()?;
    let sidecar = load_toolchain_info(&launcher_dir);
    let workspace = workspace_dir(sidecar.as_ref().and_then(|s| s.workspace.as_deref()))?;

    // Runnable mode: label is positional. Override mode: derive it
    // from `--saved-file` via sidecar (fast) or `bazel query` (slow).
    let label = match (args.label.as_deref(), args.saved_file_arg.as_deref()) {
        (Some(label), _) => label.to_owned(),
        (None, Some(saved_file)) => {
            resolve_label_for(&args.bazel, &workspace, sidecar.as_ref(), saved_file)?
        }
        (None, None) => {
            anyhow::bail!("either a positional Bazel label or `--saved-file <path>` is required");
        }
    };

    let temp_dir = Utf8PathBuf::try_from(env::temp_dir()).context("$TMPDIR was not valid UTF-8")?;
    let bep_path = temp_dir.join(format!("flycheck_bep_{}.json", std::process::id()));
    let _bep_cleanup = scopeguard(bep_path.clone());

    let user = user_config::load(&launcher_dir);

    // Dedicated `--output_user_root` for the inner `bazel build` so
    // its `--error_format=json` doesn't thrash the primary Bazel
    // server's analysis cache. Precedence: CLI > user_config > default.
    let output_user_root = match args.output_user_root.clone() {
        Some(p) => p,
        None => match user.output_user_root.clone() {
            Some(p) => p,
            None => default_output_user_root(&workspace)?,
        },
    };
    std::fs::create_dir_all(&output_user_root)
        .with_context(|| format!("creating output_user_root {output_user_root}"))?;

    let mut cmd = Command::new(args.bazel.as_str());
    cmd.current_dir(&workspace)
        // Clear env vars leaked from the outer `bazel run` so the
        // nested client rediscovers the workspace from cwd.
        .env_remove("BAZELISK_SKIP_WRAPPER")
        .env_remove("BUILD_WORKING_DIRECTORY")
        .env_remove("BUILD_WORKSPACE_DIRECTORY")
        // `--output_user_root` is a STARTUP option, must precede `build`.
        .arg(format!("--output_user_root={output_user_root}"))
        .arg("build")
        .arg(&label)
        // Flags below use the apparent `@rules_rust` name (not a
        // compile-time `ASPECT_REPOSITORY`) — `ASPECT_REPOSITORY`
        // resolves to empty when built inside rules_rust, which
        // produces bare `--//rust/settings:...` and only works when
        // the outer bazel invocation is IN rules_rust.
        //
        // `error_format=json` makes rustc emit machine-readable
        // diagnostics; without it the `.rustc-output` files are
        // pre-rendered ANSI strings that RA can't parse.
        .arg("--@rules_rust//rust/settings:error_format=json")
        .arg("--@rules_rust//rust/settings:rustc_output_diagnostics=true")
        .arg(format!("--output_groups=+{}", bep::RUSTC_OUTPUT_GROUP))
        .arg("--keep_going")
        .arg(format!("--build_event_json_file={bep_path}"));
    if user.clippy {
        // `clippy_output_diagnostics=true` gates the aspect writing
        // JSON to the declared `.clippy.diagnostics` file (vs a
        // marker), exposed via the `clippy_output` group.
        cmd.arg("--aspects=@rules_rust//rust:defs.bzl%rust_clippy_aspect")
            .arg("--@rules_rust//rust/settings:clippy_output_diagnostics=true")
            .arg(format!("--output_groups=+{}", bep::CLIPPY_OUTPUT_GROUP));
    }
    let status = cmd
        .status()
        .with_context(|| format!("invoking {}", args.bazel))?;

    let mut diagnostic_files = match bep::parse_action_stderr_paths(&bep_path) {
        Ok(paths) => paths,
        Err(e) => {
            eprintln!("flycheck: parsing BEP failed: {e:#}");
            Vec::new()
        }
    };
    if user.clippy {
        // Additive: clippy's JSON goes to the declared
        // `.clippy.diagnostics` file (exposed via `clippy_output`),
        // not stderr, when `clippy_output_diagnostics=true`.
        //
        // `parse_output_group_paths` needs flycheck's OWN Bazel exec
        // root to resolve BEP-relative paths (rules_rust#4130).
        match bazel_info_execution_root(&args.bazel, &output_user_root)
            .and_then(|er| bep::parse_output_group_paths(&bep_path, bep::CLIPPY_OUTPUT_GROUP, &er))
        {
            Ok(paths) => diagnostic_files.extend(paths),
            Err(e) => eprintln!("flycheck: parsing clippy_output group failed: {e:#}"),
        }
    }

    let sysroot_src = sidecar.as_ref().map(|s| s.sysroot_src.as_path());
    emit_diagnostics(&diagnostic_files, &workspace, sysroot_src)?;

    // Forward Bazel's exit code so RA can distinguish "build with
    // diagnostics" from "build tool broke".
    Ok(status.code().unwrap_or(1) as u8)
}

/// Read the sidecar written by discover. Missing / malformed → `None`;
/// flycheck falls back to its slow paths.
fn load_toolchain_info(launcher_dir: &Utf8Path) -> Option<ToolchainInfoSidecar> {
    let path = launcher_dir.join(TOOLCHAIN_INFO_SIDECAR);
    let bytes = match fs::read(&path) {
        Ok(b) => b,
        Err(e) => {
            log::info!(
                "toolchain_info sidecar: {path}: {e} — falling back to cwd/current defaults"
            );
            return None;
        }
    };
    match serde_json::from_slice::<ToolchainInfoSidecar>(&bytes) {
        Ok(s) => Some(s),
        Err(e) => {
            log::warn!("toolchain_info sidecar: parsing {path}: {e}");
            None
        }
    }
}

/// Stream JSON rustc diagnostics from each action-stderr file to
/// stdout, rewriting `file_name` fields to absolute workspace paths
/// (rustc emits them relative to the exec root; RA otherwise resolves
/// them against the saved file's directory and produces nonsense).
///
/// Non-JSON lines (sandbox warnings, env dumps) pass through so we
/// don't silently swallow an unrecognized format.
fn emit_diagnostics(
    files: &[Utf8PathBuf],
    workspace: &Utf8Path,
    sysroot_src: Option<&Utf8Path>,
) -> Result<()> {
    let stdout = io::stdout();
    let mut out = stdout.lock();
    for path in files {
        let content = match fs::read_to_string(path) {
            Ok(c) => c,
            Err(e) => {
                log::warn!("could not read {path}: {e}");
                continue;
            }
        };
        for line in content.lines() {
            let trimmed = line.trim_start();
            if !trimmed.starts_with('{') {
                continue;
            }
            match serde_json::from_str::<Value>(trimmed) {
                Ok(mut value) => {
                    rewrite_file_names(&mut value, workspace, sysroot_src);
                    serde_json::to_writer(&mut out, &value)
                        .context("writing rewritten rustc JSON to stdout")?;
                    out.write_all(b"\n").context("writing newline to stdout")?;
                }
                Err(_) => {
                    // Not JSON — pass through unmodified.
                    out.write_all(line.as_bytes())
                        .context("passing through non-JSON line to stdout")?;
                    out.write_all(b"\n").context("writing newline to stdout")?;
                }
            }
        }
    }
    out.flush().context("flushing stdout")?;
    Ok(())
}

/// Replace `/rustc/<40 hex>/library/` in `input` with `<sysroot_src>/`.
/// Returns `None` when no substitution happened (common) so the caller
/// skips the allocation.
fn substitute_rustc_stdlib(input: &str, sysroot_src: &Utf8Path) -> Option<String> {
    if !input.contains("/rustc/") {
        return None;
    }
    let needle = "/rustc/";
    const SHA_LEN: usize = 40;
    const LIBRARY_SEP: &str = "/library/";

    let mut out = String::with_capacity(input.len());
    let mut cursor = 0;
    let mut replaced = false;
    while let Some(rel) = input[cursor..].find(needle) {
        out.push_str(&input[cursor..cursor + rel]);
        let after_prefix = &input[cursor + rel + needle.len()..];
        let matched = after_prefix
            .get(..SHA_LEN)
            .filter(|sha| sha.bytes().all(|b| b.is_ascii_hexdigit()))
            .and_then(|_| after_prefix.get(SHA_LEN..))
            .and_then(|rest| rest.strip_prefix(LIBRARY_SEP));
        if let Some(tail) = matched {
            out.push_str(sysroot_src.as_str());
            out.push('/');
            cursor = input.len() - tail.len();
            replaced = true;
        } else {
            out.push_str(needle);
            cursor += rel + needle.len();
        }
    }
    out.push_str(&input[cursor..]);
    replaced.then_some(out)
}

/// Rewrite rustc-diagnostic paths in place:
///  * Relative `file_name` → absolute under `workspace`.
///  * `/rustc/<sha>/library/…` → `<sysroot_src>/…` in `file_name`,
///    `rendered`, and `explanation` strings. RA extracts paths from
///    `rendered` for VFS lookup, so rewriting only `file_name` isn't
///    enough.
fn rewrite_file_names(value: &mut Value, workspace: &Utf8Path, sysroot_src: Option<&Utf8Path>) {
    let Value::Object(map) = value else {
        if let Value::Array(items) = value {
            for item in items.iter_mut() {
                rewrite_file_names(item, workspace, sysroot_src);
            }
        }
        return;
    };
    for (key, child) in map.iter_mut() {
        match key.as_str() {
            "file_name" => {
                if let Value::String(s) = child {
                    if !s.is_empty() && !std::path::Path::new(s).is_absolute() {
                        *s = workspace.join(&*s).to_string();
                    }
                    if let (Some(sr), Value::String(s)) = (sysroot_src, &mut *child) {
                        if let Some(replaced) = substitute_rustc_stdlib(s, sr) {
                            *s = replaced;
                        }
                    }
                }
            }
            "rendered" | "explanation" => {
                if let (Some(sr), Value::String(s)) = (sysroot_src, child) {
                    if let Some(replaced) = substitute_rustc_stdlib(s, sr) {
                        *s = replaced;
                    }
                }
            }
            _ => rewrite_file_names(child, workspace, sysroot_src),
        }
    }
}

/// Precedence: `$BUILD_WORKSPACE_DIRECTORY` → sidecar's `workspace`
/// (correct when RA spawns flycheck with cwd inside a package) →
/// `env::current_dir()`.
fn workspace_dir(sidecar_workspace: Option<&Utf8Path>) -> Result<Utf8PathBuf> {
    if let Ok(dir) = env::var("BUILD_WORKSPACE_DIRECTORY") {
        return Utf8PathBuf::try_from(std::path::PathBuf::from(dir))
            .context("BUILD_WORKSPACE_DIRECTORY was not valid UTF-8");
    }
    if let Some(dir) = sidecar_workspace {
        return Ok(dir.to_path_buf());
    }
    let cwd = env::current_dir().context("current_dir")?;
    Utf8PathBuf::try_from(cwd).context("current_dir was not valid UTF-8")
}

/// Default location for flycheck's dedicated `--output_user_root`,
/// next to Bazel's own user cache root. Must live outside the
/// workspace — Bazel 8+ errors when a repo_contents_cache falls inside
/// the main repo. Hashed by workspace path so two projects don't share
/// a flycheck server.
fn default_output_user_root(workspace: &Utf8Path) -> Result<Utf8PathBuf> {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};

    let mut hasher = DefaultHasher::new();
    workspace.as_str().hash(&mut hasher);
    let workspace_hash = format!("{:016x}", hasher.finish());

    let cache_root = user_cache_dir()?.join("bazel").join("rules_rust_flycheck");
    Ok(cache_root.join(workspace_hash))
}

/// Best-effort platform cache dir. Uses `$XDG_CACHE_HOME` when set;
/// otherwise `~/.cache` on Linux, `~/Library/Caches` on macOS,
/// `%LOCALAPPDATA%` on Windows.
fn user_cache_dir() -> Result<Utf8PathBuf> {
    if let Ok(dir) = env::var("XDG_CACHE_HOME") {
        if !dir.is_empty() {
            return Ok(Utf8PathBuf::from(dir));
        }
    }
    #[cfg(target_os = "macos")]
    {
        let home = env::var("HOME").context("HOME not set")?;
        Ok(Utf8PathBuf::from(home).join("Library").join("Caches"))
    }
    #[cfg(target_os = "windows")]
    {
        let dir = env::var("LOCALAPPDATA").context("LOCALAPPDATA not set")?;
        Ok(Utf8PathBuf::from(dir))
    }
    #[cfg(not(any(target_os = "macos", target_os = "windows")))]
    {
        let home = env::var("HOME").context("HOME not set")?;
        Ok(Utf8PathBuf::from(home).join(".cache"))
    }
}

/// Derive the Bazel label for a saved file (override mode). Fast
/// path: sidecar's `file_labels` map (root modules). Fallback:
/// `bazel query` scoped to the nearest `BUILD.bazel`.
fn resolve_label_for(
    bazel: &Utf8Path,
    workspace: &Utf8Path,
    sidecar: Option<&ToolchainInfoSidecar>,
    saved_file: &Utf8Path,
) -> Result<String> {
    if let Some(sc) = sidecar {
        if let Some(label) = sc.file_labels.get(saved_file) {
            return Ok(label.clone());
        }
    }
    query_label_for(bazel, workspace, saved_file)
}

/// `bazel query 'attr(srcs, "<file>", //<package>:*)'` scoped to the
/// nearest `BUILD.bazel`. Returns the first match — if a file belongs
/// to several targets, any is correct.
fn query_label_for(
    bazel: &Utf8Path,
    workspace: &Utf8Path,
    saved_file: &Utf8Path,
) -> Result<String> {
    let file_rel = saved_file
        .strip_prefix(workspace)
        .with_context(|| format!("saved file {saved_file} is not under workspace {workspace}"))?;
    let package = find_owning_package(workspace, file_rel).with_context(|| {
        format!("no BUILD.bazel found above {saved_file} — is this file part of a Bazel target?")
    })?;
    let file_basename = file_rel
        .file_name()
        .with_context(|| format!("saved file {saved_file} has no file name"))?;
    let pattern = format!("//{package}:{file_basename}");
    let query = format!("attr(srcs, {pattern:?}, //{package}:*)");
    let output = Command::new(bazel.as_str())
        .current_dir(workspace)
        .arg("query")
        .arg("--output=label")
        .arg(&query)
        .output()
        .with_context(|| format!("invoking {bazel} query {query}"))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("bazel query failed for {query}: {stderr}");
    }
    String::from_utf8(output.stdout)
        .context("bazel query output not UTF-8")?
        .lines()
        .find(|l| !l.is_empty())
        .map(str::to_owned)
        .with_context(|| format!("bazel query returned no targets for {pattern}"))
}

/// Walk up looking for `BUILD.bazel` or `BUILD`. Returns the
/// workspace-relative package path.
fn find_owning_package(workspace: &Utf8Path, file_rel: &Utf8Path) -> Option<Utf8PathBuf> {
    let mut dir = file_rel.parent()?;
    loop {
        for name in ["BUILD.bazel", "BUILD"] {
            if workspace.join(dir).join(name).is_file() {
                return Some(dir.to_path_buf());
            }
        }
        dir = dir.parent()?;
    }
}

/// `bazel info execution_root` against the flycheck server. Its exec
/// root differs from discover's (different `--output_user_root`), so
/// we can't reuse the sidecar's value.
fn bazel_info_execution_root(bazel: &Utf8Path, output_user_root: &Utf8Path) -> Result<Utf8PathBuf> {
    let output = Command::new(bazel.as_str())
        .arg(format!("--output_user_root={output_user_root}"))
        .arg("info")
        .arg("execution_root")
        .output()
        .with_context(|| format!("invoking {bazel} info execution_root"))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("bazel info execution_root failed: {stderr}");
    }
    let root = String::from_utf8(output.stdout)
        .context("bazel info execution_root output not UTF-8")?
        .trim()
        .to_owned();
    Ok(Utf8PathBuf::from(root))
}

/// Best-effort cleanup of the temporary BEP file.
fn scopeguard(path: Utf8PathBuf) -> impl Drop {
    struct Guard(Utf8PathBuf);
    impl Drop for Guard {
        fn drop(&mut self) {
            let _ = fs::remove_file(&self.0);
        }
    }
    Guard(path)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn relative_file_names_become_absolute() {
        let workspace = Utf8Path::new("/abs/ws");
        let mut v = json!({
            "$message_type": "diagnostic",
            "spans": [
                {"file_name": "util/label/label.rs", "byte_start": 0},
                {"file_name": "/already/absolute.rs", "byte_start": 1},
                {
                    "file_name": "src/lib.rs",
                    "expansion": {
                        "span": {"file_name": "src/macro.rs"}
                    }
                }
            ],
            "children": [
                {"spans": [{"file_name": "src/inner.rs"}]}
            ]
        });
        rewrite_file_names(&mut v, workspace, None);
        // Join via Utf8Path so the test passes on Windows too.
        let expect = |rel: &str| Value::String(workspace.join(rel).to_string());
        let spans = v["spans"].as_array().unwrap();
        assert_eq!(spans[0]["file_name"], expect("util/label/label.rs"));
        assert_eq!(spans[1]["file_name"], json!("/already/absolute.rs"));
        assert_eq!(spans[2]["file_name"], expect("src/lib.rs"));
        assert_eq!(
            spans[2]["expansion"]["span"]["file_name"],
            expect("src/macro.rs"),
        );
        assert_eq!(
            v["children"][0]["spans"][0]["file_name"],
            expect("src/inner.rs"),
        );
    }

    #[test]
    fn empty_file_name_is_left_alone() {
        let workspace = Utf8Path::new("/ws");
        let mut v = json!({"spans": [{"file_name": ""}]});
        rewrite_file_names(&mut v, workspace, None);
        assert_eq!(v["spans"][0]["file_name"], json!(""));
    }

    #[test]
    fn rustc_stdlib_remap_gets_replaced_with_sysroot_src() {
        let workspace = Utf8Path::new("/ws");
        let sysroot_src = Utf8Path::new("/toolchain/lib/rustlib/src/library");
        let mut v = json!({
            "spans": [
                {"file_name": "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860/library/core/src/result.rs"},
                {"file_name": "/rustc/notasha/library/x.rs"},
                {"file_name": "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860/bin/rustc.rs"},
            ]
        });
        rewrite_file_names(&mut v, workspace, Some(sysroot_src));
        let spans = v["spans"].as_array().unwrap();
        // Impl always emits forward slashes at the substitution boundary
        // (rustc's stdlib remap is `/`-separated on every platform).
        assert_eq!(
            spans[0]["file_name"],
            json!(format!("{sysroot_src}/core/src/result.rs")),
        );
        assert_eq!(spans[1]["file_name"], json!("/rustc/notasha/library/x.rs"));
        assert_eq!(
            spans[2]["file_name"],
            json!("/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860/bin/rustc.rs"),
        );
    }

    #[test]
    fn rustc_stdlib_remap_left_alone_when_sysroot_src_missing() {
        // No sidecar → no substitution; RA logs its own VFS miss.
        let workspace = Utf8Path::new("/ws");
        let mut v = json!({
            "spans": [{"file_name": "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860/library/core/src/result.rs"}]
        });
        rewrite_file_names(&mut v, workspace, None);
        assert_eq!(
            v["spans"][0]["file_name"],
            json!("/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860/library/core/src/result.rs"),
        );
    }

    #[test]
    fn rustc_stdlib_remap_gets_replaced_inside_rendered_field() {
        // RA parses paths out of `rendered` for VFS lookup — rewriting
        // only `file_name` isn't enough.
        let workspace = Utf8Path::new("/ws");
        let sysroot_src = Utf8Path::new("/toolchain/lib/rustlib/src/library");
        let mut v = json!({
            "rendered": "note: tuple variant defined here\n  --> /rustc/59807616e1fa2540724bfbac14d7976d7e4a3860/library/core/src/result.rs:561:4\n\n"
        });
        rewrite_file_names(&mut v, workspace, Some(sysroot_src));
        assert_eq!(
            v["rendered"],
            json!("note: tuple variant defined here\n  --> /toolchain/lib/rustlib/src/library/core/src/result.rs:561:4\n\n"),
        );
    }

    #[test]
    fn multiple_rustc_prefixes_all_rewritten() {
        let sysroot_src = Utf8Path::new("/toolchain/src/library");
        let out = substitute_rustc_stdlib(
            "at /rustc/59807616e1fa2540724bfbac14d7976d7e4a3860/library/core/mod.rs and /rustc/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/library/alloc/vec.rs done",
            sysroot_src,
        )
        .unwrap();
        assert_eq!(
            out,
            "at /toolchain/src/library/core/mod.rs and /toolchain/src/library/alloc/vec.rs done"
        );
    }

    #[test]
    fn workspace_dir_prefers_env_over_sidecar() {
        // env::set_var isn't safe under parallel tests, so call twice:
        // env absent → sidecar wins; env present → env wins.
        struct Guard;
        impl Drop for Guard {
            fn drop(&mut self) {
                env::remove_var("BUILD_WORKSPACE_DIRECTORY");
            }
        }
        let _g = Guard;

        let sidecar_ws = Utf8Path::new("/from/sidecar");
        env::remove_var("BUILD_WORKSPACE_DIRECTORY");
        assert_eq!(workspace_dir(Some(sidecar_ws)).unwrap(), sidecar_ws);

        env::set_var("BUILD_WORKSPACE_DIRECTORY", "/from/env");
        assert_eq!(
            workspace_dir(Some(sidecar_ws)).unwrap(),
            Utf8Path::new("/from/env"),
        );
    }

    #[test]
    fn substitute_rustc_stdlib_leaves_non_stdlib_prefixes_alone() {
        let sysroot_src = Utf8Path::new("/toolchain/src/library");
        for input in [
            "/rustc/notasha/library/x.rs",
            "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860/bin/rustc.rs",
            "/rustc/",
        ] {
            assert!(
                substitute_rustc_stdlib(input, sysroot_src).is_none(),
                "expected no rewrite for {input}"
            );
        }
    }
}
