mod aquery;
pub mod bep;
mod cache;
mod rust_project;

use std::{collections::BTreeMap, convert::TryInto, fs, process::Command};

use anyhow::{bail, Context};
use camino::{Utf8Path, Utf8PathBuf};
use runfiles::Runfiles;
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

    generate_crate_info(
        bazel,
        output_base,
        workspace,
        bazel_startup_options,
        bazel_args,
        rules_rust_name,
        targets,
        &bep_file,
    )?;

    let spec_paths =
        bep::parse_spec_paths(&bep_file).with_context(|| format!("parsing BEP file {bep_file}"))?;
    log::info!("discovered {} crate spec files via BEP", spec_paths.len());

    let toolchain_info_path: Utf8PathBuf = runfiles::rlocation!(
        Runfiles::create()?,
        "rules_rust/rust/private/rust_analyzer_detect_sysroot.rust_analyzer_toolchain.json"
    )
    .context("toolchain runfile not found")?
    .try_into()?;
    let toolchain_info_raw = fs::read_to_string(&toolchain_info_path)
        .with_context(|| format!("reading toolchain info {toolchain_info_path}"))?;

    // Read every spec file once; the contents feed both the cache key and the
    // consolidate/assemble step on a miss.
    let spec_contents = read_specs(&spec_paths)?;

    let launcher_dir = std::env::var(cache::LAUNCHER_DIR_ENV_VAR).unwrap_or_default();
    let cache_key = cache::compute_key(
        &spec_contents,
        &toolchain_info_raw,
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
        deserialize_with_substitution(&toolchain_info_raw, output_base, workspace, execution_root)
            .with_context(|| format!("parsing toolchain info {toolchain_info_path}"))?;

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
) -> anyhow::Result<()> {
    log::info!("running bazel build with BEP discovery...");
    log::debug!("Building rust_analyzer_crate_spec files for {:?}", targets);

    let output = bazel_command(bazel, Some(workspace), Some(output_base))
        .args(bazel_startup_options)
        .arg("build")
        .args(bazel_args)
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

    if !output.status.success() {
        let status = output.status;
        let stderr = String::from_utf8_lossy(&output.stderr);
        bail!("bazel build failed: ({status})\n{stderr}");
    }

    log::info!("bazel build finished");

    Ok(())
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
}
