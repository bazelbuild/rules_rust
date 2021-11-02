#[test]
pub fn test_tool_exec() {
    let tool_path = env!("TOOL_PATH");
    assert!(
        tool_path.contains("-exec-"),
        "tool_path did not contain '-exec-': {}",
        tool_path
    );
}

#[test]
pub fn test_cxxflags() {
    let cxxflags = env!("CXXFLAGS");
    assert!(
        cxxflags.contains("-DMY_DEFINE"),
        "CXXFLAGS did not contain '-DMY_DEFINE', {}",
        cxxflags
    );
}
