//! This module contains code that would normally lint for Rust, Clippy, or Rustdoc, but we
//! explicitly 'allow' said lints in the Cargo.toml of this crate.

/// Would trigger Rustdoc's `invalid_html_tags` lint.
///
/// <h1>
/// </script>
pub fn add(a: usize, b: usize) -> usize {
    // Would trigger Clippy's `absurd_extreme_comparisons` and `needless_if` lints.
    if 100 > i32::MAX {}

    a + b
}

// Would trigger Rust's `dead_code` lint.
fn sub(a: usize, b: usize) -> usize {
    a - b
}
