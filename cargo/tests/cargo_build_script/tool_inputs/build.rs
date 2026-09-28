use std::process::Command;

fn main() {
    let tool = std::env::var("CODEGEN").expect("CODEGEN is declared");
    let result = Command::new(&tool)
        .arg(format!("{tool}.runtime"))
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
