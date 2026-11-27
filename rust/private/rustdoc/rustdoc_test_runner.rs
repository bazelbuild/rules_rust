//! Runs pre-compiled rustdoc test binaries from a `--persist-doctests` directory
//! and reconstructs unified output matching `rustdoc --test`'s format.

use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::Instant;

use runfiles::rlocation;
use runfiles::Runfiles;

const ARGS_ENV_VAR: &str = "RUSTDOC_TEST_RUNNER_ARGS";
const METADATA_ENV_VAR: &str = "RUSTDOC_TEST_METADATA";

fn find_test_binaries(dir: &Path) -> Vec<PathBuf> {
    let mut bins = Vec::new();
    collect_rust_out(dir, &mut bins);
    bins.sort();
    bins
}

fn collect_rust_out(dir: &Path, bins: &mut Vec<PathBuf>) {
    let entries = match fs::read_dir(dir) {
        Ok(entries) => entries,
        Err(_) => return,
    };

    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            collect_rust_out(&path, bins);
        } else if path
            .file_name()
            .is_some_and(|n| n == "rust_out" || n == "rust_out.exe")
        {
            bins.push(path);
        }
    }
}

/// What `rustdoc_compile_wrapper` recorded about a persisted doctest.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
struct TestInfo {
    name: String,
    /// The doctest is expected to exit unsuccessfully.
    should_panic: bool,
    /// The doctest was only compiled and must not be executed.
    no_run: bool,
}

/// Parses one metadata line: `<mangled>=<human name>[\t<attribute>...]`.
fn parse_metadata_line(line: &str) -> Option<(String, TestInfo)> {
    let (mangled, rest) = line.split_once('=')?;
    let mut fields = rest.split('\t');
    let name = fields.next()?.to_string();
    let mut info = TestInfo {
        name,
        ..TestInfo::default()
    };
    for attribute in fields {
        match attribute {
            "should_panic" => info.should_panic = true,
            "no_run" => info.no_run = true,
            _ => {}
        }
    }
    Some((mangled.to_string(), info))
}

fn load_test_info_map(r: &Runfiles) -> HashMap<String, TestInfo> {
    env::var(METADATA_ENV_VAR)
        .ok()
        .and_then(|rloc| rlocation!(r, &rloc))
        .and_then(|path| fs::read_to_string(path).ok())
        .map(|content| content.lines().filter_map(parse_metadata_line).collect())
        .unwrap_or_default()
}

fn test_info_for_bin(bin: &Path, info_map: &HashMap<String, TestInfo>) -> TestInfo {
    let dir_name = bin
        .parent()
        .and_then(|p| p.file_name())
        .and_then(|n| n.to_str())
        .unwrap_or("unknown");

    info_map.get(dir_name).cloned().unwrap_or_else(|| TestInfo {
        name: dir_name.to_string(),
        ..TestInfo::default()
    })
}

struct TestResult {
    name: String,
    passed: bool,
    exit_code: i32,
    stdout: String,
    stderr: String,
}

/// Runs one persisted doctest the way rustdoc would.
///
/// `no_run` doctests are reported as compiled without being executed and
/// `should_panic` doctests pass only when the executable fails, mirroring
/// rustdoc's own handling of those attributes.
fn run_test_binary(bin: &Path, extra_args: &[String], info: TestInfo) -> TestResult {
    if info.no_run {
        return TestResult {
            name: format!("{} - compile", info.name),
            passed: true,
            exit_code: 0,
            stdout: String::new(),
            stderr: String::new(),
        };
    }

    let output = Command::new(bin)
        .args(extra_args)
        .output()
        .unwrap_or_else(|e| panic!("Failed to execute {}: {}", bin.display(), e));

    let mut stdout = String::from_utf8_lossy(&output.stdout).into_owned();
    let (name, passed) = if info.should_panic {
        if output.status.success() {
            stdout.push_str("Test executable succeeded, but it's marked `should_panic`.\n");
        }
        (
            format!("{} - should panic", info.name),
            !output.status.success(),
        )
    } else {
        (info.name, output.status.success())
    };

    TestResult {
        name,
        passed,
        exit_code: output.status.code().unwrap_or(1),
        stdout,
        stderr: String::from_utf8_lossy(&output.stderr).into_owned(),
    }
}

fn main() {
    let r = Runfiles::create().unwrap();

    let doctest_dir_rlocation = env::var(ARGS_ENV_VAR)
        .unwrap_or_else(|_| panic!("{} environment variable not set", ARGS_ENV_VAR));

    let doctest_dir = rlocation!(r, &doctest_dir_rlocation)
        .unwrap_or_else(|| panic!("Failed to locate doctests dir: {}", doctest_dir_rlocation));

    let info_map = load_test_info_map(&r);

    let extra_args: Vec<String> = env::args().skip(1).collect();
    let bins = find_test_binaries(&doctest_dir);

    let start = Instant::now();
    let mut results: Vec<TestResult> = Vec::new();

    for bin in &bins {
        let info = test_info_for_bin(bin, &info_map);
        results.push(run_test_binary(bin, &extra_args, info));
    }

    let elapsed = start.elapsed();
    let mut passed = 0usize;
    let mut failed = 0usize;
    let mut failed_results: Vec<&TestResult> = Vec::new();

    for result in &results {
        if result.passed {
            passed += 1;
        } else {
            failed += 1;
            failed_results.push(result);
        }
    }

    let total = passed + failed;

    println!();
    println!(
        "running {} test{}",
        total,
        if total == 1 { "" } else { "s" }
    );
    for result in &results {
        let status = if result.passed { "ok" } else { "FAILED" };
        println!("test {} ... {}", result.name, status);
    }

    if !failed_results.is_empty() {
        println!();
        println!("failures:");

        for result in &failed_results {
            println!();
            println!("---- {} stdout ----", result.name);

            if !result.stdout.trim().is_empty() {
                println!("{}", result.stdout.trim());
                println!();
            }

            println!(
                "Test executable failed (exit status: {}).",
                result.exit_code
            );
            println!();
            println!("stderr:");
            println!();

            if !result.stderr.trim().is_empty() {
                println!("{}", result.stderr.trim());
            }

            println!();
        }

        println!();
        println!("failures:");

        let mut sorted_names: Vec<&str> = failed_results.iter().map(|r| r.name.as_str()).collect();
        sorted_names.sort();

        for name in &sorted_names {
            println!("    {}", name);
        }
    }

    println!();
    if failed > 0 {
        println!(
            "test result: FAILED. {} passed; {} failed; 0 ignored; 0 measured; 0 filtered out; finished in {:.2}s",
            passed, failed, elapsed.as_secs_f64()
        );
        std::process::exit(1);
    } else {
        println!(
            "test result: ok. {} passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in {:.2}s",
            passed, elapsed.as_secs_f64()
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn metadata_lines_carry_name_and_attributes() {
        assert_eq!(
            parse_metadata_line("src_lib_rs_3_0=src/lib.rs - (line 3)"),
            Some((
                "src_lib_rs_3_0".to_string(),
                TestInfo {
                    name: "src/lib.rs - (line 3)".to_string(),
                    should_panic: false,
                    no_run: false,
                }
            ))
        );
        assert_eq!(
            parse_metadata_line("src_lib_rs_9_0=src/lib.rs - f (line 9)\tshould_panic\tno_run"),
            Some((
                "src_lib_rs_9_0".to_string(),
                TestInfo {
                    name: "src/lib.rs - f (line 9)".to_string(),
                    should_panic: true,
                    no_run: true,
                }
            ))
        );
        assert_eq!(parse_metadata_line("no separator"), None);
    }
}
