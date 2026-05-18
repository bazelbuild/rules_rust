mod aquery;
mod rust_project;

use std::{collections::BTreeMap, convert::TryInto, fs, path::Path, process::Command};

use anyhow::{bail, Context};
use camino::{Utf8Path, Utf8PathBuf};
use runfiles::Runfiles;
use rust_project::RustProject;
pub use rust_project::{DiscoverProject, RustAnalyzerArg};
use serde::{de::DeserializeOwned, Deserialize};

pub const WORKSPACE_ROOT_FILE_NAMES: &[&str] =
    &["MODULE.bazel", "REPO.bazel", "WORKSPACE.bazel", "WORKSPACE"];

pub const BUILD_FILE_NAMES: &[&str] = &["BUILD.bazel", "BUILD"];

/// Install a symlink at `<workspace>/.bazel_rust_flycheck` pointing at the
/// bundled `flycheck` binary so rust-analyzer can invoke it directly via
/// `check.overrideCommand`. The indirection sidesteps bzlmod
/// canonical-repo-name fragility (the symlink target is resolved here, where
/// canonical names are fully knowable).
///
/// Lives at workspace root rather than under `bazel-out` because the
/// `bazel-out` convenience symlink retargets when a different bazel command
/// runs against a different `--output_base`. Monorepos commonly run their IDE
/// bazel under a dedicated output_base separate from CLI bazel, which would
/// strand the symlink and break flycheck whenever a CLI build ran between
/// discoveries. Workspace root is stable across output_base switches;
/// consumers gitignore via their existing `.gitignore` entry.
pub fn install_flycheck_symlink(
    workspace: &Utf8Path,
    flycheck_rlocationpath: &str,
) -> anyhow::Result<()> {
    let runfiles = Runfiles::create().context("failed to load runfiles")?;
    let binary: Utf8PathBuf = runfiles
        .rlocation(flycheck_rlocationpath)
        .with_context(|| {
            format!("flycheck binary runfile not found: {flycheck_rlocationpath}")
        })?
        .try_into()?;
    let resolved = binary
        .canonicalize_utf8()
        .with_context(|| format!("failed to canonicalize {binary}"))?;
    let symlink_path = workspace.join(".bazel_rust_flycheck");
    match fs::remove_file(&symlink_path) {
        Ok(_) => {}
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {}
        Err(error) => {
            return Err(error)
                .with_context(|| format!("failed to remove {symlink_path}"));
        }
    }
    symlink_to_file(resolved.as_std_path(), symlink_path.as_std_path())
        .with_context(|| format!("failed to symlink {symlink_path} -> {resolved}"))?;
    Ok(())
}

#[cfg(unix)]
fn symlink_to_file(target: &Path, link: &Path) -> std::io::Result<()> {
    std::os::unix::fs::symlink(target, link)
}

#[cfg(windows)]
fn symlink_to_file(target: &Path, link: &Path) -> std::io::Result<()> {
    std::os::windows::fs::symlink_file(target, link)
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
    generate_crate_info(
        bazel,
        output_base,
        workspace,
        bazel_startup_options,
        bazel_args,
        rules_rust_name,
        targets,
    )?;

    let crate_specs = aquery::get_crate_specs(
        bazel,
        output_base,
        workspace,
        execution_root,
        bazel_startup_options,
        bazel_args,
        targets,
        rules_rust_name,
    )?;

    let path: Utf8PathBuf = runfiles::rlocation!(
        Runfiles::create()?,
        "rules_rust/rust/private/rust_analyzer_detect_sysroot.rust_analyzer_toolchain.json"
    )
    .context("toolchain runfile not found")?
    .try_into()?;

    let toolchain_info = deserialize_file_content(&path, output_base, workspace, execution_root)?;

    rust_project::assemble_rust_project(bazel, workspace, toolchain_info, &crate_specs)
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

fn generate_crate_info(
    bazel: &Utf8Path,
    output_base: &Utf8Path,
    workspace: &Utf8Path,
    bazel_startup_options: &[String],
    bazel_args: &[String],
    rules_rust: &str,
    targets: &[String],
) -> anyhow::Result<()> {
    log::info!("running bazel build...");
    log::debug!("Building rust_analyzer_crate_spec files for {:?}", targets);

    let output = bazel_command(bazel, Some(workspace), Some(output_base))
        .args(bazel_startup_options)
        .arg("build")
        .args(bazel_args)
        .arg("--norun_validations")
        .arg("--remote_download_all")
        .arg(format!(
            "--aspects={rules_rust}//tools/rust_analyzer:defs.bzl%rust_analyzer_aspect"
        ))
        .arg("--output_groups=rust_analyzer_crate_spec,rust_generated_srcs,rust_analyzer_proc_macro_dylib,rust_analyzer_src,rust_analyzer_check_command")
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

fn deserialize_file_content<T>(
    path: &Utf8Path,
    output_base: &Utf8Path,
    workspace: &Utf8Path,
    execution_root: &Utf8Path,
) -> anyhow::Result<T>
where
    T: DeserializeOwned,
{
    let content = fs::read_to_string(path)
        .with_context(|| format!("failed to read file: {path}"))?
        .replace("__WORKSPACE__", workspace.as_str())
        .replace("${pwd}", execution_root.as_str())
        .replace("__EXEC_ROOT__", execution_root.as_str())
        .replace("__OUTPUT_BASE__", output_base.as_str());

    log::trace!("{}\n{}", path, content);

    serde_json::from_str(&content).with_context(|| format!("failed to deserialize file: {path}"))
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
        Some(p) if !p.as_str().is_empty() => format!("//{p}:all"),
        _ => "//...".to_string(),
    };

    Ok(targets)
}

#[derive(Debug, Deserialize)]
struct ToolchainInfo {
    sysroot: Utf8PathBuf,
    sysroot_src: Utf8PathBuf,
}
