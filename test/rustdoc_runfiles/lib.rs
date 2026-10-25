//! Read declared runtime files and call a shared library from a persisted doctest.
//!
//! ```
//! use std::path::PathBuf;
//!
//! let root = PathBuf::from(std::env::var("TEST_SRCDIR")?)
//!     .join(std::env::var("TEST_WORKSPACE")?)
//!     .join("test/rustdoc_runfiles");
//! assert_eq!(std::fs::read_to_string(root.join("crate.txt"))?, "crate data\n");
//! assert_eq!(std::fs::read_to_string(root.join("transitive.txt"))?, "transitive data\n");
//! assert_eq!(std::fs::read_to_string(root.join("extra.txt"))?, "extra dependency data\n");
//! assert_eq!(include_str!("compile.txt"), "compile data\n");
//! assert_eq!(doctest_runfiles::answer(), 42);
//! # Ok::<(), Box<dyn std::error::Error>>(())
//! ```

#![warn(rust_2018_idioms)]

#[link(name = "native_shared")]
extern "C" {
    fn native_answer() -> i32;
}

/// Return the value exported by the native runtime dependency.
pub fn answer() -> i32 {
    // SAFETY: native_answer takes no pointers and always returns a valid i32.
    unsafe { native_answer() }
}
