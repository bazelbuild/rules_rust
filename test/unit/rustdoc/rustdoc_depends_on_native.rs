/// Calls into a Rust dependency that links a native library.
/// ```
/// assert_eq!(lib_nodep_with_cc::native_answer(), 42);
/// ```
pub fn answer() -> u32 {
    lib_nodep_with_cc::native_answer()
}
