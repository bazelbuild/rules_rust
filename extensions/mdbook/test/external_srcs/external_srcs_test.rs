use runfiles::{rlocation, Runfiles};
use std::fs;

#[test]
fn test_external_srcs_output() {
    let r = Runfiles::create().unwrap();

    let dir = rlocation!(r, env!("MDBOOK_EXTERNAL_SRCS_OUTPUT")).unwrap();

    let test_chapter = dir.join("test.html");
    let content = fs::read_to_string(test_chapter).unwrap();
    assert!(content.contains("This is a test."));
}

#[test]
fn test_local_book_mixed_output() {
    let r = Runfiles::create().unwrap();

    let dir = rlocation!(r, env!("MDBOOK_LOCAL_BOOK_MIXED_OUTPUT")).unwrap();

    let test_chapter = dir.join("test.html");
    let content = fs::read_to_string(test_chapter).unwrap();
    assert!(content.contains("This is a test."));
}
