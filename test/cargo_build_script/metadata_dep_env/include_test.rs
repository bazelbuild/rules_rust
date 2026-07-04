/// A `DEP_<LINKS>_INCLUDE` value that points into the producing crate's
/// `OUT_DIR` must reach the dependent's build script as a fully resolved,
/// existing path. Previously the producing crate's `OUT_DIR` was rewritten to
/// the literal `${out_dir}` token, which the dependent build-script runner
/// never resolves, so C/C++ includes such as `lz4.h` could not be found.
#[test]
fn include_path_dep_env_is_resolved() {
    assert_eq!(env!("METADATA_INCLUDE_RESOLVED"), "1");
}
