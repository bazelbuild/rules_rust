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
//! - `COVERAGE_DIR`: Directory containing metadata files needed for coverage collection (e.g. gcda files, profraw).
//! - `COVERAGE_OUTPUT_FILE`: The coverage action output path.
//! - `ROOT`: Location from where the code coverage collection was invoked.
//! - `RUNFILES_DIR` (optional): Location of the test's runfiles. Not set in split
//!   coverage postprocessing mode (`--experimental_split_coverage_postprocessing`).
//! - `TEST_BINARY`: Runfiles-relative path to the test binary (used when `RUNFILES_DIR` is absent).
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

fn find_test_binary(execroot: &Path, runfiles_dir: &Path) -> PathBuf {
    let test_binary = runfiles_dir
        .join(env::var("TEST_WORKSPACE").unwrap())
        .join(env::var("TEST_BINARY").unwrap());

    if !test_binary.exists() {
        let configuration = runfiles_dir
            .strip_prefix(execroot)
            .expect("RUNFILES_DIR should be relative to ROOT")
            .components()
            .enumerate()
            .filter_map(|(i, part)| {
                // Keep only `bazel-out/<configuration>/bin`
                if i < 3 {
                    Some(PathBuf::from(part.as_os_str()))
                } else {
                    None
                }
            })
            .fold(PathBuf::new(), |mut path, part| {
                path.push(part);
                path
            });

        let test_binary = execroot
            .join(configuration)
            .join(env::var("TEST_BINARY").unwrap());

        debug_log!(
            "TEST_BINARY is not found in runfiles. Falling back to: {}",
            test_binary.display()
        );

        test_binary
    } else {
        test_binary
    }
}

/// Derive the Bazel output configuration bin directory from `COVERAGE_DIR`.
///
/// `COVERAGE_DIR` follows the stable convention `bazel-out/<config>/testlogs/...`.
/// Extracting the first two path components gives `bazel-out/<config>`, which
/// combined with `bin` yields the directory containing the test binary.
fn config_bin_dir(execroot: &Path, coverage_dir: &Path) -> PathBuf {
    let coverage_rel = coverage_dir.strip_prefix(execroot).unwrap_or(coverage_dir);
    let mut components = coverage_rel.components();
    let bazel_out = components
        .next()
        .expect("COVERAGE_DIR should have at least 2 path components");
    let config = components
        .next()
        .expect("COVERAGE_DIR should have at least 2 path components");
    PathBuf::from(bazel_out.as_os_str())
        .join(config.as_os_str())
        .join("bin")
}

fn main() {
    let coverage_dir = PathBuf::from(env::var("COVERAGE_DIR").unwrap());
    let execroot = PathBuf::from(env::var("ROOT").unwrap());

    // RUNFILES_DIR is explicitly removed by Bazel in split coverage
    // postprocessing mode (--experimental_split_coverage_postprocessing).
    let runfiles_dir = env::var("RUNFILES_DIR")
        .map(|d| {
            let p = PathBuf::from(d);
            if p.is_absolute() {
                p
            } else {
                execroot.join(p)
            }
        })
        .ok();

    debug_log!("ROOT: {}", execroot.display());
    match runfiles_dir {
        Some(ref rd) => debug_log!("RUNFILES_DIR: {}", rd.display()),
        None => debug_log!("RUNFILES_DIR: not set (split coverage postprocessing)"),
    }

    let coverage_output_file = coverage_dir.join("coverage.dat");
    let profdata_file = coverage_dir.join("coverage.profdata");
    let llvm_cov_path = env::var("RUST_LLVM_COV").unwrap();
    let llvm_profdata_path = env::var("RUST_LLVM_PROFDATA").unwrap();
    let llvm_cov = match runfiles_dir {
        Some(ref rd) => find_metadata_file(&execroot, rd, &llvm_cov_path),
        None => execroot.join(&llvm_cov_path),
    };
    let llvm_profdata = match runfiles_dir {
        Some(ref rd) => find_metadata_file(&execroot, rd, &llvm_profdata_path),
        None => execroot.join(&llvm_profdata_path),
    };
    let test_binary = match runfiles_dir {
        Some(ref rd) => find_test_binary(&execroot, rd),
        None => {
            let bin_dir = config_bin_dir(&execroot, &coverage_dir);
            let test_binary = execroot
                .join(bin_dir)
                .join(env::var("TEST_BINARY").unwrap());
            debug_log!("Resolved TEST_BINARY to: {}", test_binary.display());
            test_binary
        }
    };
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
        .arg("-ignore-filename-regex=.*external/.+")
        .arg("-ignore-filename-regex=/tmp/.+");

    // Allow additional ignore patterns via RUST_COVERAGE_IGNORE_REGEX env var
    // (comma-separated list of regexes passed to llvm-cov -ignore-filename-regex).
    if let Ok(extra) = env::var("RUST_COVERAGE_IGNORE_REGEX") {
        for pattern in extra.split(',') {
            let pattern = pattern.trim();
            if !pattern.is_empty() {
                llvm_cov_cmd.arg(format!("-ignore-filename-regex={}", pattern));
            }
        }
    }

    llvm_cov_cmd
        .arg(format!("-path-equivalence=.,{}", execroot.display()))
        .arg(test_binary)
        .stdout(process::Stdio::piped())
        .stderr(process::Stdio::piped());

    debug_log!("Spawning {:#?}", llvm_cov_cmd);
    let child = llvm_cov_cmd
        .spawn()
        .expect("Failed to spawn llvm-cov process");

    let output = child.wait_with_output().expect("llvm-cov process failed");

    if !output.status.success() {
        let stderr = std::str::from_utf8(&output.stderr).unwrap_or("<non-utf8>");
        if stderr.contains("no coverage data found") {
            debug_log!("No coverage data found in binary; writing empty report");
            fs::write(&coverage_output_file, "").unwrap();
            fs::remove_file(&profdata_file).ok();
            return;
        }
        eprintln!("llvm-cov export failed:\n{}", stderr);
        process::exit(output.status.code().unwrap_or(1));
    }

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
