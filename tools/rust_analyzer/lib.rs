use std::path::Path;
use std::process::Command;

use anyhow::anyhow;
use log::debug;
use runfiles::Runfiles;

mod aquery;
mod rust_project;

const DEFAULT_RUNFILES_PREFIX: &str = "rules_rust";

pub fn generate_crate_info(
    bazel: impl AsRef<Path>,
    workspace: impl AsRef<Path>,
    rules_rust: impl AsRef<str>,
    targets: &[String],
) -> anyhow::Result<()> {
    log::debug!("Building rust_analyzer_crate_spec files for {:?}", targets);

    let output = Command::new(bazel.as_ref())
        .current_dir(workspace.as_ref())
        .arg("build")
        .arg(format!(
            "--aspects={}//rust:defs.bzl%rust_analyzer_aspect",
            rules_rust.as_ref()
        ))
        .arg("--output_groups=rust_analyzer_crate_spec")
        .args(targets)
        .output()?;

    if !output.status.success() {
        return Err(anyhow!(
            "bazel build failed:({})\n{}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        ));
    }

    Ok(())
}

fn read_runfile(rules_rust_name: impl AsRef<str>, path: &str) -> anyhow::Result<String> {
    let workspace_name = match rules_rust_name.as_ref().trim_start_matches('@') {
        "" => DEFAULT_RUNFILES_PREFIX,
        s => s,
    };

    let relative_path = format!("{}{}", workspace_name, path);
    let r = Runfiles::create()?;
    let path = r.rlocation(relative_path);
    Ok(std::fs::read_to_string(&path)?)
}

pub fn write_rust_project(
    bazel: impl AsRef<Path>,
    workspace: impl AsRef<Path>,
    rules_rust_name: &impl AsRef<str>,
    targets: &[String],
    execution_root: impl AsRef<Path>,
    output_base: impl AsRef<Path>,
    rust_project_path: impl AsRef<Path>,
) -> anyhow::Result<()> {
    let crate_specs = aquery::get_crate_specs(
        bazel.as_ref(),
        workspace.as_ref(),
        execution_root.as_ref(),
        targets,
        rules_rust_name.as_ref(),
    )?;

    let sysroot_src_path = read_runfile(
        rules_rust_name,
        "/rust/private/rust_analyzer_detect_sysroot.rust_analyzer_sysroot_src",
    )?;
    let sysroot_path = read_runfile(
        rules_rust_name,
        "/rust/private/rust_analyzer_detect_sysroot.rust_analyzer_sysroot",
    )?;

    let rust_project =
        rust_project::generate_rust_project(&sysroot_path, &sysroot_src_path, &crate_specs)?;

    rust_project::write_rust_project(
        rust_project_path.as_ref(),
        execution_root.as_ref(),
        output_base.as_ref(),
        &rust_project,
    )?;

    Ok(())
}
