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

/// Write the param files of `test_expands_param_file`: one naming the other
/// through an `@` line, both with a `${pwd}` placeholder.
fn write_param_files(dir: &std::path::Path) -> (PathBuf, PathBuf) {
    use std::fs::write;

    let nested = dir.join("nested.params");
    write(&nested, "${pwd}/nested\n").unwrap();
    let param_file = dir.join("rustc.params");
    write(
        &param_file,
        format!(
            "${{pwd}}/first\nfeature=\"default\"\n@{}\n",
            nested.display()
        ),
    )
    .unwrap();
    (param_file, nested)
}

/// Test that the shell process wrapper rewrites a `@file` argument as
/// `@file.expanded`, with the placeholders of every line replaced and the
/// files named by `@` lines rewritten the same way. The real process
/// wrapper does the same in `options.rs`.
#[cfg(unix)]
#[test]
fn test_expands_param_file() {
    use std::process::Command;

    let pwd = std::env::current_dir().unwrap().canonicalize().unwrap();
    let pwd = pwd.to_str().unwrap();
    let dir = PathBuf::from(std::env::var("TEST_TMPDIR").unwrap()).join("sh_param_files");
    std::fs::create_dir_all(&dir).unwrap();
    let (param_file, nested) = write_param_files(&dir);

    let output = Command::new("/bin/sh")
        .arg(process_wrapper_script())
        .args(["--", "/bin/sh", "-c", r#"printf '%s\n' "$1""#, "sh"])
        .arg(format!("@{}", param_file.display()))
        .output()
        .unwrap();

    assert!(
        output.status.success(),
        "process_wrapper.sh failed: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert_eq!(
        String::from_utf8(output.stdout).unwrap(),
        format!("@{}.expanded\n", param_file.display())
    );
    assert_eq!(
        read_to_string(format!("{}.expanded", param_file.display())).unwrap(),
        format!(
            "{pwd}/first\nfeature=\"default\"\n@{}.expanded\n",
            nested.display()
        )
    );
    assert_eq!(
        read_to_string(format!("{}.expanded", nested.display())).unwrap(),
        format!("{pwd}/nested\n")
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

/// Test that the batch process wrapper rewrites a `@file` argument as
/// `@file.expanded`, with the placeholders of every line replaced and the
/// files named by `@` lines rewritten the same way. The real process
/// wrapper does the same in `options.rs`.
#[cfg(windows)]
#[test]
fn test_expands_param_file() {
    use std::process::Command;

    let pwd = std::env::current_dir().unwrap();
    let pwd = pwd.to_str().unwrap();
    let dir = PathBuf::from(std::env::var("TEST_TMPDIR").unwrap()).join("bat_param_files");
    std::fs::create_dir_all(&dir).unwrap();
    let (param_file, nested) = write_param_files(&dir);

    let output = Command::new("cmd")
        .arg("/C")
        .arg(process_wrapper_batch())
        .args(["--", "cmd", "/C", "echo"])
        .arg(format!("@{}", param_file.display()))
        .output()
        .unwrap();

    assert!(
        output.status.success(),
        "process_wrapper.bat failed: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert_eq!(
        String::from_utf8(output.stdout).unwrap().trim_end(),
        format!("@{}.expanded", param_file.display())
    );
    assert_eq!(
        read_to_string(format!("{}.expanded", param_file.display())).unwrap(),
        format!(
            "{pwd}/first\r\nfeature=\"default\"\r\n@{}.expanded\r\n",
            nested.display()
        )
    );
    assert_eq!(
        read_to_string(format!("{}.expanded", nested.display())).unwrap(),
        format!("{pwd}/nested\r\n")
    );
}
