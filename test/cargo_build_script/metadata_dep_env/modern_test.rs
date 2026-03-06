#[test]
fn modern_metadata_dep_env_is_forwarded() {
    assert_eq!(env!("METADATA_MODERN_VALUE"), "1");
}
