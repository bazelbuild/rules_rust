use use_generated_src_with_crate_root_defined;

pub fn forty_two_from_external_repo() -> String {
    format!(
        "{}",
        &use_generated_src_with_crate_root_defined::forty_two_as_string()
    )
}

#[cfg(test)]
mod test {
    #[test]
    fn test_forty_two_as_string() {
        assert_eq!(super::forty_two_from_external_repo(), "42");
    }
}
