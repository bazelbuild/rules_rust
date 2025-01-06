//! Binary used for automatic Rust workspace discovery by `rust-analyzer`.
//! Check the `rust-analyzer` user manual (<https://rust-analyzer.github.io/manual.html>),
//! particularly the `rust-analyzer.workspace.discoverConfig` section, for more details.

use std::convert::TryFrom;
use std::env;
use std::fs;

use anyhow::bail;
use camino::Utf8Path;
use camino::Utf8PathBuf;
use clap::Args;
use env_logger::Target;
use env_logger::WriteStyle;
use gen_rust_project_lib::DiscoverProject;
use gen_rust_project_lib::NormalizedProjectString;
use gen_rust_project_lib::WORKSPACE_ROOT_FILE_NAMES;
use gen_rust_project_lib::{generate_crate_info, generate_rust_project, Config, RustAnalyzerArg};
use log::LevelFilter;
use std::io::Write;

#[derive(Debug, Args)]
struct DiscoverProjectArgs {
    /// The argument that `rust-analyzer` can pass to the binary.
    rust_analyzer_argument: Option<RustAnalyzerArg>,
}

fn discover_rust_project(
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
        config_group,
        specific,
    } = Config::parse()?;

    let DiscoverProjectArgs {
        rust_analyzer_argument,
    } = specific;

    let ra_arg = match rust_analyzer_argument {
        Some(ra_arg) => ra_arg,
        None => RustAnalyzerArg::Buildfile(find_workspace_root_file(&workspace)?),
    };

    let rules_rust_name = env!("ASPECT_REPOSITORY");

    log::info!("got rust-analyzer argument: {ra_arg}");

    let (buildfile, targets) = ra_arg.query_target_details(&workspace)?;
    let targets = &[targets];

    log::debug!("got buildfile: {buildfile}");
    log::debug!("got targets: {targets:?}");

    // Generate the crate specs.
    generate_crate_info(
        &bazel,
        &output_base,
        &workspace,
        config_group.as_deref(),
        rules_rust_name,
        targets,
    )?;

    // Use the generated files to print the rust-project.json.
    discover_rust_project(
        &bazel,
        &output_base,
        &workspace,
        &execution_root,
        config_group.as_deref(),
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
