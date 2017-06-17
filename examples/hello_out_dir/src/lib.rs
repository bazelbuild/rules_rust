#[cfg(test)]
mod test {
    #[test]
    fn test_out_dir_contents() {
        let secret_number = include!(concat!(env!("OUT_DIR"), "/body.rs"));
        assert_eq!(secret_number, 8888);
    }
}
