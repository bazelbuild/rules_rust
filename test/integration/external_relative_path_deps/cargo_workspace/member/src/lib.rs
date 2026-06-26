/// Re-exports the greeting from external_crate (workspace dep).
pub fn say_hello() -> &'static str {
    external_crate::greet()
}

/// Re-exports the greeting from external_crate_b (direct dep).
pub fn say_hello_b() -> &'static str {
    external_crate_b::greet()
}

/// Re-exports the greeting from ext_ws_crate (belongs to a different Cargo workspace).
pub fn say_hello_ext_ws() -> &'static str {
    ext_ws_crate::greet()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_workspace_dep() {
        assert_eq!(say_hello(), "Hello from external_crate!");
    }

    #[test]
    fn test_direct_dep() {
        assert_eq!(say_hello_b(), "Hello from external_crate_b!");
    }

    #[test]
    fn test_ext_workspace_dep() {
        assert_eq!(say_hello_ext_ws(), "Hello from ext_ws_crate!");
    }
}
