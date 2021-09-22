use std::env;
use std::fs;
use std::path::PathBuf;

#[test]
fn can_find_the_out_dir_file() {
    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    let contents = fs::read_to_string(out_path.join("test_content.txt")).unwrap();
    assert_eq!("Test content", contents);
}
