/// A library that depends on svh_lib. When compiled against a hollow `.rmeta`
/// of svh_lib, this crate's metadata records svh_lib's SVH at that point in
/// time. If the full `.rlib` of svh_lib was produced by a separate rustc
/// invocation (with a different HashMap seed), it may have a different SVH,
/// causing a mismatch when a downstream binary tries to link against both.
pub use svh_lib::Widget;
