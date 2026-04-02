//! This script collects code coverage data for Rust sources, after the tests
//! were executed.
//!
//! By taking advantage of Bazel C++ code coverage collection, this script is
//! able to be executed by the existing coverage collection mechanics.
//!
//! Bazel uses the lcov tool for gathering coverage data. There is also
//! an experimental support for clang llvm coverage, which uses the .profraw
//! data files to compute the coverage report.
//!
//! This script assumes the following environment variables are set:
//! - `COVERAGE_DIR``: Directory containing metadata files needed for coverage collection (e.g. gcda files, profraw).
//! - `COVERAGE_OUTPUT_FILE`: The coverage action output path.
//! - `ROOT`: Location from where the code coverage collection was invoked.
//! - `RUNFILES_DIR`: Location of the test's runfiles.
//! - `VERBOSE_COVERAGE`: Print debug info from the coverage scripts
//!
//! The script looks in $COVERAGE_DIR for the Rust metadata coverage files
//! (profraw) and uses lcov to get the coverage data. The coverage data
//! is placed in $COVERAGE_DIR as a `coverage.dat` file.

use std::env;
use std::fs;
use std::path::Path;
use std::path::PathBuf;
use std::process;

macro_rules! debug_log {
    ($($arg:tt)*) => {
        if env::var("VERBOSE_COVERAGE").is_ok() {
            eprintln!($($arg)*);
        }
    };
}

fn find_metadata_file(execroot: &Path, runfiles_dir: &Path, path: &str) -> PathBuf {
    if execroot.join(path).exists() {
        return execroot.join(path);
    }

    debug_log!(
        "File does not exist in execroot, falling back to runfiles: {}",
        path
    );

    runfiles_dir.join(path)
}

/// Derive the bindir (e.g., "bazel-out/k8-fastbuild/bin") from a bazel output path.
/// Works with paths like "bazel-out/k8-fastbuild/testlogs/..." or runfiles paths.
fn get_bindir(path: &Path, execroot: &Path) -> Option<PathBuf> {
    let relative = path.strip_prefix(execroot).unwrap_or(path);
    let components: Vec<_> = relative.components().take(2).collect();
    if components.len() >= 2 {
        let base: PathBuf = components.iter().collect();
        Some(base.join("bin"))
    } else {
        None
    }
}

fn find_test_binary(execroot: &Path, runfiles_dir: Option<&Path>, coverage_dir: &Path) -> PathBuf {
    let test_binary_env = env::var("TEST_BINARY").unwrap();

    // Try runfiles first if available
    if let Some(runfiles) = runfiles_dir {
        let test_binary = runfiles
            .join(env::var("TEST_WORKSPACE").unwrap_or_default())
            .join(&test_binary_env);
        if test_binary.exists() {
            return test_binary;
        }
        // Try deriving bindir from runfiles path
        if let Some(bindir) = get_bindir(runfiles, execroot) {
            let test_binary = execroot.join(bindir).join(&test_binary_env);
            if test_binary.exists() {
                return test_binary;
            }
        }
    }

    // Derive bindir from coverage_dir
    if let Some(bindir) = get_bindir(coverage_dir, execroot) {
        let test_binary = execroot.join(&bindir).join(&test_binary_env);
        debug_log!("Using test binary: {}", test_binary.display());
        return test_binary;
    }

    execroot.join(&test_binary_env)
}

fn main() {
    let coverage_dir = PathBuf::from(env::var("COVERAGE_DIR").unwrap());
    let execroot = PathBuf::from(env::var("ROOT").unwrap());

    // RUNFILES_DIR may not be set in newer Bazel versions during coverage post-processing.
    // Try BAZEL_COVERAGE_INTERNAL_RUNFILES_DIR as fallback.
    let runfiles_dir = env::var("RUNFILES_DIR")
        .ok()
        .filter(|s| !s.is_empty())
        .or_else(|| {
            env::var("BAZEL_COVERAGE_INTERNAL_RUNFILES_DIR")
                .ok()
                .filter(|s| !s.is_empty())
        })
        .map(|dir| {
            let path = PathBuf::from(dir);
            if path.is_absolute() {
                path
            } else {
                execroot.join(path)
            }
        });

    debug_log!("ROOT: {}", execroot.display());
    debug_log!("RUNFILES_DIR: {:?}", runfiles_dir);

    let coverage_output_file = coverage_dir.join("coverage.dat");
    let profdata_file = coverage_dir.join("coverage.profdata");
    let llvm_cov = find_metadata_file(
        &execroot,
        runfiles_dir.as_deref().unwrap_or(&execroot),
        &env::var("RUST_LLVM_COV").unwrap(),
    );
    let llvm_profdata = find_metadata_file(
        &execroot,
        runfiles_dir.as_deref().unwrap_or(&execroot),
        &env::var("RUST_LLVM_PROFDATA").unwrap(),
    );
    let test_binary = find_test_binary(&execroot, runfiles_dir.as_deref(), &coverage_dir);
    let profraw_files: Vec<PathBuf> = fs::read_dir(coverage_dir)
        .unwrap()
        .flatten()
        .filter_map(|entry| {
            let path = entry.path();
            if let Some(ext) = path.extension() {
                if ext == "profraw" {
                    return Some(path);
                }
            }
            None
        })
        .collect();

    let mut llvm_profdata_cmd = process::Command::new(llvm_profdata);
    llvm_profdata_cmd
        .arg("merge")
        .arg("--sparse")
        .args(profraw_files)
        .arg("--output")
        .arg(&profdata_file);

    debug_log!("Spawning {:#?}", llvm_profdata_cmd);
    let status = llvm_profdata_cmd
        .status()
        .expect("Failed to spawn llvm-profdata process");

    if !status.success() {
        process::exit(status.code().unwrap_or(1));
    }

    let mut llvm_cov_cmd = process::Command::new(llvm_cov);
    llvm_cov_cmd
        .arg("export")
        .arg("-format=lcov")
        .arg("-instr-profile")
        .arg(&profdata_file)
        .arg("-ignore-filename-regex='.*external/.+'")
        .arg("-ignore-filename-regex='/tmp/.+'")
        .arg(format!("-path-equivalence=.,'{}'", execroot.display()))
        .arg(test_binary)
        .stdout(process::Stdio::piped());

    debug_log!("Spawning {:#?}", llvm_cov_cmd);
    let child = llvm_cov_cmd
        .spawn()
        .expect("Failed to spawn llvm-cov process");

    let output = child.wait_with_output().expect("llvm-cov process failed");

    // Parse the child process's stdout to a string now that it's complete.
    debug_log!("Parsing llvm-cov output");
    let report_str = std::str::from_utf8(&output.stdout).expect("Failed to parse llvm-cov output");

    debug_log!("Writing output to {}", coverage_output_file.display());
    fs::write(
        coverage_output_file,
        report_str
            .replace("#/proc/self/cwd/", "")
            .replace(&execroot.display().to_string(), ""),
    )
    .unwrap();

    // Destroy the intermediate binary file so lcov_merger doesn't parse it twice.
    debug_log!("Cleaning up {}", profdata_file.display());
    fs::remove_file(profdata_file).unwrap();

    debug_log!("Success!");
}
