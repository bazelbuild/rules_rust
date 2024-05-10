use std::path::PathBuf;
use std::process::{exit, Command};

fn main() {
    let runfiles = runfiles::Runfiles::create().unwrap();

    let rustfmt = runfiles::rlocation!(runfiles, env!("RUSTFMT"));
    if !rustfmt.exists() {
        panic!("rustfmt does not exist at: {}", rustfmt.display());
    }

    let working_directory = std::env::var_os("BUILD_WORKING_DIRECTORY")
        .map(PathBuf::from)
        .unwrap_or_else(|| std::env::current_dir().expect("Failed to get working directory"));

    let status = Command::new(rustfmt)
        .current_dir(&working_directory)
        .args(std::env::args_os().skip(1))
        .status()
        .expect("Failed to run rustfmt");
    if let Some(exit_code) = status.code() {
        exit(exit_code);
    }
    exit_for_signal(&status);
    panic!("Child rustfmt process didn't exit or get a signal - don't know how to handle it");
}

#[cfg(target_family = "unix")]
fn exit_for_signal(status: &std::process::ExitStatus) {
    use std::os::unix::process::ExitStatusExt;
    if let Some(signal) = status.signal() {
        exit(signal);
    }
}

#[cfg(not(target_family = "unix"))]
#[allow(unused)]
fn exit_for_signal(status: &std::process::ExitStatus) {}
