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

#[cfg(windows)]
fn process_wrapper_batch() -> PathBuf {
    let rfiles = Runfiles::create().unwrap();
    runfiles::rlocation!(
        rfiles,
        "rules_rust/util/process_wrapper/private/process_wrapper.bat"
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

/// Test that the batch process wrapper replaces `${pwd}` in environment
/// variables and in arguments. The real process wrapper does both.
///
/// The child command is `cmd /C set <prefix>`, which prints every variable
/// with that prefix from the child's own environment. This avoids `%VAR%`
/// expansions in the arguments, which cmd would expand too early.
#[cfg(windows)]
#[test]
fn test_expands_pwd_in_env() {
    use std::process::Command;

    // The wrapper replaces `${pwd}` with `%CD%`.
    let pwd = std::env::current_dir().unwrap();
    let pwd = pwd.to_str().unwrap();

    // Run through `cmd /C` so the arguments reach the batch file verbatim.
    // When a `.bat` is the program, `Command` quotes arguments that contain
    // `{}` and the quotes would then show up in the output of `echo`.
    let run = |args: &[&str]| {
        let output = Command::new("cmd")
            .arg("/C")
            .arg(process_wrapper_batch())
            .arg("--")
            .args(args)
            .env("RULES_RUST_TEST_EXPANDED", "${pwd}\\env")
            .env("RULES_RUST_TEST_UNCHANGED", "no placeholder")
            .output()
            .unwrap();
        assert!(
            output.status.success(),
            "process_wrapper.bat failed: {}",
            String::from_utf8_lossy(&output.stderr)
        );
        let stdout = String::from_utf8(output.stdout).unwrap();
        stdout
            .lines()
            .map(|line| line.trim_end().to_owned())
            .collect::<Vec<_>>()
    };

    assert_eq!(
        run(&["cmd", "/C", "set", "RULES_RUST_TEST_"]),
        vec![
            format!("RULES_RUST_TEST_EXPANDED={pwd}\\env"),
            "RULES_RUST_TEST_UNCHANGED=no placeholder".to_owned(),
        ]
    );
    assert_eq!(
        run(&["cmd", "/C", "echo", "${pwd}\\arg"]),
        vec![format!("{pwd}\\arg")]
    );
}
