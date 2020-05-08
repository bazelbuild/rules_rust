#[test]
pub fn test_manifest_dir() {
    let actual = include_str!(concat!(env!("CARGO_MANIFEST_DIR"), "/src/manifest_dir_file.txt"));
    let expected = "This file tests that CARGO_MANIFEST_DIR is set for the build environment\n";
    assert_eq!(actual, expected);
}

#[test]
pub fn test_arbitrary_env() {
    assert_eq!(env!("ARBITRARY_ENV1"), "Value1");
    assert_eq!(env!("ARBITRARY_ENV2"), "Value2");
}
