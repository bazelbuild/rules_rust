//! Stands in for `anyhow`'s build script.
//!
//! `anyhow` only uses its build script to probe the compiler for optional
//! `cfg`s, so it still builds against this no-op replacement.

fn main() {}
