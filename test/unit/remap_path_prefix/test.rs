#[test]
fn test_dep_file_name() {
    let mut expected = std::path::PathBuf::from(".");
    // After the ., the path components appear to be joined with / on all platforms.
    // This is probably a rustc bug we should report.
    expected.push("test/unit/remap_path_prefix/dep.rs");
    let expected_str = expected.to_str().unwrap();
    assert_eq!(dep::get_file_name::<()>(), expected_str);
}
