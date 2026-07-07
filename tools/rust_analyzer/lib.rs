mod aquery;
pub mod bep;
mod cache;
mod rust_project;

use std::{collections::BTreeMap, fs, process::Command};

use anyhow::{bail, Context};
use camino::{Utf8Path, Utf8PathBuf};
use rust_project::RustProject;
pub use rust_project::{
    assemble_rust_project, diagnose, format_diagnostics, AssemblyDiagnostics, DiscoverProject,
    RustAnalyzerArg,
};
use serde::{de::DeserializeOwned, Deserialize};

pub use aquery::{consolidate_crate_specs, CrateSpec};

pub const WORKSPACE_ROOT_FILE_NAMES: &[&str] =
    &["MODULE.bazel", "REPO.bazel", "WORKSPACE.bazel", "WORKSPACE"];

pub const BUILD_FILE_NAMES: &[&str] = &["BUILD.bazel", "BUILD"];

/// Shared between the setup-side install and the
/// `rust_project.rs` flycheck-runnable emitter so the two can't
/// drift on extension handling.
///
/// `.exe` on every platform is deliberate: Node spawn (the
/// rust-analyzer VS Code extension's spawner) can't execute
/// extensionless files on Windows without `shell: true`, and POSIX
/// `execve` ignores file extensions — same filename works everywhere.
pub const FLYCHECK_BINARY_FILENAME: &str = "flycheck.exe";

pub const DISCOVER_BINARY_FILENAME: &str = "discover_bazel_rust_project.exe";

/// JSON embedded at compile time. The `:toolchain_info_env` rule
/// (BUILD.bazel) emits the env var through Bazel's path-mapping-aware
/// `Args` machinery; routing the same path through a plain
/// `rustc_env = {"K": "$(execpath …)"}` would miss the path-mapping
/// rewrite under `--experimental_output_paths=strip` and fail to
/// locate the file. Content uses `__OUTPUT_BASE__` / `__WORKSPACE__` /
/// `__EXEC_ROOT__` placeholder tokens substituted at runtime (see
/// `deserialize_with_substitution`).
const TOOLCHAIN_INFO_RAW: &str = include_str!(env!("RUST_ANALYZER_TOOLCHAIN_JSON"));

/// `dirname(current_exe())` — used by discover/flycheck to find their
/// per-install sibling files (cache dir, output_user_root). Uses
/// `current_exe` rather than `argv[0]` because the install is a real
/// `fs::copy`: the runfiles crate's argv[0]-first policy doesn't
/// apply post-install.
pub fn install_dir() -> anyhow::Result<Utf8PathBuf> {
    let exe = std::env::current_exe().context("locating current_exe")?;
    let parent = exe
        .parent()
        .with_context(|| format!("current_exe has no parent: {}", exe.display()))?;
    Utf8PathBuf::from_path_buf(parent.to_path_buf())
        .map_err(|p| anyhow::anyhow!("install dir is not valid UTF-8: {}", p.display()))
}

