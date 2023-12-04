use std::panic::catch_unwind;

#[test]
fn catch_panic() {
    assert!(catch_unwind(|| panic!("Test panic")).is_err());
}
