#[test]
fn test_dep_file_name() {
    let mut expected = std::path::PathBuf::from(".");
    expected.push("test");
    expected.push("unit");
    expected.push("remap_path_prefix");
    expected.push("dep.rs");
    let expected_str = expected.to_str().unwrap();
    assert_eq!(dep::get_file_name::<()>(), expected_str);
}
