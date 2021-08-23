use anyhow::anyhow;
use std::path::Path;
use std::process::Command;

mod aquery;
mod rust_project;

pub fn generate_crate_and_sysroot_info(
    bazel: impl AsRef<Path>,
    workspace: impl AsRef<Path>,
    rules_rust: impl AsRef<str>,
    targets: &[&str],
) -> anyhow::Result<()> {
    log::debug!("Building rust_analyzer_crate_spec files for {:?}", targets);

    let output = Command::new(bazel.as_ref())
        .current_dir(workspace.as_ref())
        .arg("build")
        .arg("--aspects=@rules_rust//rust:defs.bzl%rust_analyzer_aspect")
        .arg("--output_groups=rust_analyzer_crate_spec,rust_analyzer_sysroot_src")
        .arg(format!(
            "{}//tools/rust_analyzer:detect_sysroot",
            rules_rust.as_ref()
        ))
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

pub fn write_rust_project(
    bazel: impl AsRef<Path>,
    workspace: impl AsRef<Path>,
    rules_rust: &impl AsRef<str>,
    targets: &[&str],
    execution_root: impl AsRef<Path>,
    rust_project_path: impl AsRef<Path>,
) -> anyhow::Result<()> {
    let crate_specs = aquery::get_crate_specs(
        bazel.as_ref(),
        workspace.as_ref(),
        execution_root.as_ref(),
        &targets,
    )?;
    let sysroot_src = aquery::get_sysroot_src(
        bazel.as_ref(),
        workspace.as_ref(),
        execution_root.as_ref(),
        rules_rust.as_ref(),
    )?;
    let rust_project = rust_project::generate_rust_project(&sysroot_src, &crate_specs)?;

    rust_project::write_rust_project(
        rust_project_path.as_ref(),
        execution_root.as_ref(),
        &rust_project,
    )?;

    Ok(())
}
