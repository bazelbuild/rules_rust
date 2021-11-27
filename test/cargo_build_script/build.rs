fn main() {
    // Pass the TOOL_PATH along to the rust_test so we can assert on it.
    println!(
        "cargo:rustc-env=TOOL_PATH={}",
        std::env::var("TOOL").unwrap()
    );
    println!(
        "cargo:rustc-env=CXXFLAGS={}",
        std::env::var("CXXFLAGS").unwrap()
    );

    // Assert that the CC and CXX env vars existed and were executable.
    // We don't assert what happens when they're executed (in particular, we don't check for a
    // non-zero exit code), but this asserts that it's an existing file which is executable.
    //
    // Unfortunately we need to shlex the path, because we add a `--sysroot=...` arg to the env var.
    for env_var in &["CC", "CXX"] {
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
}
