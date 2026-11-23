//! Edition 2024 doctests are merged into a single test binary by default.
//!
//! Crate level doctests have no item in their name, which the compiled
//! runner's name mapping has to handle.
//!
//! ```
//! assert_eq!(doctest_edition_2024::answer(), 42);
//! ```
//!
//! ```should_panic
//! panic!("merged doctests must isolate panics");
//! ```
//!
//! ```compile_fail
//! let answer: u32 = "forty two";
//! ```
//!
//! ```ignore
//! this is never compiled
//! ```
//!
//! `no_run` doctests are compiled but must never execute.
//!
//! ```no_run
//! std::process::exit(7);
//! ```
//!
//! Doctests marked `standalone_crate` are compiled on their own even in
//! edition 2024, so a crate can mix merged and standalone binaries.
//!
//! ```standalone_crate
//! assert_eq!(doctest_edition_2024::answer(), 42);
//! ```

#![warn(rust_2018_idioms)]

/// The answer.
///
/// ```
/// assert_eq!(doctest_edition_2024::answer(), 42);
/// ```
pub fn answer() -> u32 {
    42
}
