#[test]
pub fn test_tool_exec() {
    let tool_path = env!("TOOL_PATH");
    assert!(
        tool_path.contains("-exec-") || tool_path.contains("-exec/bin/"),
        "tool_path did not contain '-exec-' or '-exec/bin'\n`{}`",
        tool_path,
    );
}
