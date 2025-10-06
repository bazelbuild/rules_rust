#[test]
fn cargo_env_vars() {
    assert_eq!(env!("CARGO_CRATE_NAME"), "custom_crate_name");
}