#[allow(clippy::too_many_arguments)]
pub fn generate_rust_project(
    bazel: &Utf8Path,
    output_base: &Utf8Path,
    workspace: &Utf8Path,
    execution_root: &Utf8Path,
    bazel_startup_options: &[String],
    bazel_args: &[String],
    rules_rust_name: &str,
    targets: &[String],
) -> anyhow::Result<RustProject> {
    // Materialize per-crate spec files via the aspect, with Bazel emitting BEP
    // so we can discover them as a side-effect of the build. This replaces a
    // separate `bazel aquery` round-trip — that query is the dominant cost in
    // a large monorepo (O(action graph) every invocation, never cached) and
    // dropping it is the main perf win of this path.
    let bep_file = output_base.join(format!("rules_rust_ra_bep_{}.json", std::process::id()));
    let _bep_cleanup = BepCleanup(bep_file.clone());

    let build = generate_crate_info(
        bazel,
        output_base,
        workspace,
        bazel_startup_options,
        bazel_args,
        rules_rust_name,
        targets,
        &bep_file,
    )?;

    let spec_paths = match bep::parse_spec_paths(&bep_file, execution_root) {
        Ok(paths) => paths,
        // A failed build often means a missing or partial BEP file; surface
        // the build error rather than the downstream parse error.
        Err(_) if !build.success => {
            bail!(
                "bazel build failed and produced no usable output:\n{}",
                build.stderr
            )
        }
        Err(e) => return Err(e).with_context(|| format!("parsing BEP file {bep_file}")),
    };
    if assess_discovery(build.success, spec_paths.len(), &build.stderr)? {
        log::warn!(
            "some targets failed to build; the rust-analyzer project may be \
             incomplete. Run `bazel build //...` to see the errors."
        );
    }
    log::info!("discovered {} crate spec files via BEP", spec_paths.len());

    // Toolchain-info JSON is embedded at compile time — see
    // `TOOLCHAIN_INFO_RAW` (above) for the wiring.
    let toolchain_info_raw = TOOLCHAIN_INFO_RAW;

    // Read every spec file once; the contents feed both the cache key and the
    // consolidate/assemble step on a miss.
    let spec_contents = read_specs(&spec_paths)?;

    let launcher_dir = std::env::var(cache::LAUNCHER_DIR_ENV_VAR).unwrap_or_default();
    let cache_key = cache::compute_key(
        &spec_contents,
        toolchain_info_raw,
        bazel,
        workspace,
        execution_root,
        &launcher_dir,
    );
    if let Some(bytes) = cache::get(workspace, &cache_key)? {
        match serde_json::from_slice::<RustProject>(&bytes) {
            Ok(project) => {
                log::info!("merge cache hit ({cache_key}); skipping assembly");
                return Ok(project);
            }
            Err(e) => {
                // A corrupted entry shouldn't block discovery — log, evict, and
                // fall through to recompute.
                log::warn!("merge cache entry {cache_key} corrupted ({e}); recomputing");
            }
        }
    } else {
        log::info!("merge cache miss ({cache_key}); assembling");
    }

    let toolchain_info: ToolchainInfo =
        deserialize_with_substitution(toolchain_info_raw, output_base, workspace, execution_root)
            .context("parsing embedded toolchain info JSON")?;

    let crate_specs =
        parse_and_consolidate(&spec_contents, output_base, workspace, execution_root)?;

    let project =
        rust_project::assemble_rust_project(bazel, workspace, toolchain_info, &crate_specs)?;

    // Surface dep-graph problems the assembler had to paper over (missing
    // deps, cycles). Each becomes a log::warn (visible as a progress event
    // in rust-analyzer's UI) AND lands in a persistent log file so users
    // can grep after the fact — progress events scroll off the status bar
    // before anyone notices them.
    report_diagnostics(workspace, &crate_specs);

    // Best-effort cache write. Failures are logged but don't fail discovery.
    match serde_json::to_vec(&project) {
        Ok(bytes) => cache::put(workspace, &cache_key, &bytes),
        Err(e) => log::warn!("merge cache: serializing project failed ({e}); not caching"),
    }

    Ok(project)
}

const WARNINGS_LOG_REL: &str = ".vscode/.rules_rust_analyzer/last_warnings.log";

fn report_diagnostics(workspace: &Utf8Path, crate_specs: &std::collections::BTreeSet<CrateSpec>) {
    let diag = rust_project::diagnose(crate_specs);
    let log_path = workspace.join(WARNINGS_LOG_REL);
    if diag.is_empty() {
        // Clear any leftover file from a previous run so absence-of-file is
        // a meaningful "no diagnostics this round" signal.
        let _ = fs::remove_file(&log_path);
        return;
    }
    let report = rust_project::format_diagnostics(&diag);
    for line in report.lines() {
        log::warn!("{line}");
    }
    if let Some(parent) = log_path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if let Err(e) = fs::write(&log_path, &report) {
        log::warn!("could not write {log_path}: {e}");
    }
}

fn read_specs(spec_paths: &[Utf8PathBuf]) -> anyhow::Result<Vec<(Utf8PathBuf, String)>> {
    spec_paths
        .iter()
        .map(|p| {
            let content =
                fs::read_to_string(p).with_context(|| format!("reading crate spec {p}"))?;
            Ok((p.clone(), content))
        })
        .collect()
}

fn parse_and_consolidate(
    spec_contents: &[(Utf8PathBuf, String)],
    output_base: &Utf8Path,
    workspace: &Utf8Path,
    execution_root: &Utf8Path,
) -> anyhow::Result<std::collections::BTreeSet<CrateSpec>> {
    let crate_specs = spec_contents
        .iter()
        .map(|(path, content)| {
            deserialize_with_substitution::<CrateSpec>(
                content,
                output_base,
                workspace,
                execution_root,
            )
            .with_context(|| format!("deserializing crate spec {path}"))
        })
        .collect::<anyhow::Result<Vec<_>>>()?;
    consolidate_crate_specs(crate_specs)
}

