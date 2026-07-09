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
use gen_rust_project_lib::{bep, install_dir, user_config};
use serde_json::Value;

#[derive(Parser, Debug)]
#[command(about = "rust-analyzer flycheck wrapper backed by `bazel build`")]
struct Args {
    /// Bazel label of the crate whose owning file rust-analyzer just saved.
    label: String,

    /// The file rust-analyzer just saved. Currently unused — we check the
    /// whole crate, matching cargo check's per-crate semantics. Accepted
    /// so the runnable template's `{saved_file}` placeholder has somewhere
    /// to land without errors.
    #[clap(default_value = "")]
    saved_file: String,

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

    let workspace = workspace_dir()?;

    let temp_dir = Utf8PathBuf::try_from(env::temp_dir()).context("$TMPDIR was not valid UTF-8")?;
    let bep_path = temp_dir.join(format!("flycheck_bep_{}.json", std::process::id()));
    let _bep_cleanup = scopeguard(bep_path.clone());

    // Per-user preferences live in `<launcher_dir>/user_config.json`.
    // Clippy mode is a per-user opt-in there — the shared discover
    // command doesn't decide it — so we consult the config on every
    // save rather than baking the choice into flycheck's argv.
    let user = user_config::load(&install_dir()?);

    // Dedicated `--output_user_root` for the inner `bazel build` so
    // its `--error_format=json` / `--rustc_output_diagnostics=true`
    // don't thrash the user's primary Bazel server's analysis cache.
    // Precedence: CLI flag > user_config > platform default. The
    // default lives next to Bazel's own output roots (~/.cache/bazel
    // on Linux) — not inside the workspace, which Bazel 8+ rejects
    // for repo_contents_cache.
    let output_user_root = match args.output_user_root.clone() {
        Some(p) => p,
        None => match user.output_user_root.clone() {
            Some(p) => p,
            None => default_output_user_root(&workspace)?,
        },
    };
    std::fs::create_dir_all(&output_user_root)
        .with_context(|| format!("creating output_user_root {output_user_root}"))?;

    // Assemble the bazel command. Clippy mode adds the aspect and
    // its diagnostics output group on top of the base build flags.
    let mut cmd = Command::new(args.bazel.as_str());
    cmd.current_dir(&workspace)
        // BUILD_WORKSPACE_DIRECTORY / BUILD_WORKING_DIRECTORY leak in from
        // the outer `bazel run` invocation and would confuse the nested
        // bazel client; clear them so the nested call rediscovers the
        // workspace from cwd.
        .env_remove("BAZELISK_SKIP_WRAPPER")
        .env_remove("BUILD_WORKING_DIRECTORY")
        .env_remove("BUILD_WORKSPACE_DIRECTORY")
        // `--output_user_root` is a STARTUP option — must precede the
        // command (`build`). Bazel rejects it elsewhere.
        .arg(format!("--output_user_root={output_user_root}"))
        .arg("build")
        .arg(&args.label)
        // `error_format=json` makes rustc emit machine-readable diagnostics
        // and tells process_wrapper to capture them verbatim; without it the
        // `.rustc-output` files are pre-rendered ANSI strings that
        // rust-analyzer can't parse.
        .arg("--@rules_rust//rust/settings:error_format=json")
        .arg("--@rules_rust//rust/settings:rustc_output_diagnostics=true")
        .arg(format!("--output_groups=+{}", bep::RUSTC_OUTPUT_GROUP))
        .arg("--keep_going")
        .arg(format!("--build_event_json_file={bep_path}"));
    if user.clippy {
        cmd.arg("--aspects=@rules_rust//rust:defs.bzl%rust_clippy_aspect")
            // Diagnostics go to a declared `.clippy.diagnostics` file per
            // crate, exposed via the `clippy_output` output group. Without
            // this flag the aspect only emits a marker file, so we'd have
            // nowhere to read clippy JSON from.
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
        // Additive: the `clippy_output` group holds `.clippy.diagnostics`
        // files that action-stderr harvesting doesn't cover (clippy's JSON
        // goes to the declared file, not stderr, when
        // `clippy_output_diagnostics=true`).
        //
        // `parse_output_group_paths` needs the exec root to resolve BEP-
        // relative paths (per rules_rust#4130). Fetching inline via
        // `bazel info` — we already run bazel in this process, so one
        // extra info call adds negligible latency to a save.
        match bazel_info_execution_root(&args.bazel, &output_user_root)
            .and_then(|er| bep::parse_output_group_paths(&bep_path, bep::CLIPPY_OUTPUT_GROUP, &er))
        {
            Ok(paths) => diagnostic_files.extend(paths),
            Err(e) => eprintln!("flycheck: parsing clippy_output group failed: {e:#}"),
        }
    }

    emit_diagnostics(&diagnostic_files, &workspace)?;

