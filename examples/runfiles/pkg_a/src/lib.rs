use runfiles::{rlocation, Runfiles};
use std::process;
use std::path::PathBuf;

pub fn invoke_binary(bin: PathBuf) {
    let child = process::Command::new(bin)
        .stdin(process::Stdio::piped())
        .stdout(process::Stdio::piped())
        .spawn()
        .expect("Failed to spawn command");
    let output = child.wait_with_output().expect("Failed to read stdout");
    let stdout = String::from_utf8(output.stdout).unwrap();
    println!("say_hello binary output: {}", stdout.trim());
}

pub fn invoke_say_hello_binary_with_path() {
    let r = Runfiles::create().unwrap();
    let bin = rlocation!(r, "_main/pkg_a/say_hello").unwrap();
    println!("Invoking say_hello binary with path:    {}", bin.display());

    invoke_binary(bin);
}

pub fn invoke_say_hello_binary_with_env_var() {
    let r = Runfiles::create().unwrap();
    let bin = rlocation!(r, env!("SAY_HELLO_BIN")).unwrap();
    println!("Invoking say_hello binary with env var: {}", bin.display());

    invoke_binary(bin);
}

pub fn invoke_say_hello_with_late_join() {
    let r = Runfiles::create().unwrap();
    let bin_folder = rlocation!(r, "_main/pkg_a").unwrap();

    let bin = bin_folder.join("say_hello");
    println!("Invoking pkg_a binary with late join: {}", bin.display());

    invoke_binary(bin);
}

pub fn invoke_say_hello_with_late_join_parent() {
    let r = Runfiles::create().unwrap();
    let bin_folder = rlocation!(r, "_main/pkg_a/say_hello").unwrap();

    let bin = bin_folder.parent().unwrap().join("say_hello");
    println!("Invoking pkg_a binary with late join parent: {}", bin.display());

    invoke_binary(bin);
}
