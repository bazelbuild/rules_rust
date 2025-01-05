use std::{env, io::ErrorKind};

use anyhow::bail;
use camino::Utf8Path;
use clap::Args;
use gen_rust_project_lib::{
    generate_crate_info, generate_rust_project, Config, NormalizedProjectString,
};

#[derive(Debug, Args)]
struct GenerateProjectArgs {
    /// Space separated list of target patterns that comes after all other args.
    #[clap(default_value = "@//...")]
    targets: Vec<String>,
}

fn write_rust_project(
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

    // Try to remove the existing rust-project.json. It's OK if the file doesn't exist.
    match std::fs::remove_file(rust_project_path) {
        Ok(_) => {}
        Err(err) if err.kind() == ErrorKind::NotFound => {}
        Err(err) => bail!("Unexpected error removing old rust-project.json: {}", err),
    }

    // Render the `rust-project.json` file content and replace the exec root
    // placeholders with the path to the local exec root.
    let rust_project_content =
        rust_project.as_normalized_project_string(workspace, output_base, execution_root)?;

    // Write the new rust-project.json file.
    std::fs::write(rust_project_path, rust_project_content)?;

    Ok(())
}

// TODO(david): This shells out to an expected rule in the workspace root //:rust_analyzer that the user must define.
// It would be more convenient if it could automatically discover all the rust code in the workspace if this target
// does not exist.
fn main() -> anyhow::Result<()> {
    env_logger::init();

    let Config {
        workspace,
        execution_root,
        output_base,
        bazel,
        config_group,
        specific,
    } = Config::parse()?;

    let GenerateProjectArgs { targets } = specific;

    let rules_rust_name = env!("ASPECT_REPOSITORY");

    // Generate the crate specs.
    generate_crate_info(
        &bazel,
        &output_base,
        &workspace,
        config_group.as_deref(),
        rules_rust_name,
        &targets,
    )?;

    // Use the generated files to write rust-project.json.
    write_rust_project(
        &bazel,
        &output_base,
        &workspace,
        &execution_root,
        config_group.as_deref(),
        rules_rust_name,
        &targets,
        &workspace.join("rust-project.json"),
    )?;

    Ok(())
}
