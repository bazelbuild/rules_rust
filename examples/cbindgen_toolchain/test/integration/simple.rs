//! A simple crate exposing a C API for the `rust_cbindgen_library` example.

/// A simple value exported to the generated header.
pub const SIMPLE_VALUE: i64 = 42;

/// Returns a well known value.
#[no_mangle]
pub extern "C" fn simple_function() -> i64 {
    1337
}
