//! Binary used for automatic Rust workspace discovery by `rust-analyzer`.
//! Check the `rust-analyzer` user manual (<https://rust-analyzer.github.io/manual.html>),
//! particularly the `rust-analyzer.workspace.discoverConfig` section, for more details.

use std::{convert::TryFrom, env, fs, io::Write};

use anyhow::bail;
use camino::{Utf8Path, Utf8PathBuf};
use clap::Parser;
use env_logger::{Target, WriteStyle};
use gen_rust_project_lib::{
    generate_crate_info, generate_rust_project, get_bazel_info, DiscoverProject,
    NormalizedProjectString, RustAnalyzerArg, WORKSPACE_ROOT_FILE_NAMES,
};
use log::LevelFilter;

fn discover_rust_project(
    bazel: &Utf8Path,
    output_base: &Utf8Path,
    workspace: &Utf8Path,
    execution_root: &Utf8Path,
    rules_rust_name: &str,
    targets: &[String],
    buildfile: Utf8PathBuf,
) -> anyhow::Result<()> {
    let project = generate_rust_project(
        bazel,
        output_base,
        workspace,
        execution_root,
        rules_rust_name,
        targets,
    )?;

    let discovery_str = DiscoverProject::Finished { buildfile, project }
        .as_normalized_project_string(workspace, output_base, execution_root)?;

    println!("{discovery_str}");

    Ok(())
}

/// Log formatting function that generates and writes a [`DiscoverProject::Progress`]
/// message which `rust-analyzer` can display.
fn discovery_progress(message: String) -> String {
    DiscoverProject::Progress { message }
        .as_project_string()
        .expect("represent discovery error as string")
}

/// Construct and print a [`DiscoverProject::Error`] to transmit a
/// project discovery failure to `rust-analyzer`.
fn discovery_failure(error: anyhow::Error) {
    let discovery = DiscoverProject::Error {
        error: format!("could not generate rust-project.json: {error}"),
        source: error.source().as_ref().map(ToString::to_string),
    };

    let discovery_str = discovery
        .as_project_string()
        .expect("represent discovery error as string");

    println!("{discovery_str}");
}

/// Looks within the current directory for a file that marks a bazel workspace.
///
/// # Errors
///
/// Returns an error if no file from [`WORKSPACE_ROOT_FILE_NAMES`] is found.
fn find_workspace_root_file(workspace: &Utf8Path) -> anyhow::Result<Utf8PathBuf> {
    for entry in fs::read_dir(&workspace)? {
        // Continue iteration if a path is not UTF8.
        let Ok(path) = Utf8PathBuf::try_from(entry?.path()) else {
            continue;
        };

        // Guard against directory names that would match items
        // from [`WORKSPACE_ROOT_FILE_NAMES`].
        if !path.is_file() {
            continue;
        }

        if let Some(filename) = path.file_name() {
            if WORKSPACE_ROOT_FILE_NAMES.contains(&filename) {
                return Ok(path);
            }
        }
    }

    bail!("no root file found for bazel workspace {workspace}")
}

fn project_discovery() -> anyhow::Result<()> {
    let Config {
        workspace,
        execution_root,
        output_base,
        bazel,
        rust_analyzer_argument,
    } = Config::parse()?;

    log::info!("got rust-analyzer argument: {rust_analyzer_argument:?}");

    let ra_arg = match rust_analyzer_argument {
        Some(ra_arg) => ra_arg,
        None => RustAnalyzerArg::Buildfile(find_workspace_root_file(&workspace)?),
    };

    let rules_rust_name = env!("ASPECT_REPOSITORY");

    log::info!("resolved rust-analyzer argument: {ra_arg}");

    let (buildfile, targets) = ra_arg.query_target_details(&workspace)?;
    let targets = &[targets];

    log::debug!("got buildfile: {buildfile}");
    log::debug!("got targets: {targets:?}");

    // Generate the crate specs.
    generate_crate_info(&bazel, &output_base, &workspace, rules_rust_name, targets)?;

    // Use the generated files to print the rust-project.json.
    discover_rust_project(
        &bazel,
        &output_base,
        &workspace,
        &execution_root,
        rules_rust_name,
        targets,
        buildfile,
    )
}

fn main() {
    // Treat logs as progress messages.
    env_logger::Builder::from_default_env()
        // Never write color/styling info
        .write_style(WriteStyle::Never)
        // Format logs as progress messages
        .format(|fmt, rec| writeln!(fmt, "{}", discovery_progress(rec.args().to_string())))
        // `rust-analyzer` reads the stdout
        .filter_level(LevelFilter::Debug)
        .target(Target::Stdout)
        .init();

    if let Err(e) = project_discovery() {
        discovery_failure(e);
    }
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

    /// The argument that `rust-analyzer` can pass to the binary.
    rust_analyzer_argument: Option<RustAnalyzerArg>,
}

impl Config {
    // Parse the configuration flags and supplement with bazel info as needed.
    pub fn parse() -> anyhow::Result<Self> {
        let ConfigParser {
            workspace,
            execution_root,
            output_base,
            bazel,
            rust_analyzer_argument,
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
                rust_analyzer_argument,
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
            rust_analyzer_argument,
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

    /// The argument that `rust-analyzer` can pass to the binary.
    rust_analyzer_argument: Option<RustAnalyzerArg>,
}