    // Forward Bazel's exit code so rust-analyzer can tell apart "build
    // succeeded with diagnostics" from "build tool itself broke".
    Ok(status.code().unwrap_or(1) as u8)
}

/// Stream each action-stderr file to stdout, keeping only lines that look
/// like rustc JSON messages. For each diagnostic line, recursively rewrite
/// `file_name` fields to absolute paths anchored at the workspace root —
/// rustc emits them relative to the Bazel exec root (structurally the
/// workspace layout), and rust-analyzer otherwise tries to resolve them
/// relative to the saved file's directory, producing nonsense like
/// `<workspace>/util/label/util/label/label.rs`.
///
/// Non-JSON lines (sandbox warnings, env dumps) are dropped so the LSP
/// only sees parseable rustc messages.
///
/// Errors writing to stdout bubble up — rust-analyzer parses our stdout
/// as the diagnostic stream, so silently dropping writes would surface as
/// "no squiggles after save" with no clue why. A failed write is almost
/// always "rust-analyzer closed the pipe" which is also worth surfacing
/// (the editor is gone; flycheck has no consumer).
fn emit_diagnostics(files: &[Utf8PathBuf], workspace: &Utf8Path) -> Result<()> {
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
                    absolutize_file_names(&mut value, workspace);
                    serde_json::to_writer(&mut out, &value)
                        .context("writing rewritten rustc JSON to stdout")?;
                    out.write_all(b"\n").context("writing newline to stdout")?;
                }
                Err(_) => {
                    // Not strict JSON — pass through unmodified so we don't
                    // silently drop a diagnostic format we don't recognize.
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

/// Walk a rustc-diagnostic JSON value and rewrite every `"file_name"`
/// string field to an absolute path under `workspace`. file_name appears
/// in `spans[*].file_name`, in nested `expansion.span.file_name` chains
/// for macro expansions, and inside `children[*].spans[*]…` for
/// sub-diagnostics — recursion catches all of them.
fn absolutize_file_names(value: &mut Value, workspace: &Utf8Path) {
    match value {
        Value::Object(map) => {
            for (key, child) in map.iter_mut() {
                if key == "file_name" {
                    if let Value::String(s) = child {
                        if !s.is_empty() && !std::path::Path::new(s).is_absolute() {
                            *s = workspace.join(&*s).to_string();
                        }
                    }
                } else {
                    absolutize_file_names(child, workspace);
                }
            }
        }
        Value::Array(items) => {
            for item in items.iter_mut() {
                absolutize_file_names(item, workspace);
            }
        }
        _ => {}
    }
}

fn workspace_dir() -> Result<Utf8PathBuf> {
    if let Ok(dir) = env::var("BUILD_WORKSPACE_DIRECTORY") {
        return Utf8PathBuf::try_from(std::path::PathBuf::from(dir))
            .context("BUILD_WORKSPACE_DIRECTORY was not valid UTF-8");
    }
    let cwd = env::current_dir().context("current_dir")?;
    Utf8PathBuf::try_from(cwd).context("current_dir was not valid UTF-8")
}

/// Default location for flycheck's dedicated `--output_user_root`,
/// sitting next to Bazel's own user cache root
/// (`~/.cache/bazel/_bazel_<user>/…` on Linux, `~/Library/Caches/bazel/…`
/// on macOS). Living outside the workspace matters on Bazel 8+, which
/// errors when a repo_contents_cache falls inside the main repo — the
/// old default (`<launcher_dir>/output_user_root`) always did.
///
/// A per-workspace subdirectory (hashed workspace path) keeps two
/// projects from sharing a flycheck server.
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

/// Query `bazel info execution_root` against the flycheck server (same
/// `--output_user_root` we used for the build). Only invoked on save
/// when clippy is enabled — see the call site.
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
        absolutize_file_names(&mut v, workspace);
        // Construct expected paths via Utf8Path::join so the test passes on
        // both POSIX and Windows (Windows uses `\` as the separator).
        let expect = |rel: &str| Value::String(workspace.join(rel).to_string());
        let spans = v["spans"].as_array().unwrap();
        assert_eq!(spans[0]["file_name"], expect("util/label/label.rs"));
        // Absolute paths must be left untouched.
        assert_eq!(spans[1]["file_name"], json!("/already/absolute.rs"));
        assert_eq!(spans[2]["file_name"], expect("src/lib.rs"));
        // Recursive descent reaches the expansion span.
        assert_eq!(
            spans[2]["expansion"]["span"]["file_name"],
            expect("src/macro.rs"),
        );
        // And children's spans.
        assert_eq!(
            v["children"][0]["spans"][0]["file_name"],
            expect("src/inner.rs"),
        );
    }

    #[test]
    fn empty_file_name_is_left_alone() {
        let workspace = Utf8Path::new("/ws");
        let mut v = json!({"spans": [{"file_name": ""}]});
        absolutize_file_names(&mut v, workspace);
        assert_eq!(v["spans"][0]["file_name"], json!(""));
    }
}
