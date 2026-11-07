// Regression for https://github.com/bazelbuild/rules_rust/issues/4297.
#[test]
fn declared_tool_and_runtime_file_reach_the_build_script() {
    assert_eq!(env!("TOOL_MESSAGE"), "declared runtime input");
}
