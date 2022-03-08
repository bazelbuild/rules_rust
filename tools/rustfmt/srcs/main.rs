use std::env;
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::str;

fn main() {
    // Gather all command line and environment settings
    let options = parse_args();

    // Gather a list of all formattable targets
    let targets = query_rustfmt_targets(&options);

    // Run rustfmt on these targets
    apply_rustfmt(&options, &targets);
}

/// Perform a `bazel` query to determine a list of Bazel targets which are to be formatted.
fn query_rustfmt_targets(options: &Config) -> Vec<String> {
    // Determine what packages to query
    let scope = match options.packages.is_empty() {
        true => "//...:all".to_owned(),
        false => {
            // Check to see if all the provided packages are actually targets
            let is_all_targets = options
                .packages
                .iter()
                .all(|pkg| match label::analyze(pkg) {
                    Ok(tgt) => tgt.name != "all",
                    Err(_) => false,
                });

            // Early return if a list of targets and not packages were provided
            if is_all_targets {
                return options.packages.clone();
            }

            options.packages.join(" + ")
        }
    };

    let query_args = vec![
        "query".to_owned(),
        format!(
            r#"kind('{types}', {scope}) except attr(tags, 'norustfmt', kind('{types}', {scope}))"#,
            types = "^rust_",
            scope = scope
        ),
    ];

    let child = Command::new(&options.bazel)
        .current_dir(&options.workspace)
        .args(query_args)
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn()
        .expect("Failed to spawn bazel query command");

    let output = child
        .wait_with_output()
        .expect("Failed to wait on spawned command");

    if !output.status.success() {
        std::process::exit(output.status.code().unwrap_or(1));
    }

    str::from_utf8(&output.stdout)
        .expect("Invalid stream from command")
        .split('\n')
        .filter(|line| !line.is_empty())
        .map(|line| line.to_string())
        .collect()
}

/// Build a list of Bazel targets using the `rustfmt_aspect` to produce the
/// arguments to use when formatting the sources of those targets.
fn generate_rustfmt_target_manifests(options: &Config, targets: &[String]) {
    let build_args = vec![
        "build".to_owned(),
        format!(
            "--aspects={}//rust:defs.bzl%rustfmt_aspect",
            env!("ASPECT_REPOSITORY")
        ),
        "--output_groups=rustfmt_manifest".to_owned(),
    ];

    let child = Command::new(&options.bazel)
        .current_dir(&options.workspace)
        .args(build_args)
        .args(targets)
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn()
        .expect("Failed to spawn command");

    let output = child
        .wait_with_output()
        .expect("Failed to wait on spawned command");

    if !output.status.success() {
        std::process::exit(output.status.code().unwrap_or(1));
    }
}

/// Run rustfmt on a set of Bazel targets
fn apply_rustfmt(options: &Config, targets: &[String]) {
    // Ensure the targets are first built and a manifest containing `rustfmt`
    // arguments are generated before formatting source files.
    generate_rustfmt_target_manifests(options, targets);

    for target in targets.iter() {
        // Replace any `:` characters and strip leading slashes
        let target_path = target.replace(':', "/").trim_start_matches('/').to_owned();

        // Find a manifest for the current target. Not all targets will have one
        let manifest = options.workspace.join("bazel-bin").join(format!(
            "{}.{}",
            &target_path,
            rustfmt_lib::RUSTFMT_MANIFEST_EXTENSION,
        ));

        if !manifest.exists() {
            continue;
        }

        // Load the manifest containing rustfmt arguments
        let rustfmt_config = rustfmt_lib::parse_rustfmt_manifest(&manifest);

        // Ignore any targets which do not have source files. This can
        // occur in cases where all source files are generated.
        if rustfmt_config.sources.is_empty() {
            continue;
        }

        // Run rustfmt
        let status = Command::new(&options.rustfmt_config.rustfmt)
            .current_dir(&options.workspace)
            .arg("--edition")
            .arg(rustfmt_config.edition)
            .arg("--config-path")
            .arg(&options.rustfmt_config.config)
            .args(rustfmt_config.sources)
            .status()
            .expect("Failed to run rustfmt");

        if !status.success() {
            std::process::exit(status.code().unwrap_or(1));
        }
    }
}

/// A struct containing details used for executing rustfmt.
#[derive(Debug)]
struct Config {
    /// The path of the Bazel workspace root.
    pub workspace: PathBuf,

    /// The Bazel executable to use for builds and queries.
    pub bazel: PathBuf,

    /// Information about the current rustfmt binary to run.
    pub rustfmt_config: rustfmt_lib::RustfmtConfig,

    /// Optionally, users can pass a list of targets/packages/scopes
    /// (eg `//my:target` or `//my/pkg/...`) to control the targets
    /// to be formatted. If empty, all targets in the workspace will
    /// be formatted.
    pub packages: Vec<String>,
}

/// Parse command line arguments and environment variables to
/// produce config data for running rustfmt.
fn parse_args() -> Config {
    Config{
        workspace: PathBuf::from(
            env::var("BUILD_WORKSPACE_DIRECTORY")
            .expect("The environment variable BUILD_WORKSPACE_DIRECTORY is required for finding the workspace root")
        ),
        bazel: PathBuf::from(
            env::var("BAZEL_REAL")
            .unwrap_or_else(|_| "bazel".to_owned())
        ),
        rustfmt_config: rustfmt_lib::parse_rustfmt_config(),
        packages: env::args().skip(1).collect(),
    }
}
