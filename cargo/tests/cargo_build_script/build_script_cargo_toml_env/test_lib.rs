//! Tests that CARGO_PKG_* env vars from Cargo.toml are available to build.rs
//! at runtime via build_script_env_files.

#[test]
fn check_authors_from_cargo_toml() {
    // Authors should be colon-separated as Cargo does
    let authors = env!("TEST_AUTHORS");
    assert!(
        authors.contains("Test Author"),
        "Expected 'Test Author' in authors, got: {}",
        authors
    );
    assert!(
        authors.contains("Another Author"),
        "Expected 'Another Author' in authors, got: {}",
        authors
    );
}

#[test]
fn check_version_from_cargo_toml() {
    assert_eq!("1.2.3", env!("TEST_VERSION"));
}

#[test]
fn check_name_from_cargo_toml() {
    assert_eq!("test_cargo_toml_env", env!("TEST_NAME"));
}

#[test]
fn check_description_from_cargo_toml() {
    let desc = env!("TEST_DESCRIPTION");
    // Description should contain the multiline content (with escaped newlines)
    assert!(
        desc.contains("multiline description"),
        "Expected 'multiline description' in description, got: {}",
        desc
    );
}
