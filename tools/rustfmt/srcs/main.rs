use std::collections::VecDeque;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::str;

use label;

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
        "--output_groups=rustfmt_manifest",
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
            .arg("--config-path")
            .arg(&options.config)
            .args(rustfmt_config.sources)
            .status()
            .expect("Failed to run rustfmt");

        if !status.success() {
            std::process::exit(status.code().unwrap_or(1));
        }
    }
}

/// Generate an absolute path to a file without resolving symlinks
fn absolutify_existing<T: AsRef<Path>>(path: &T) -> std::io::Result<PathBuf> {
    let absolute_path = if path.as_ref().is_absolute() {
        path.as_ref().to_owned()
    } else {
        std::env::current_dir()
            .expect("Failed to get working directory")
            .join(path)
    };
    std::fs::metadata(&absolute_path).map(|_| absolute_path)
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

    /// Optionally, users can pass a list of targets/packages/scopes
    /// (eg `//my:target` or `//my/pkg/...`) to control the targets
    /// to be formatted.
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
        rustfmt: absolutify_existing(&env!("RUSTFMT"))
            .expect("Unable to find rustfmt binary"),
        config: absolutify_existing(&env!("RUSTFMT_CONFIG"))
            .expect("Unable to find rustfmt config file"),
        packages: env::args().skip(1).collect(),
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
            .expect("There should always be at least 1 line in the manifest"),
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
