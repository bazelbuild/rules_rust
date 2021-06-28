#![deny(clippy::assertions_on_constants)]
#[test]
fn test() {
    // we should able to read rustc args from a generated file
    assert!(cfg!(test_flag));
}
