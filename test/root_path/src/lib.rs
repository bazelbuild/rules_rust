pub mod submodule;

pub fn greeting() -> &'static str {
    submodule::msg()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_greeting() {
        assert_eq!(greeting(), "Hello from directory artifact!");
    }

    #[test]
    #[cfg(test_cbs)]
    fn test_cbs_env() {
        assert_eq!(
            env!("GREETING_FROM_CBS"),
            "Hello from cargo build script!"
        );
    }
}
