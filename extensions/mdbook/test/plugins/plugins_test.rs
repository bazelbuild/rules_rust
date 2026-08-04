use runfiles::{rlocation, Runfiles};
use std::fs;

#[test]
fn test_preprocessor_output() {
    let r = Runfiles::create().unwrap();

    let dir = rlocation!(r, env!("MDBOOK_PLUGINS_OUTPUT")).unwrap();

    let index_html = dir.join("index.html");
    let content = fs::read_to_string(index_html).unwrap();

    // Check if the preprocessor successfully replaced {{secret}} with 42
    assert!(content.contains("The secret is: 42."));
    assert!(!content.contains("{{secret}}"));
}
