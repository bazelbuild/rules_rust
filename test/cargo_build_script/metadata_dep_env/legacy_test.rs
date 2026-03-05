#[test]
fn legacy_metadata_dep_env_is_forwarded() {
    assert_eq!(env!("METADATA_LEGACY_VALUE"), "2");
}
