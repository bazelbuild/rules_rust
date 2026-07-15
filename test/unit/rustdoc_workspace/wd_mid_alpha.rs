//! The first middle crate of the test diamond dependency graph.

/// Twice the base value.
pub fn double() -> u32 {
    wd_base::BASE * 2
}
