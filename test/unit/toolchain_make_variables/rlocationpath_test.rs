//! Runs the binaries named by the `*_RLOCATIONPATH` Make variables of each toolchain.

use runfiles::{rlocation, Runfiles};
use std::process::Command;

fn assert_version(rlocationpath: &str) {
    let r = Runfiles::create().unwrap();
    let bin = rlocation!(r, rlocationpath).unwrap();
    assert!(
        bin.exists(),
        "{rlocationpath} is not in the runfiles: {}",
        bin.display()
    );

    let output = Command::new(&bin)
        .arg("--version")
        .output()
        .unwrap_or_else(|e| panic!("failed to run {}: {e}", bin.display()));
    assert!(
        output.status.success(),
        "{} --version failed: {}",
        bin.display(),
        String::from_utf8_lossy(&output.stderr)
    );
}

#[test]
fn rustc() {
    assert_version(env!("RUSTC_RLOCATIONPATH"));
}

#[test]
fn rustdoc() {
    assert_version(env!("RUSTDOC_RLOCATIONPATH"));
}

#[test]
fn rustfmt() {
    assert_version(env!("RUSTFMT_RLOCATIONPATH"));
}

#[test]
fn clippy_driver() {
    assert_version(env!("CLIPPY_DRIVER_RLOCATIONPATH"));
}

#[test]
fn cargo() {
    assert_version(env!("CARGO_RLOCATIONPATH"));
}
