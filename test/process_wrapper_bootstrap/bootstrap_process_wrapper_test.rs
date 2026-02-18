//! Tests for the bootstrap process wrapper.

use std::env;
use std::process::Command;

use runfiles::Runfiles;

fn resolve_runfile(env_var: &str) -> String {
    let rfiles = Runfiles::create().unwrap();
    let rlocationpath = env::var(env_var).unwrap();
    runfiles::rlocation!(rfiles, rlocationpath.as_str())
        .unwrap()
        .display()
        .to_string()
}

#[test]
fn test_substitutes_pwd() {
    let wrapper = resolve_runfile("BOOTSTRAP_PROCESS_WRAPPER_RLOCATIONPATH");
    let probe = resolve_runfile("BOOTSTRAP_PROCESS_WRAPPER_PROBE_RLOCATIONPATH");
    let pwd = env::current_dir().unwrap().display().to_string();

    let output = Command::new(wrapper)
        .arg("--")
        .arg(probe)
        .arg("${pwd}/suffix")
        .output()
        .unwrap();

    assert!(
        output.status.success(),
        "wrapper failed: status={:?}, stderr={}",
        output.status,
        String::from_utf8_lossy(&output.stderr),
    );

    let stdout = String::from_utf8(output.stdout).unwrap();
    assert_eq!(stdout.trim_end(), format!("{}/suffix", pwd));
}

#[test]
fn test_propagates_exit_code() {
    let wrapper = resolve_runfile("BOOTSTRAP_PROCESS_WRAPPER_RLOCATIONPATH");
    let probe = resolve_runfile("BOOTSTRAP_PROCESS_WRAPPER_PROBE_RLOCATIONPATH");

    let status = Command::new(wrapper)
        .arg("--")
        .arg(probe)
        .env("BOOTSTRAP_PROCESS_WRAPPER_PROBE_EXIT_CODE", "23")
        .status()
        .unwrap();

    assert_eq!(status.code(), Some(23));
}