/// Best-effort cleanup of the temporary BEP file Bazel wrote.
struct BepCleanup(Utf8PathBuf);
impl Drop for BepCleanup {
    fn drop(&mut self) {
        let _ = fs::remove_file(&self.0);
    }
}

/// Executes `bazel info` to get a map of context information.
pub fn bazel_info(
    bazel: &Utf8Path,
    workspace: Option<&Utf8Path>,
    output_base: Option<&Utf8Path>,
    bazel_startup_options: &[String],
    bazel_args: &[String],
) -> anyhow::Result<BTreeMap<String, String>> {
    let output = bazel_command(bazel, workspace, output_base)
        .args(bazel_startup_options)
        .arg("info")
        .args(bazel_args)
        .output()?;

    if !output.status.success() {
        let status = output.status;
        let stderr = String::from_utf8_lossy(&output.stderr);
        bail!("bazel info failed: ({status:?})\n{stderr}");
    }

    // Extract and parse the output.
    let info_map = String::from_utf8(output.stdout)?
        .trim()
        .split('\n')
        .filter_map(|line| line.split_once(':'))
        .map(|(k, v)| (k.to_owned(), v.trim().to_owned()))
        .collect();

    Ok(info_map)
}

/// Result of the discovery build. With `--keep_going` a non-`success` exit
/// isn't fatal — the caller proceeds if the BEP still yielded specs.
struct DiscoveryBuild {
    success: bool,
    stderr: String,
}

#[allow(clippy::too_many_arguments)]
fn generate_crate_info(
    bazel: &Utf8Path,
    output_base: &Utf8Path,
    workspace: &Utf8Path,
    bazel_startup_options: &[String],
    bazel_args: &[String],
    rules_rust: &str,
    targets: &[String],
    bep_file: &Utf8Path,
) -> anyhow::Result<DiscoveryBuild> {
    log::info!("running bazel build with BEP discovery...");
    log::debug!("Building rust_analyzer_crate_spec files for {:?}", targets);

    let output = bazel_command(bazel, Some(workspace), Some(output_base))
        .args(bazel_startup_options)
        .arg("build")
        .args(bazel_args)
        // Don't let one broken target abort discovery for the whole
        // workspace; the caller decides if the partial result is usable.
        .arg("--keep_going")
        .arg("--norun_validations")
        .arg("--remote_download_all")
        .arg(format!(
            "--aspects={rules_rust}//rust:defs.bzl%rust_analyzer_aspect"
        ))
        .arg("--output_groups=rust_analyzer_crate_spec,rust_generated_srcs,rust_analyzer_proc_macro_dylib,rust_analyzer_src")
        .arg(format!("--build_event_json_file={bep_file}"))
        // Make BEP report URIs whether or not the file lives in the local
        // execution root, so bep.rs has a consistent shape to parse.
        .arg("--build_event_publish_all_actions")
        .args(targets)
        .output()?;

    let success = output.status.success();
    if success {
        log::info!("bazel build finished");
    }

    Ok(DiscoveryBuild {
        success,
        stderr: String::from_utf8_lossy(&output.stderr).into_owned(),
    })
}

/// `Ok(true)` = usable but some targets failed (caller warns); `Ok(false)` =
/// clean; `Err` = nothing usable was produced.
fn assess_discovery(success: bool, spec_count: usize, stderr: &str) -> anyhow::Result<bool> {
    match (success, spec_count) {
        (true, _) => Ok(false),
        (false, 0) => bail!("bazel build failed and produced no crate specs:\n{stderr}"),
        (false, _) => Ok(true),
    }
}

fn bazel_command(
    bazel: &Utf8Path,
    workspace: Option<&Utf8Path>,
    output_base: Option<&Utf8Path>,
) -> Command {
    let mut cmd = Command::new(bazel);

    cmd
        // Switch to the workspace directory if one was provided.
        .current_dir(workspace.unwrap_or(Utf8Path::new(".")))
        .env_remove("BAZELISK_SKIP_WRAPPER")
        .env_remove("BUILD_WORKING_DIRECTORY")
        .env_remove("BUILD_WORKSPACE_DIRECTORY")
        // Set the output_base if one was provided.
        .args(output_base.map(|s| format!("--output_base={s}")));

    cmd
}

