use std::{env, io::ErrorKind};

use anyhow::bail;
use camino::{Utf8Path, Utf8PathBuf};
use clap::Parser;
use gen_rust_project_lib::{
    generate_crate_info, generate_rust_project, get_bazel_info, NormalizedProjectString,
};

fn write_rust_project(
    bazel: &Utf8Path,
    output_base: &Utf8Path,
    workspace: &Utf8Path,
    execution_root: &Utf8Path,
    rules_rust_name: &str,
    targets: &[String],
    rust_project_path: &Utf8Path,
) -> anyhow::Result<()> {
    let rust_project = generate_rust_project(
        bazel,
        output_base,
        workspace,
        execution_root,
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
        targets,
    } = Config::parse()?;

    let rules_rust_name = env!("ASPECT_REPOSITORY");

    // Generate the crate specs.
    generate_crate_info(&bazel, &output_base, &workspace, rules_rust_name, &targets)?;

    // Use the generated files to write rust-project.json.
    write_rust_project(
        &bazel,
        &output_base,
        &workspace,
        &execution_root,
        rules_rust_name,
        &targets,
        &workspace.join("rust-project.json"),
    )?;

    Ok(())
}

#[derive(Debug)]
pub struct Config {
    /// The path to the Bazel workspace directory. If not specified, uses the result of `bazel info workspace`.
    pub workspace: Utf8PathBuf,

    /// The path to the Bazel execution root. If not specified, uses the result of `bazel info execution_root`.
    pub execution_root: Utf8PathBuf,

    /// The path to the Bazel output user root. If not specified, uses the result of `bazel info output_base`.
    pub output_base: Utf8PathBuf,

    /// The path to a Bazel binary
    pub bazel: Utf8PathBuf,

    /// Space separated list of target patterns that comes after all other args.
    targets: Vec<String>,
}

impl Config {
    // Parse the configuration flags and supplement with bazel info as needed.
    pub fn parse() -> anyhow::Result<Self> {
        let ConfigParser {
            workspace,
            execution_root,
            output_base,
            bazel,
            targets,
        } = ConfigParser::parse();

        // Implemented this way instead of a classic `if let` to satisfy the
        // borrow checker.
        // See: <https://github.com/rust-lang/rust/issues/54663>
        if workspace.is_some() && execution_root.is_some() && output_base.is_some() {
            return Ok(Config {
                workspace: workspace.unwrap(),
                execution_root: execution_root.unwrap(),
                output_base: output_base.unwrap(),
                bazel,
                targets,
            });
        }

        // We need some info from `bazel info`. Fetch it now.
        let mut info_map = get_bazel_info(&bazel, workspace.as_deref(), output_base.as_deref())?;

        let config = Config {
            workspace: info_map
                .remove("workspace")
                .expect("'workspace' must exist in bazel info")
                .into(),
            execution_root: info_map
                .remove("execution_root")
                .expect("'execution_root' must exist in bazel info")
                .into(),
            output_base: info_map
                .remove("output_base")
                .expect("'output_base' must exist in bazel info")
                .into(),
            bazel,
            targets,
        };

        Ok(config)
    }
}

#[derive(Debug, Parser)]
struct ConfigParser {
    /// The path to the Bazel workspace directory. If not specified, uses the result of `bazel info workspace`.
    #[clap(long, env = "BUILD_WORKSPACE_DIRECTORY")]
    workspace: Option<Utf8PathBuf>,

    /// The path to the Bazel execution root. If not specified, uses the result of `bazel info execution_root`.
    #[clap(long)]
    execution_root: Option<Utf8PathBuf>,

    /// The path to the Bazel output user root. If not specified, uses the result of `bazel info output_base`.
    #[clap(long, env = "OUTPUT_BASE")]
    output_base: Option<Utf8PathBuf>,

    /// The path to a Bazel binary
    #[clap(long, default_value = "bazel")]
    bazel: Utf8PathBuf,

    /// Space separated list of target patterns that comes after all other args.
    #[clap(default_value = "@//...")]
    targets: Vec<String>,
}
