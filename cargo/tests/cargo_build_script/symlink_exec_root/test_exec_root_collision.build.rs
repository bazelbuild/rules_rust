//! A Cargo build script binary used in unit tests for the Bazel `cargo_build_script` rule

fn main() {
    // `external` is a top-level exec root entry, so the runner will try to symlink it into
    // CARGO_MANIFEST_DIR, where this data file has already created a real directory of the
    // same name. The pre-existing directory must win, and must still be readable.
    let collision = std::path::Path::new("external/exec_root_collision.txt");
    assert!(
        collision.is_file(),
        "'external/exec_root_collision.txt' must be readable from CARGO_MANIFEST_DIR"
    );
    assert_eq!(
        std::fs::read_to_string(collision).unwrap(),
        "This file makes 'external' a real directory in CARGO_MANIFEST_DIR."
    );
}
