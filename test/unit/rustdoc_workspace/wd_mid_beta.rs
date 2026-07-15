//! The second middle crate of the test diamond dependency graph.

/// Three times the base value.
pub fn triple() -> u32 {
    wd_base::BASE * 3
}
