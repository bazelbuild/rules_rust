//! Exercises two dependencies whose Bazel targets share the same name.

pub use collide_a::ValueA;
pub use collide_b::ValueB;

/// Sums the two values.
#[no_mangle]
pub extern "C" fn collide_sum(a: ValueA, b: ValueB) -> i32 {
    a.value + b.value
}
