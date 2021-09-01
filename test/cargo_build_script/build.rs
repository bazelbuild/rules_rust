fn main() {
    // Pass the TOOL_PATH along to the rust_test so we can assert on it.
    println!(
        "cargo:rustc-env=TOOL_PATH={}",
        std::env::var("TOOL").unwrap()
    );
}
