//! ```
//! #[cfg(feature = "with_proc_macro")]
//! rustdoc_proc_macro::make_answer!();
//! ```

#[cfg(feature = "with_proc_macro")]
use rustdoc_proc_macro::make_answer;

#[cfg(feature = "with_proc_macro")]
make_answer!();

#[cfg(feature = "with_build_script")]
pub const CONST: &str = env!("CONST");

/// A value with all characters that might need special handling. Note that this
/// is duplicated in the Starlark code, which attempts to pass it.
pub const SPECIAL_VALUE: &str = ")(][ \"\\/'&^%><;:\t$#@!*-_=+`~.,?x";

/// ```
/// assert_eq!(test_crate::SPECIAL_VALUE, test_crate::SPECIAL_VALUE_FROM_RUSTC_ENV);
/// // Also try grabbing it from the environment when the doctest is built.
/// assert_eq!(test_crate::SPECIAL_VALUE, env!("SPECIAL_VALUE"));
/// ```
pub const SPECIAL_VALUE_FROM_RUSTC_ENV: &str = env!("SPECIAL_VALUE");

/// The answer to the ultimate question
/// ```
/// fn answer() -> u32 { 42 }
/// assert_eq!(answer(), 42);
/// ```
///
/// ```
/// use adder::inc;
/// assert_eq!(inc(41), 42);
/// ```
#[cfg(not(feature = "with_proc_macro"))]
pub fn answer() -> u32 {
    42
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_answer() {
        assert_eq!(answer(), 42);
    }

    #[test]
    fn test_special_value() {
        assert_eq!(SPECIAL_VALUE, SPECIAL_VALUE_FROM_RUSTC_ENV);
        // Also try grabbing it from the environment when the test is built.
        assert_eq!(SPECIAL_VALUE, env!("SPECIAL_VALUE"));
        // Also try grabbing it from the environment when the test is run.
        assert_eq!(SPECIAL_VALUE, std::env::var("SPECIAL_VALUE").unwrap());
    }
}
