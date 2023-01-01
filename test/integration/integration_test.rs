use std::path::PathBuf;
use std::process::Command;

pub fn bazel_path() -> PathBuf {
    PathBuf::from(std::env::var("BIT_BAZEL_BINARY").expect("BIT_BAZEL_BINARY not set"))
}

pub fn workspace_path() -> PathBuf {
    PathBuf::from(std::env::var("BIT_WORKSPACE_DIR").expect("BIT_WORKSPACE_DIR not set"))
}

pub fn bazel(cmd: &str) -> Command {
    let mut command = Command::new(bazel_path());
    command.current_dir(workspace_path()).arg(cmd);
    command
}
