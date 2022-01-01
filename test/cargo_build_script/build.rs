//! A Cargo build script binary used in unit tests for the Bazel `cargo_build_script` rule

/// `cargo_build_script` should always set `CARGO_ENCODED_RUSTFLAGS`
fn test_encoded_rustflags() {
    let encoded_rustflags = std::env::var("CARGO_ENCODED_RUSTFLAGS").unwrap();

    let flags: Vec<String> = encoded_rustflags
        .split('\x1f')
        .map(str::to_string)
        .collect();
    assert_eq!(flags.len(), 2);

    assert!(flags[0].starts_with("--sysroot"));

    // Ensure the `pwd` template has been resolved
    assert!(!flags[0].contains("${pwd}"));

    assert_eq!(flags[1], "--verbose");
}

fn main() {
    // Perform some unit testing
    test_encoded_rustflags();

    // Pass the TOOL_PATH along to the rust_test so we can assert on it.
    println!(
        "cargo:rustc-env=TOOL_PATH={}",
        std::env::var("TOOL").unwrap()
    );

    // Assert that the CC, CXX and LD env vars existed and were executable.
    // We don't assert what happens when they're executed (in particular, we don't check for a
    // non-zero exit code), but this asserts that it's an existing file which is executable.
    //
    // Unfortunately we need to shlex the path, because we add a `--sysroot=...` arg to the env var.
    for env_var in &["CC", "CXX", "LD"] {
        let v = std::env::var(env_var)
            .unwrap_or_else(|err| panic!("Error getting {}: {}", env_var, err));
        let (path, args) = if let Some(index) = v.find("--sysroot") {
            let (path, args) = v.split_at(index);
            (path, Some(args))
        } else {
            (v.as_str(), None)
        };
        std::process::Command::new(path)
            .args(args.into_iter())
            .status()
            .unwrap();
    }

    // Assert that some env variables are set.
    for env_var in &["CFLAGS", "CXXFLAGS", "LDFLAGS"] {
        assert!(std::env::var(env_var).is_ok());
    }
}
