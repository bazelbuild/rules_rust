//! A dependency crate whose Bazel target shares its name with another crate.

/// A value from crate B.
#[repr(C)]
pub struct ValueB {
    /// The inner value.
    pub value: i32,
}
