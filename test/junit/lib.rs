#[cfg(test)]
mod tests {
    #[test]
    fn test_passing() {
        assert_eq!(2 + 2, 4);
    }

    #[test]
    #[ignore]
    fn test_ignored() {}
}
