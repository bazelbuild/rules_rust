//! Build script that reads CARGO_PKG_* env vars at runtime.
//! This tests that cargo_toml_env_vars + build_script_env_files correctly
//! provides these variables to build scripts, which is needed for crates
//! like rav1e that use the `built` crate.

fn main() {
    // Read env vars that should be set from cargo_toml_env_vars via build_script_env_files
    let authors = std::env::var("CARGO_PKG_AUTHORS")
        .expect("CARGO_PKG_AUTHORS should be set from Cargo.toml");
    let version = std::env::var("CARGO_PKG_VERSION")
        .expect("CARGO_PKG_VERSION should be set from Cargo.toml");
    let name =
        std::env::var("CARGO_PKG_NAME").expect("CARGO_PKG_NAME should be set from Cargo.toml");
    let description = std::env::var("CARGO_PKG_DESCRIPTION")
        .expect("CARGO_PKG_DESCRIPTION should be set from Cargo.toml");

    // Pass them to rustc so the test can verify them
    println!("cargo:rustc-env=TEST_AUTHORS={}", authors);
    println!("cargo:rustc-env=TEST_VERSION={}", version);
    println!("cargo:rustc-env=TEST_NAME={}", name);
    // Escape newlines for cargo:rustc-env
    println!(
        "cargo:rustc-env=TEST_DESCRIPTION={}",
        description.replace('\n', "\\n")
    );
}
