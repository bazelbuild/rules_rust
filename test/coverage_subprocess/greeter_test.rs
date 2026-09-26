//! Runs `greeter` through `CARGO_BIN_EXE_greeter`.

use std::process::Command;

#[test]
fn greeter_greets() {
    let output = Command::new(env!("CARGO_BIN_EXE_greeter"))
        .arg("bazel")
        .output()
        .expect("failed to run greeter");
    assert!(output.status.success());
    assert_eq!(String::from_utf8_lossy(&output.stdout), "hello, bazel\n");
}
