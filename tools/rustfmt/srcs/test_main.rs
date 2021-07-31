use std::ffi::OsStr;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

fn main() {
    // Gather all and environment settings
    let options = parse_args();

    // Perform rustfmt for each manifest available
    run_rustfmt(&options);
}

/// Run rustfmt on a set of Bazel targets
fn run_rustfmt(options: &Config) {
    // In order to ensure the test parses all sources, we separately
    // track whether or not a failure has occured when checking formatting.
    let mut is_failure: bool = false;

    let runfiles = runfiles::Runfiles::create().expect("Failed to find runfiles");

    for manifest in options.manifests.iter() {
        // Ignore any targets which do not have source files. This can
        // occur in cases where all source files are generated.
        if manifest.sources.is_empty() {
            continue;
        }

        let runfiles_sources = manifest
            .sources
            .iter()
            .map(|p| {
                rustfmt_lib::from_slash(runfiles.rlocation(rustfmt_lib::current_dir_name().join(p)))
            })
            .collect::<Vec<_>>();

        // Run rustfmt
        let status = Command::new(&options.rustfmt_config.rustfmt)
            .arg("--check")
            .arg("--edition")
            .arg(&manifest.edition)
            .arg("--config-path")
            .arg(&options.rustfmt_config.config)
            .args(&runfiles_sources)
            .status()
            .expect("Failed to run rustfmt");

        if !status.success() {
            is_failure = true;
        }
    }

    if is_failure {
        std::process::exit(1);
    }
}

/// A struct containing details used for executing rustfmt.
#[derive(Debug)]
struct Config {
    /// Information about the current rustfmt binary to run.
    pub rustfmt_config: rustfmt_lib::RustfmtConfig,

    /// A list of manifests containing information about sources
    /// to check using rustfmt.
    pub manifests: Vec<rustfmt_lib::RustfmtManifest>,
}

/// Parse settings from the environment into a config struct
fn parse_args() -> Config {
    let runfiles = runfiles::Runfiles::create().expect("Failed to find runfiles");
    let manifests = runfiles
        .list_files()
        .into_iter()
        .filter(|path| {
            path.extension() == Some(OsStr::new(rustfmt_lib::RUSTFMT_MANIFEST_EXTENSION))
        })
        .collect::<Vec<_>>();

    if manifests.is_empty() {
        panic!("No manifests were found");
    }

    Config {
        rustfmt_config: rustfmt_lib::parse_rustfmt_config(),
        manifests: manifests
            .iter()
            .map(|manifest| rustfmt_lib::parse_rustfmt_manifest(manifest))
            .collect(),
    }
}
