// TODO: Remove this exception after https://github.com/rust-lang/rust-clippy/pull/10055 is released
#![allow(clippy::uninlined_format_args)]

#[test]
pub fn test_tool_exec() {
    let tool_path = env!("TOOL_PATH");
    assert!(
        tool_path.contains("-exec-"),
        "tool_path did not contain '-exec-': {}",
        tool_path
    );
}
