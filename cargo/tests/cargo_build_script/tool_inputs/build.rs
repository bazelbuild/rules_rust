use std::process::Command;

fn main() {
    let tool = std::env::var("CODEGEN").expect("CODEGEN is declared");
    // Discover the tool's own runfiles, not those inherited from this script.
    let result = Command::new(&tool)
        .env_remove("RUNFILES_DIR")
        .env_remove("RUNFILES_MANIFEST_FILE")
        .env_remove("TEST_SRCDIR")
        .output()
        .expect("run declared tool");
    assert!(
        result.status.success(),
        "{}",
        String::from_utf8_lossy(&result.stderr)
    );
    let message = String::from_utf8(result.stdout).expect("tool output is UTF-8");
    println!("cargo:rustc-env=TOOL_MESSAGE={message}");
}
