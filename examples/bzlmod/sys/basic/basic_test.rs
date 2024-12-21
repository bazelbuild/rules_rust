use std::io::Write;
use std::process;

use runfiles::{rlocation, Runfiles};

#[test]
fn test_call() {
    let r = Runfiles::create().unwrap();

    let bin = rlocation!(r, env!("HELLO_SYS_RLOCATIONPATH")).unwrap();

    let mut child = process::Command::new(bin)
        .stdin(process::Stdio::piped())
        .stdout(process::Stdio::piped())
        .spawn()
        .expect("Failed to spawn command");

    // Get the stdin handle of the child process
    if let Some(mut stdin) = child.stdin.take() {
        // Write text to the stdin of the child process
        let input = "Hello world";
        stdin
            .write_all(input.as_bytes())
            .expect("Failed to write to stdin");
    }

    // Wait for the child process to finish
    let output = child.wait_with_output().expect("Failed to read stdout");

    let stdout = String::from_utf8(output.stdout).unwrap();
    assert_eq!("Compressed 11 to 50 bytes", stdout.trim());
}
