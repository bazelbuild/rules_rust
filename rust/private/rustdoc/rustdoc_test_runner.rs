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
        } else if path.file_name().is_some_and(|n| n == "rust_out") {
            bins.push(path);
        }
    }
}

fn load_test_name_map(r: &Runfiles) -> HashMap<String, String> {
    env::var(METADATA_ENV_VAR)
        .ok()
        .and_then(|rloc| rlocation!(r, &rloc))
        .and_then(|path| fs::read_to_string(path).ok())
        .map(|content| {
            content
                .lines()
                .filter_map(|line| {
                    let (mangled, human) = line.split_once('=')?;
                    Some((mangled.to_string(), human.to_string()))
                })
                .collect()
        })
        .unwrap_or_default()
}

fn test_name_for_bin(bin: &Path, name_map: &HashMap<String, String>) -> String {
    let dir_name = bin
        .parent()
        .and_then(|p| p.file_name())
        .and_then(|n| n.to_str())
        .unwrap_or("unknown");

    name_map
        .get(dir_name)
        .cloned()
        .unwrap_or_else(|| dir_name.to_string())
}

struct TestResult {
    name: String,
    passed: bool,
    exit_code: i32,
    stdout: String,
    stderr: String,
}

fn run_test_binary(bin: &Path, extra_args: &[String], name: String) -> TestResult {
    let output = Command::new(bin)
        .args(extra_args)
        .output()
        .unwrap_or_else(|e| panic!("Failed to execute {}: {}", bin.display(), e));

    TestResult {
        name,
        passed: output.status.success(),
        exit_code: output.status.code().unwrap_or(1),
        stdout: String::from_utf8_lossy(&output.stdout).into_owned(),
        stderr: String::from_utf8_lossy(&output.stderr).into_owned(),
    }
}

fn main() {
    let r = Runfiles::create().unwrap();

    let doctest_dir_rlocation = env::var(ARGS_ENV_VAR)
        .unwrap_or_else(|_| panic!("{} environment variable not set", ARGS_ENV_VAR));

    let doctest_dir = rlocation!(r, &doctest_dir_rlocation)
        .unwrap_or_else(|| panic!("Failed to locate doctests dir: {}", doctest_dir_rlocation));

    let name_map = load_test_name_map(&r);

    let extra_args: Vec<String> = env::args().skip(1).collect();
    let bins = find_test_binaries(&doctest_dir);

    let start = Instant::now();
    let mut results: Vec<TestResult> = Vec::new();

    for bin in &bins {
        let name = test_name_for_bin(bin, &name_map);
        results.push(run_test_binary(bin, &extra_args, name));
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
