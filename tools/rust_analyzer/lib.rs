mod aquery;
mod config;
mod ra_arg;
mod rust_project;

use std::collections::HashMap;
use std::process::Command;

use anyhow::bail;
use camino::{Utf8Path, Utf8PathBuf};
pub use config::Config;
pub use ra_arg::RustAnalyzerArg;
use runfiles::Runfiles;
use rust_project::{normalize_project_string, DiscoverProject, RustProject};

pub fn generate_crate_info(
    bazel: &Utf8Path,
    output_base: &Utf8Path,
    workspace: &Utf8Path,
    config_group: Option<&str>,
    rules_rust: &str,
    targets: &[String],
) -> anyhow::Result<()> {
    log::info!("running bazel build...");
    log::debug!("Building rust_analyzer_crate_spec files for {:?}", targets);

    let output = Command::new(bazel)
        .current_dir(workspace)
        .env_remove("BAZELISK_SKIP_WRAPPER")
        .env_remove("BUILD_WORKING_DIRECTORY")
        .env_remove("BUILD_WORKSPACE_DIRECTORY")
        .arg(format!("--output_base={output_base}"))
        .arg("build")
        .args(config_group.map(|s| format!("--config={s}")))
        .arg("--norun_validations")
        .arg(format!(
            "--aspects={rules_rust}//rust:defs.bzl%rust_analyzer_aspect"
        ))
        .arg("--output_groups=rust_analyzer_crate_spec,rust_generated_srcs,rust_analyzer_proc_macro_dylibs,rust_analyzer_build_info_out_dirs")
        .args(targets)
        .output()?;

    if !output.status.success() {
        bail!(
            "bazel build failed:({})\n{}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        );
    }

    log::info!("bazel build finished");

    Ok(())
}

pub fn discover_rust_project(
    bazel: &Utf8Path,
    output_base: &Utf8Path,
    workspace: &Utf8Path,
    execution_root: &Utf8Path,
    config_group: Option<&str>,
    rules_rust_name: &str,
    targets: &[String],
    buildfile: Utf8PathBuf,
) -> anyhow::Result<()> {
    let project = generate_rust_project(
        bazel,
        output_base,
        workspace,
        execution_root,
        config_group,
        rules_rust_name,
        targets,
    )?;

    let discovery = DiscoverProject::Finished { buildfile, project };
    let discovery_str = serde_json::to_string(&discovery)?;
    let discovery_str =
        normalize_project_string(&discovery_str, workspace, output_base, execution_root);

    println!("{discovery_str}");

    Ok(())
}

/// Log formatting function that generates and writes a [`DiscoverProject::Progress`]
/// message which `rust-analyzer` can display.
pub fn discovery_progress(message: String) -> String {
    let discovery = DiscoverProject::Progress { message };
    serde_json::to_string(&discovery).expect("serializable message")
}

pub fn discovery_failure(error: anyhow::Error) {
    let discovery = DiscoverProject::Error {
        error: format!("could not generate rust-project.json: {error}"),
        source: error.source().as_ref().map(ToString::to_string),
    };

    let discovery_str = serde_json::to_string(&discovery).expect("serializable error");
    println!("{discovery_str}");
}

pub fn write_rust_project(
    bazel: &Utf8Path,
    output_base: &Utf8Path,
    workspace: &Utf8Path,
    execution_root: &Utf8Path,
    config_group: Option<&str>,
    rules_rust_name: &str,
    targets: &[String],
    rust_project_path: &Utf8Path,
) -> anyhow::Result<()> {
    let rust_project = generate_rust_project(
        bazel,
        output_base,
        workspace,
        execution_root,
        config_group,
        rules_rust_name,
        targets,
    )?;

    rust_project::write_rust_project(
        rust_project_path,
        output_base,
        workspace,
        execution_root,
        &rust_project,
    )?;

    Ok(())
}

fn generate_rust_project(
    bazel: &Utf8Path,
    output_base: &Utf8Path,
    workspace: &Utf8Path,
    execution_root: &Utf8Path,
    config_group: Option<&str>,
    rules_rust_name: &str,
    targets: &[String],
) -> anyhow::Result<RustProject> {
    let crate_specs = aquery::get_crate_specs(
        bazel,
        output_base,
        workspace,
        execution_root,
        config_group,
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

    rust_project::generate_rust_project(workspace, sysroot, sysroot_src, &crate_specs)
}
