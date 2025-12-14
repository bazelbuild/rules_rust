extern crate insta;

use std::env;

#[test]
fn test_hello_world() {
    insta::assert_debug_snapshot!("hello world!");
}

#[test]
fn test_foo_bar() {
    insta::assert_debug_snapshot!(vec![1, 2, 3, 4, 5]);
}

#[test]
fn test_moo_cow() {
    insta::assert_debug_snapshot!(("moo", "moooooooo!"));
}