fn deserialize_with_substitution<T>(
    content: &str,
    output_base: &Utf8Path,
    workspace: &Utf8Path,
    execution_root: &Utf8Path,
) -> anyhow::Result<T>
where
    T: DeserializeOwned,
{
    let content = content
        .replace("__WORKSPACE__", workspace.as_str())
        .replace("${pwd}", execution_root.as_str())
        .replace("__EXEC_ROOT__", execution_root.as_str())
        .replace("__OUTPUT_BASE__", output_base.as_str());

    serde_json::from_str(&content).context("failed to deserialize after template substitution")
}

/// `rust-analyzer` associates workspaces with buildfiles. Therefore, when it passes in a
/// source file path, we use this function to identify the buildfile the file belongs to.
fn source_file_to_buildfile(file: &Utf8Path) -> anyhow::Result<Utf8PathBuf> {
    // Skip the first element as it's always the full file path.
    file.ancestors()
        .skip(1)
        .flat_map(|dir| BUILD_FILE_NAMES.iter().map(move |build| dir.join(build)))
        .find(|p| p.exists())
        .with_context(|| format!("no buildfile found for {file}"))
}

fn buildfile_to_targets(workspace: &Utf8Path, buildfile: &Utf8Path) -> anyhow::Result<String> {
    log::info!("getting targets for buildfile: {buildfile}");

    let parent_dir = buildfile
        .strip_prefix(workspace)
        .with_context(|| format!("{buildfile} not part of workspace"))?
        .parent();

    let targets = match parent_dir {
        Some(p) if !p.as_str().is_empty() => format!("//{}:all", dir_to_bazel_package(p.as_str())),
        _ => "//...".to_string(),
    };

    Ok(targets)
}

/// Convert a workspace-relative directory path to a Bazel package
/// segment (always `/`-separated).
///
/// On Windows, `Utf8Path::strip_prefix(...).parent()` returns a path
/// with native `\` separators, which Bazel rejects with "invalid
/// package name 'foo\\bar\\baz'". This normalization makes the resulting
/// Bazel target pattern valid on both platforms.
fn dir_to_bazel_package(dir: &str) -> String {
    dir.replace('\\', "/")
}

#[derive(Debug, Deserialize)]
pub struct ToolchainInfo {
    pub sysroot: Utf8PathBuf,
    pub sysroot_src: Utf8PathBuf,
    /// Declared rust-analyzer version (e.g. `"1.96.0"`). Empty when the
    /// toolchain rule didn't set it (user-supplied
    /// `rust_analyzer_toolchain` that omits the attribute). Consumers
    /// should treat empty as "assume oldest supported" to avoid emitting
    /// features that newer rust-analyzer versions added but older ones
    /// reject.
    #[serde(default)]
    pub version: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dir_to_bazel_package_normalizes_backslashes() {
        // Windows-shaped input (post-strip_prefix.parent()): backslashes.
        assert_eq!(dir_to_bazel_package(r"foo\bar\baz"), "foo/bar/baz");
        assert_eq!(dir_to_bazel_package(r"util\label"), "util/label");
        // POSIX-shaped input: pass through unchanged.
        assert_eq!(dir_to_bazel_package("foo/bar"), "foo/bar");
        assert_eq!(dir_to_bazel_package(""), "");
        // Mixed (defense in depth).
        assert_eq!(dir_to_bazel_package(r"a/b\c/d"), "a/b/c/d");
    }

    #[test]
    fn assess_discovery_clean_build_is_complete() {
        // Success → never incomplete, regardless of spec count.
        assert!(!assess_discovery(true, 0, "").unwrap());
        assert!(!assess_discovery(true, 42, "").unwrap());
    }

    #[test]
    fn assess_discovery_partial_failure_is_usable_but_incomplete() {
        // Some targets failed but specs were produced (e.g. an unrelated
        // broken target in a large monorepo) → proceed, but flag incomplete.
        assert!(assess_discovery(false, 2712, "boom").unwrap());
    }

    #[test]
    fn assess_discovery_total_failure_errors() {
        // Failed build with nothing usable → fatal, and the message carries
        // the captured stderr so the user sees the real cause.
        let err = assess_discovery(false, 0, "the real bazel error")
            .unwrap_err()
            .to_string();
        assert!(err.contains("the real bazel error"), "got: {}", err);
    }
}
