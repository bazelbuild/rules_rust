use runfiles::{rlocation, Runfiles};
use std::fs;

#[test]
fn test_flattening_output() {
    let r = Runfiles::create().unwrap();

    let dir = rlocation!(r, env!("MDBOOK_FLATTENING_OUTPUT")).unwrap();

    // Verify index.html exists
    let index = dir.join("index.html");
    assert!(index.exists(), "index.html should exist");
    let content = fs::read_to_string(index).unwrap();
    assert!(content.contains("This is a test."));

    // Verify that the custom CSS was correctly found and included in the output.
    // mdBook copies additional-css files into the output directory.
    let css = dir.join("theme/css/custom.css");
    assert!(
        css.exists(),
        "custom.css should have been copied to the output"
    );
    let css_content = fs::read_to_string(css).unwrap();
    assert!(css_content.contains("background-color: red;"));
}
