use anyhow::anyhow;
use std::collections::HashMap;
use std::env;
use std::path::PathBuf;
use std::process::Command;
use structopt::StructOpt;
use gen_rust_project_lib::generate_crate_and_sysroot_info;
use gen_rust_project_lib::write_rust_project;

// TODO(david): This shells out to an expected rule in the workspace root //:rust_analyzer that the user must define.
// It would be more convenient if it could automatically discover all the rust code in the workspace if this target does not exist.
fn main() -> anyhow::Result<()> {
    env_logger::init();

    let config = parse_config()?;

    let workspace_root = config
        .workspace
        .as_ref()
        .expect("failed to find workspace root, set with --workspace");
    let execution_root = config
        .execution_root
        .as_ref()
        .expect("failed to find execution root, is --execution-root set correctly?");

    let targets = config.targets.split(",").collect::<Vec<_>>();

    // Generate the crate specs and sysroot src.
    generate_crate_and_sysroot_info(
        &config.bazel,
        &workspace_root,
        &config.rules_rust,
        &targets,
    )?;

    // Use the generated files to write rust-project.json.
    write_rust_project(        &config.bazel,
        &workspace_root,
        &config.rules_rust,
        &targets,
        &execution_root,
        &workspace_root.join("rust-project.json"),
)?;

    Ok(())
}

// Parse the configuration flags and supplement with bazel info as needed.
fn parse_config() -> anyhow::Result<Config> {
    let mut config = Config::from_args();

    // Ensure we know the workspace. If we are under `bazel run`, the
    // BUILD_WORKSPACE_DIR environment variable will be present.
    if config.workspace.is_none() {
        if let Some(ws_dir) = env::var_os("BUILD_WORKSPACE_DIRECTORY") {
            config.workspace = Some(PathBuf::from(ws_dir));
        }
    }

    if config.workspace.is_some() && config.execution_root.is_some() {
        return Ok(config);
    }

    // We need some info from `bazel info`. Fetch it now.
    let mut bazel_info_command = Command::new(&config.bazel);
    bazel_info_command.arg("info");
    if let Some(workspace) = &config.workspace {
        bazel_info_command.current_dir(workspace);
    }

    // Execute bazel info.
    let output = bazel_info_command.output()?;
    if !output.status.success() {
        return Err(anyhow!(
            "Failed to run `bazel info` ({:?}): {}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        ));
    }

    // Extract the output.
    let output = String::from_utf8_lossy(output.stdout.as_slice());
    let bazel_info = output
        .trim()
        .split('\n')
        .map(|line| line.split_at(line.find(':').expect("missing `:` in bazel info output")))
        .map(|(k, v)| (k, (&v[1..]).trim()))
        .collect::<HashMap<_, _>>();

    if config.workspace.is_none() {
        config.workspace = bazel_info.get("workspace").map(Into::into);
    }
    if config.execution_root.is_none() {
        config.execution_root = bazel_info.get("execution_root").map(Into::into);
    }

    Ok(config)
}

#[derive(Debug, StructOpt)]
struct Config {
    // If not specified, uses the result of `bazel info workspace`.
    #[structopt(long)]
    workspace: Option<PathBuf>,

    // If not specified, uses the result of `bazel info execution_root`.
    #[structopt(long)]
    execution_root: Option<PathBuf>,

    #[structopt(long, default_value = "bazel")]
    bazel: PathBuf,

    #[structopt(long, default_value = "@rules_rust", help = "The name of the rules_rust repository")]
    rules_rust: String,

    #[structopt(long, default_value = "//:rust_analyzer", help = "Deprecated. If found, overrides --targets for historical reasons")]
    bazel_analyzer_target: String,

    #[structopt(long, default_value = "//...", help = "Comma-separated list of target patterns")]
    targets: String,
}
