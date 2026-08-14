//! An example binary that depends on a dynamically linked library.

extern crate rust_dylib_lib;

fn main() {
    let val = rust_dylib_lib::example_test_dep_fn();
    assert_eq!(val, 1);
    println!("dylib dep works: {}", val);
}
