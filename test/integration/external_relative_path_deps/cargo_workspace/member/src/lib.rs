use external_crate;

/// Re-exports the greeting from external_crate.
pub fn say_hello() -> &'static str {
    external_crate::greet()
}
