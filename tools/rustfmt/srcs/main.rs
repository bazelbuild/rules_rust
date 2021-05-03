use std::collections::VecDeque;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
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

/// A set of supported rules for use in a `bazel query` when querying for Rust targets.
const SUPPORTED_RULES: &str =
    "rust_library|rust_proc_macro|rust_shared_library|rust_static_library|rust_binary|rust_test";

/// Perform a `bazel` query to determine a list of Bazel targets which are to be formatted.
fn query_rustfmt_targets(options: &Config) -> Vec<String> {
    let scope = match &options.package {
        Some(target) => {
            if !target.ends_with(":all") && !target.ends_with("...") {
                return vec![target.to_string()];
            }
            target
        }
        None => "//...:all",
    };

    let query_args = vec![
        "query".to_owned(),
        format!(
            r#"kind('{types}', {scope}) except attr(tags, 'norustfmt|manual', kind('{types}', {scope}))"#,
            types = SUPPORTED_RULES,
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
        .split("\n")
        .filter(|line| !line.is_empty())
        .map(|line| line.to_string())
        .collect()
}

/// Build a list of Bazel targets using the `rustfmt_aspect` to produce the
/// arguments to use when formatting the sources of those targets.
fn build_rustfmt_targets(options: &Config, targets: &Vec<String>) {
    let build_args = vec![
        "build",
        "--aspects=@rules_rust//rust:defs.bzl%rustfmt_aspect",
        "--output_groups=+rustfmt",
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
fn apply_rustfmt(options: &Config, targets: &Vec<String>) {
    // Ensure the targets are first built and a manifest containing `rustfmt`
    // arguments are generated before formatting source files.
    build_rustfmt_targets(&options, &targets);

    for target in targets.iter() {
        // Replace any `:` characters and strip leading slashes
        let target_path = target.replace(":", "/").trim_start_matches("/").to_owned();

        // Load the manifest containing rustfmt arguments
        let rustfmt_config = parse_rustfmt_manifest(
            &options
                .workspace
                .join("bazel-bin")
                .join(format!("{}.rustfmt", &target_path)),
        );

        // Ignore any targets which do not have source files. This can
        // occur in cases where all source files are generated.
        if rustfmt_config.sources.is_empty() {
            continue;
        }

        // Run rustfmt
        let status = Command::new(&options.rustfmt)
            .current_dir(&options.workspace)
            .arg("--edition")
            .arg(rustfmt_config.edition)
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

    /// The rustfmt binary from the currently active toolchain
    pub rustfmt: PathBuf,

    /// The rustfmt config file containing rustfmt settings.
    /// https://rust-lang.github.io/rustfmt/
    pub config: PathBuf,

    /// An optional command line flag used to control what targets
    /// to format. Users are expected to either pass a Bazel label
    /// or a package pattern (`//my/package/...`).
    pub package: Option<String>,
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
        rustfmt: PathBuf::from(env!("RUSTFMT"))
            .canonicalize()
            .expect("Unable to find rustfmt binary"),
        config: PathBuf::from(env!("RUSTFMT_CONFIG"))
            .canonicalize()
            .expect("Unable to find rustfmt config file"),
        package: env::args().nth(1),
    }
}

/// Parse rustfmt flags from a manifest generated by builds using `rustfmt_aspect`.
fn parse_rustfmt_manifest(manifest: &Path) -> RustfmtConfig {
    let content = fs::read_to_string(manifest).expect(&format!(
        "Failed to read rustfmt manifest: {}",
        manifest.display()
    ));

    let mut lines: VecDeque<String> = content
        .split("\n")
        .into_iter()
        .map(|s| s.to_owned())
        .collect();

    RustfmtConfig {
        edition: lines
            .pop_front()
            .expect("There should always be 1 line in the manifest"),
        sources: lines.into(),
    }
}

/// A struct of target specific information for use in running `rustfmt`.
#[derive(Debug)]
struct RustfmtConfig {
    /// The Rust edition of the Bazel target
    pub edition: String,

    /// A list of all (non-generated) source files for formatting.
    pub sources: Vec<String>,
}
