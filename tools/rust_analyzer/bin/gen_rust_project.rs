use std::env;

use clap::Args;
use gen_rust_project_lib::{generate_crate_info, write_rust_project, Config};

#[derive(Debug, Args)]
struct GenerateProjectArgs {
    /// Space separated list of target patterns that comes after all other args.
    #[clap(default_value = "@//...")]
    targets: Vec<String>,
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
    } = Config::parse_and_refine()?;

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
