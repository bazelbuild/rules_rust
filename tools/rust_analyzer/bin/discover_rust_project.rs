//! Binary used for automatic Rust workspace discovery by `rust-analyzer`.
//! See [rust-analyzer documentation][rd] for a thorough description of this interface.
//! [rd]: <https://rust-analyzer.github.io/manual.html#rust-analyzer.workspace.discoverConfig>.

use std::{
    env,
    io::{self, Write},
};

use anyhow::Context;
use camino::{Utf8Path, Utf8PathBuf};
use clap::Parser;
use env_logger::{fmt::Formatter, Target, WriteStyle};
use gen_rust_project_lib::{
    generate_crate_info, generate_rust_project, get_bazel_info, DiscoverProject, RustAnalyzerArg,
    BUILD_FILE_NAMES, WORKSPACE_ROOT_FILE_NAMES,
};
use log::{LevelFilter, Record};

/// Looks within the current directory for a file that marks a bazel workspace.
///
/// # Errors
///
/// Returns an error if no file from [`WORKSPACE_ROOT_FILE_NAMES`] is found.
fn find_workspace_root_file(workspace: &Utf8Path) -> anyhow::Result<Utf8PathBuf> {
    BUILD_FILE_NAMES
        .iter()
        .chain(WORKSPACE_ROOT_FILE_NAMES)
        .map(|file| workspace.join(file))
        .find(|p| p.exists())
        .with_context(|| format!("no root file found for bazel workspace {workspace}"))
}

fn project_discovery() -> anyhow::Result<DiscoverProject<'static>> {
    let Config {
        workspace,
        execution_root,
        output_base,
        bazel,
        bazelrc,
        rust_analyzer_argument,
    } = Config::parse()?;

    log::info!("got rust-analyzer argument: {rust_analyzer_argument:?}");

    let ra_arg = match rust_analyzer_argument {
        Some(ra_arg) => ra_arg,
        None => RustAnalyzerArg::Buildfile(find_workspace_root_file(&workspace)?),
    };

    let rules_rust_name = env!("ASPECT_REPOSITORY");

    log::info!("resolved rust-analyzer argument: {ra_arg:?}");

    let (buildfile, targets) = ra_arg.into_target_details(&workspace)?;
    let targets = &[targets];

    log::debug!("got buildfile: {buildfile}");
    log::debug!("got targets: {targets:?}");

    // Generate the crate specs.
    generate_crate_info(
        &bazel,
        &output_base,
        &workspace,
        bazelrc.as_deref(),
        rules_rust_name,
        targets,
    )?;

    // Use the generated files to print the rust-project.json.
    let project = generate_rust_project(
        &bazel,
        &output_base,
        &workspace,
        &execution_root,
        bazelrc.as_deref(),
        &rules_rust_name,
        targets,
    )?;

    Ok(DiscoverProject::Finished { buildfile, project })
}

fn main() -> anyhow::Result<()> {
    let log_format_fn = |fmt: &mut Formatter, rec: &Record| {
        let message = rec.args();
        let discovery = DiscoverProject::Progress { message };
        serde_json::to_writer(&mut *fmt, &discovery)?;
        // `rust-analyzer` reads messages line by line
        writeln!(fmt, "");
        Ok(())
    };

    // Treat logs as progress messages.
    env_logger::Builder::from_default_env()
        // Never write color/styling info
        .write_style(WriteStyle::Never)
        // Format logs as progress messages
        .format(log_format_fn)
        // `rust-analyzer` reads the stdout
        .filter_level(LevelFilter::Debug)
        .target(Target::Stdout)
        .init();

    let discovery = match project_discovery() {
        Ok(discovery) => discovery,
        Err(error) => DiscoverProject::Error {
            error: error.to_string(),
            source: error.source().as_ref().map(ToString::to_string),
        },
    };

    serde_json::to_writer(io::stdout(), &discovery)?;
    // `rust-analyzer` reads messages line by line
    println!("");

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

    /// The path to a Bazel binary.
    pub bazel: Utf8PathBuf,

    /// The path to a `bazelrc` configuration file.
    bazelrc: Option<Utf8PathBuf>,

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
            bazelrc,
            rust_analyzer_argument,
        } = ConfigParser::parse();

        // Implemented this way instead of a classic `if let` to satisfy the
        // borrow checker.
        // See: <https://github.com/rust-lang/rust/issues/54663>
        #[allow(clippy::unnecessary_unwrap)]
        if workspace.is_some() && execution_root.is_some() && output_base.is_some() {
            return Ok(Config {
                workspace: workspace.unwrap(),
                execution_root: execution_root.unwrap(),
                output_base: output_base.unwrap(),
                bazel,
                bazelrc,
                rust_analyzer_argument,
            });
        }

        // We need some info from `bazel info`. Fetch it now.
        let mut info_map = get_bazel_info(
            &bazel,
            workspace.as_deref(),
            output_base.as_deref(),
            bazelrc.as_deref(),
        )?;

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
            bazelrc,
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

    /// The path to a Bazel binary.
    #[clap(long, default_value = "bazel")]
    bazel: Utf8PathBuf,

    /// The path to a `bazelrc` configuration file.
    #[clap(long)]
    bazelrc: Option<Utf8PathBuf>,

    /// The argument that `rust-analyzer` can pass to the binary.
    rust_analyzer_argument: Option<RustAnalyzerArg>,
}
