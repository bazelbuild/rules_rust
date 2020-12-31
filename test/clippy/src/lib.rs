pub fn greeting() -> String {
    "Hello World".to_owned()
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn it_works() {
        assert_eq!(greeting(), "Hello World".to_owned());
    }
}
