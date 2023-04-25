mod tests {
    #[test]
    fn test_return_5_in_no_std() {
        assert_eq!(5, lib::return_5_in_no_std());
    }
}
