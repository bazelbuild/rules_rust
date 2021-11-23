
extern crate my_3p_lib;

pub fn greeter(name: &str) -> String {
    format!("Hello, {}!", name)
}

pub fn default_greeter() -> String {
    greeter(&my_3p_lib::world())
}

#[cfg(test)]
mod test {
    #[test]
    fn test_greeter() {
        assert_eq!(super::greeter("Bob"), "Hello, Bob!");
    }

    #[test]
    fn test_default_greeter() {
        assert_eq!(super::default_greeter(), "Hello, world!");
    }
}
