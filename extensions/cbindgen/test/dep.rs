//! A dependency crate used to test that cbindgen parses dependency sources.

/// A point in 2D space.
#[repr(C)]
pub struct Point {
    /// The horizontal coordinate.
    pub x: i32,
    /// The vertical coordinate.
    pub y: i32,
}
