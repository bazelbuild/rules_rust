//! The launcher must rewrite `rustc_env` values that point at generated
//! `compile_data` through `$(execpath ...)`, not only the command line.
//!
//! rustdoc expands `include_str!` while collecting doctests, so the path has
//! to resolve inside runfiles where the generated root is gone.
//!
//! ```
//! assert_eq!(
//!     rustdoc_generated_compile_data::GENERATED_INPUT.trim(),
//!     "from a generated compile_data file",
//! );
//! ```

#![warn(rust_2018_idioms)]

/// The contents of a generated `compile_data` file embedded at compile time.
pub const GENERATED_INPUT: &str = include_str!(env!("GENERATED_INPUT_PATH"));
