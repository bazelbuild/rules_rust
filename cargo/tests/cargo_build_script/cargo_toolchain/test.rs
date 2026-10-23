//! The build script saw the `cargo_toolchain`'s Cargo.

#[test]
fn build_script_was_given_cargo() {
    let cargo = std::path::Path::new(env!("CARGO_FROM_BUILD_SCRIPT"));
    let stem = cargo
        .file_stem()
        .and_then(|stem| stem.to_str())
        .expect("`CARGO` ends in a file name");
    assert_eq!(stem, "cargo", "unexpected binary {}", cargo.display());
}
