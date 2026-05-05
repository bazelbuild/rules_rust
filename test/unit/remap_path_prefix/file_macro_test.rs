#[test]
fn file_macro_has_no_bazel_out_prefix() {
    let path = remap_file_macro_lib::get_file_path();
    assert!(
        !path.contains("bazel-out"),
        "file!() should not contain 'bazel-out' prefix, got: {path}",
    );
}
