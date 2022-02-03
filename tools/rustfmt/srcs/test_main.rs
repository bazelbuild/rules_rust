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

    for manifest in options.manifests.iter() {
        // Ignore any targets which do not have source files. This can
        // occur in cases where all source files are generated.
        if manifest.sources.is_empty() {
            continue;
        }

        // Run rustfmt
        let status = Command::new(&options.rustfmt_config.rustfmt)
            .arg("--check")
            .arg("--edition")
            .arg(&manifest.edition)
            .arg("--config-path")
            .arg(&options.rustfmt_config.config)
            .args(&manifest.sources)
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

/// Parse the runfiles of the current executable for manifests generated
/// but the `rustfmt_aspect` aspect.
fn find_manifests(dir: &Path, manifests: &mut Vec<PathBuf>) {
    if dir.is_dir() {
        for entry in fs::read_dir(dir).expect("Failed to read directory contents") {
            let entry = entry.expect("Failed to read directory entry");
            let path = entry.path();
            if path.is_dir() {
                find_manifests(&path, manifests);
            } else if let Some(ext) = path.extension() {
                if ext == rustfmt_lib::RUSTFMT_MANIFEST_EXTENSION {
                    manifests.extend(vec![path]);
                }
            }
        }
    }
}

/// Parse settings from the environment into a config struct
fn parse_args() -> Config {
    let mut manifests: Vec<PathBuf> = Vec::new();
    find_manifests(
        &runfiles::find_runfiles_dir().expect("Failed to find runfiles directory"),
        &mut manifests,
    );

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
