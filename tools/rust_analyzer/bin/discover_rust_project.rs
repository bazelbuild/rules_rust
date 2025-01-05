//! Binary used for automatic Rust workspace discovery by `rust-analyzer`.
//! Check the `rust-analyzer` user manual (<https://rust-analyzer.github.io/manual.html>),
//! particularly the `rust-analyzer.workspace.discoverConfig` section, for more details.

use std::env;

use camino::Utf8PathBuf;
use clap::Args;
use env_logger::Target;
use env_logger::WriteStyle;
use gen_rust_project_lib::{
    discover_rust_project, discovery_failure, discovery_progress, generate_crate_info, Config,
    RustAnalyzerArg,
};
use log::LevelFilter;
use std::io::Write;

#[derive(Debug, Args)]
struct DiscoverProjectArgs {
    /// The build file to use as Rust workspace root when not
    /// using the `rust-analyzer` argument.
    #[clap(long, default_value = "BUILD.bazel")]
    default_buildfile: Utf8PathBuf,

    /// The argument that `rust-analyzer` can pass to the binary.
    rust_analyzer_argument: Option<RustAnalyzerArg>,
}

fn project_discovery() -> anyhow::Result<()> {
    let Config {
        workspace,
        execution_root,
        output_base,
        bazel,
        config_group,
        specific,
    } = Config::parse_and_refine()?;

    let DiscoverProjectArgs {
        default_buildfile,
        rust_analyzer_argument,
    } = specific;

    let ra_arg = match rust_analyzer_argument {
        Some(ra_arg) => ra_arg,
        None => RustAnalyzerArg::Buildfile(workspace.join(default_buildfile)),
    };

    let rules_rust_name = env!("ASPECT_REPOSITORY");

    log::info!("got rust-analyzer argument: {ra_arg}");

    let (buildfile, targets) =
        ra_arg.query_target_details(&bazel, &output_base, &workspace, config_group.as_deref())?;

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
