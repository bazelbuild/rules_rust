mod aquery;
mod command;
mod rust_project;

use std::{collections::HashMap, process::Command};

use anyhow::bail;
use camino::Utf8Path;
use command::BazelCommand;
use runfiles::Runfiles;
use rust_project::RustProject;
pub use rust_project::{DiscoverProject, NormalizedProjectString, RustAnalyzerArg};

pub const WORKSPACE_ROOT_FILE_NAMES: &[&str] =
    &["MODULE.bazel", "REPO.bazel", "WORKSPACE.bazel", "WORKSPACE"];

pub const BUILD_FILE_NAMES: &[&str] = &["BUILD.bazel", "BUILD"];

pub fn generate_crate_info(
    bazel: &Utf8Path,
    output_base: &Utf8Path,
    workspace: &Utf8Path,
    bazelrc: Option<&Utf8Path>,
    rules_rust: &str,
    targets: &[String],
) -> anyhow::Result<()> {
    log::info!("running bazel build...");
    log::debug!("Building rust_analyzer_crate_spec files for {:?}", targets);

    let output = Command::new_bazel_command(bazel, Some(workspace), Some(output_base), bazelrc)
        .arg("build")
        .arg("--norun_validations")
        .arg(format!(
            "--aspects={rules_rust}//rust:defs.bzl%rust_analyzer_aspect"
        ))
        .arg("--output_groups=rust_analyzer_crate_spec,rust_generated_srcs,rust_analyzer_proc_macro_dylibs,rust_analyzer_srcs")
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

pub fn generate_rust_project(
    bazel: &Utf8Path,
    output_base: &Utf8Path,
    workspace: &Utf8Path,
    execution_root: &Utf8Path,
    bazelrc: Option<&Utf8Path>,
    rules_rust_name: &str,
    targets: &[String],
) -> anyhow::Result<RustProject> {
    let crate_specs = aquery::get_crate_specs(
        bazel,
        output_base,
        workspace,
        execution_root,
        bazelrc,
        targets,
        rules_rust_name,
    )?;

    let path = runfiles::rlocation!(
        Runfiles::create()?,
        "rules_rust/rust/private/rust_analyzer_detect_sysroot.rust_analyzer_toolchain.json"
    )
    .unwrap();
    let toolchain_info: HashMap<String, String> =
        serde_json::from_str(&std::fs::read_to_string(path)?)?;

    let sysroot_src = &toolchain_info["sysroot_src"];
    let sysroot = &toolchain_info["sysroot"];

    rust_project::assemble_rust_project(bazel, workspace, sysroot, sysroot_src, &crate_specs)
}

/// Executes `bazel info` to get context information.
pub fn get_bazel_info(
    bazel: &Utf8Path,
    workspace: Option<&Utf8Path>,
    output_base: Option<&Utf8Path>,
    bazelrc: Option<&Utf8Path>,
) -> anyhow::Result<HashMap<String, String>> {
    let output = Command::new_bazel_command(bazel, workspace, output_base, bazelrc)
        .arg("info")
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
