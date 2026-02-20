pub fn world() -> String {
    "world".to_owned()
}
pub fn hello() -> String {
    "hello".to_owned()
}

#[cfg(test)]
mod test {
    #[test]
    fn test_world() {
        assert_eq!(super::world(), "world");
    }
    #[test]
    fn test_hello() {
        assert_eq!(super::world(), "world");

        assert_eq!(super::hello(), "hello");
    }
}
