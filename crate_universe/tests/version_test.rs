//! A small test binary for ensuring the version of the rules matches the binary version

use std::fs::File;
use std::io::{BufRead, BufReader};
use std::path::PathBuf;

fn cargo_toml_path() -> PathBuf {
    let r = runfiles::Runfiles::create().unwrap();
    runfiles::rlocation!(r, env!("CARGO_TOML")).unwrap()
}

fn version_bzl_path() -> PathBuf {
    let r = runfiles::Runfiles::create().unwrap();
    runfiles::rlocation!(r, env!("VERSION_BZL")).unwrap()
}

#[test]
fn test_cargo_and_bazel_versions() {
    // Parse the version field from the `cargo-bazel` Cargo.toml file
    let cargo_version = {
        let cargo_path = cargo_toml_path();
        let file = File::open(cargo_path).expect("Failed to load Cargo.toml file");
        BufReader::new(file)
            .lines()
            .map_while(Result::ok)
            .find(|line| line.contains("version = "))
            .map(|line| {
                line.trim()
                    .replace("version = ", "")
                    .trim_matches('\"')
                    .to_owned()
            })
            .expect("The version.bzl file should have a line with `version = `")
    };

    // Parse the version global from the Bazel module
    let bazel_version = {
        let bazel_path = version_bzl_path();
        let file = File::open(bazel_path).expect("Failed to load versions.bzl file");
        BufReader::new(file)
            .lines()
            .map_while(Result::ok)
            .find(|line| line.contains("VERSION = "))
            .map(|line| {
                line.trim()
                    .replace("VERSION = ", "")
                    .trim_matches('\"')
                    .to_owned()
            })
            .expect("The version.bzl file should have a line with `VERSION = `")
    };

    assert_eq!(cargo_version, bazel_version, "make sure `//crate_universe:version.bzl` and `//crate_universe:Cargo.toml` have matching versions.");
}
