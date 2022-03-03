pub fn openssl_version() -> i64 {
    openssl::version::number()
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_opnessl_version() {
        assert_ne!(openssl_version(), 0)
    }
}
