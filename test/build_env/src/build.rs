//! A Cargo build script which tests the functionality of the `rules_rust`
//! `cargo_build_script` rule.

/// Confirm that variables set at compile time match the same one set at runtime
fn test_cargo_compile_and_runtime_vars() {
    assert_eq!(
        env!("CARGO_MANIFEST_DIR"),
        std::env::var("CARGO_MANIFEST_DIR").unwrap()
    );
    assert_eq!(
        env!("CARGO_PKG_NAME"),
        std::env::var("CARGO_PKG_NAME").unwrap()
    );
}

fn main() {
    test_cargo_compile_and_runtime_vars();

    println!(
        "cargo:rustc-env=CARGO_PKG_NAME_FROM_BUILD_SCRIPT={}",
        env!("CARGO_PKG_NAME")
    );
    println!(
        "cargo:rustc-env=CARGO_CRATE_NAME_FROM_BUILD_SCRIPT={}",
        env!("CARGO_CRATE_NAME")
    );
    println!("cargo:rustc-env=HAS_TRAILING_SLASH=foo\\");
}
