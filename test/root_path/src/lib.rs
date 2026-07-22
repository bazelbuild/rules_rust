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
}
