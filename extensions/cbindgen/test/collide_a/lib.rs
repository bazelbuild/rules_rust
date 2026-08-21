//! A dependency crate whose Bazel target shares its name with another crate.

/// A value from crate A.
#[repr(C)]
pub struct ValueA {
    /// The inner value.
    pub value: i32,
}
