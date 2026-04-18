#[test]
fn flat_file_copied_to_out_dir() {
    let contents = include_str!(concat!(env!("OUT_DIR"), "/greeting.txt"));
    assert_eq!(contents, "Hello from OUT_DIR");
}

#[test]
fn nested_file_copied_to_out_dir() {
    let contents = include_str!(concat!(env!("OUT_DIR"), "/nested/config.txt"));
    assert_eq!(contents, "key=value");
}
