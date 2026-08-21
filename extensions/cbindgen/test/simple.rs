//! A simple crate exposing a C API used to test `rust_cbindgen_library`.

pub use dep::Point;

/// Adds two integers.
#[no_mangle]
pub extern "C" fn simple_add(a: i32, b: i32) -> i32 {
    a + b
}

/// Creates a new `Point`.
#[no_mangle]
pub extern "C" fn simple_point_new(x: i32, y: i32) -> Point {
    Point { x, y }
}
