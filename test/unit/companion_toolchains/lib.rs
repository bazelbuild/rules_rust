//! A crate for checking which toolchain binaries its actions depend on.

/// Adds two numbers.
///
/// ```
/// assert_eq!(companion_toolchains::add(1, 2), 3);
/// ```
pub fn add(a: u32, b: u32) -> u32 {
    a + b
}
