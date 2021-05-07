use anyhow::anyhow;
use anyhow::Context;
use std::collections::HashMap;
use std::env;
use std::fs;
use std::io::ErrorKind;
use std::path::PathBuf;
use std::process::Command;
use structopt::StructOpt;

// TODO(david): This shells out to an expected rule in the workspace root //:rust_analyzer that the user must define.
// It would be more convenient if it could automatically discover all the rust code in the workspace if this target does not exist.
fn main() -> anyhow::Result<()> {
    let config = parse_config()?;

    let workspace_root = config
        .workspace
        .as_ref()
        .expect("failed to find workspace root, set with --workspace");
    let execution_root = config
        .execution_root
        .as_ref()
        .expect("failed to find execution root, is --workspace set correctly?");

    build_rust_project_target(&config);
    let label = label::analyze(&config.bazel_analyzer_target)
        .with_context(|| "Cannot parse --bazel-analyzer-target")?;

    let mut generated_rust_project = workspace_root.join("bazel-bin");
    for package in label.packages() {
        generated_rust_project = generated_rust_project.join(package);
    }
    generated_rust_project = generated_rust_project.join("rust-project.json");
    let workspace_rust_project = workspace_root.join("rust-project.json");

    // The generated_rust_project has a template string we must replace with the workspace name.
    let generated_json = fs::read_to_string(&generated_rust_project)
        .expect("failed to read generated rust-project.json");

    // Try to remove the existing rust-project.json. It's OK if the file doesn't exist.
    match fs::remove_file(&workspace_rust_project) {
        Ok(_) => {}
        Err(err) if err.kind() == ErrorKind::NotFound => {}
        Err(err) => panic!("Unexpected error removing old rust-project.json: {}", err),
    }

    // Write the new rust-project.json file.
    fs::write(
        workspace_rust_project,
        generated_json.replace("__EXEC_ROOT__", &execution_root.to_string_lossy()),
    )
    .expect("failed to write workspace rust-project.json");

    Ok(())
}

fn build_rust_project_target(config: &Config) {
    let output = Command::new(&config.bazel)
        .current_dir(config.workspace.as_ref().unwrap())
        .arg("build")
        .arg(&config.bazel_analyzer_target)
        .output()
        .expect("failed to execute bazel process");
    if !output.status.success() {
        panic!(
            "bazel build failed:({}) of {:?}:\n{}",
            output.status,
            &config.bazel_analyzer_target,
            String::from_utf8_lossy(&output.stderr)
        );
    }
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
    let output = String::from_utf8_lossy(&output.stdout.as_slice());
    let bazel_info = output
        .trim()
        .split("\n")
        .map(|line| line.split_at(line.find(":").expect("missing `:` in bazel info output")))
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

    #[structopt(long, default_value = "//:rust_analyzer")]
    bazel_analyzer_target: String,
}
