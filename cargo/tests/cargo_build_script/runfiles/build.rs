//! A Cargo build script binary used in unit tests for the Bazel
//! `cargo_build_script` rule.
//!
//! Asserts that:
//!   1. Tools (which are `data` of the underlying `rust_binary`) are locatable
//!      via the runfiles library (RUNFILES_DIR).
//!   2. Data (which is `data` of `cargo_build_script`) is NOT locatable via
//!      the runfiles library.
//!   3. Data IS locatable relative to `CARGO_MANIFEST_DIR`, like a normal
//!      source file alongside `build.rs`.

fn main() {
    let r = runfiles::Runfiles::create().expect(
        "Build scripts should be able to construct a Runfiles object — \
         RUNFILES_DIR or RUNFILES_MANIFEST_FILE must be exposed by the build script runner",
    );

    let tool_rlocation = env!("TOOL_RLOCATION");
    let tool_path = r.rlocation(tool_rlocation).unwrap_or_else(|| {
        panic!(
            "Tool must be locatable via the runfiles library (rlocation: {})",
            tool_rlocation,
        )
    });
    assert!(
        tool_path.exists(),
        "Tool must exist at the path returned by the runfiles library: {}",
        tool_path.display(),
    );

    let data_rlocation = std::path::Path::new(tool_rlocation).with_file_name("data.txt");
    let data_rlocation = data_rlocation
        .to_str()
        .expect("Data rlocation path must be UTF-8");
    let data_via_runfiles = r.rlocation(data_rlocation);
    if let Some(path) = data_via_runfiles {
        assert!(
            !path.exists(),
            "Data must NOT be locatable via the runfiles library, but found it at {} (rlocation: {})",
            path.display(),
            data_rlocation,
        );
    }

    let manifest_dir =
        std::env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR should be set");
    let data_in_manifest = std::path::Path::new(&manifest_dir).join("data.txt");
    assert!(
        data_in_manifest.exists(),
        "Data must be locatable relative to CARGO_MANIFEST_DIR at {}",
        data_in_manifest.display(),
    );
}
