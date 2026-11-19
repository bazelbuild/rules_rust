//! Tests for the bootstrap process wrapper

use std::fs::read_to_string;
use std::path::PathBuf;

use runfiles::Runfiles;

fn process_wrapper_script() -> PathBuf {
    let rfiles = Runfiles::create().unwrap();
    runfiles::rlocation!(
        rfiles,
        "rules_rust/util/process_wrapper/private/process_wrapper.sh"
    )
    .unwrap()
}

/// Test that the shell process wrapper starts with the expected shebang to
/// avoid breaking the contract with the `bootstrap_process_wrapper` rule.
#[test]
fn test_shebang() {
    let content = read_to_string(process_wrapper_script()).unwrap();
    assert!(
        content.starts_with("#!/bin/sh"),
        "The shell script does not start with the expected shebang."
    )
}

/// Test that the shell process wrapper replaces `${pwd}` in environment
/// variables and in arguments. The real process wrapper does both.
#[cfg(unix)]
#[test]
fn test_expands_pwd_in_env() {
    use std::process::Command;

    // The wrapper replaces `${pwd}` with the physical working directory.
    let pwd = std::env::current_dir().unwrap().canonicalize().unwrap();
    let pwd = pwd.to_str().unwrap();

    let output = Command::new("/bin/sh")
        .arg(process_wrapper_script())
        .args(["--", "/bin/sh", "-c"])
        .arg(r#"printf '%s\n%s\n%s\n' "$EXPANDED" "$UNCHANGED" "$1""#)
        .args(["sh", "${pwd}/arg"])
        .env("EXPANDED", "${pwd}/env")
        .env("UNCHANGED", "no placeholder")
        .output()
        .unwrap();

    assert!(
        output.status.success(),
        "process_wrapper.sh failed: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert_eq!(
        String::from_utf8(output.stdout).unwrap(),
        format!("{pwd}/env\nno placeholder\n{pwd}/arg\n")
    );
}
