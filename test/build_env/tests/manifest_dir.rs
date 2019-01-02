#[test]
pub fn test_manifest_dir() {
    let actual = include_str!(concat!(env!("CARGO_MANIFEST_DIR"), "/src/manifest_dir_file.txt"));
    let expected = "This file tests that CARGO_MANIFEST_DIR is set for the build environment\n";
    assert_eq!(actual, expected);
}
