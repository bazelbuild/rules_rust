#[test]
fn test() {
    // we should able to read rustc args from a generated file
    assert!(cfg!(test_flag));
}