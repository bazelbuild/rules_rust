//! include_str! resolves at compile time against the TreeArtifact captured by Bazel.
//! If the runner failed to strip config.log / *.d / *.pc files, the TreeArtifact hash
//! would change on every run, causing unnecessary rebuilds for all downstream crates.

const OUTPUT: &str = include_str!(concat!(env!("OUT_DIR"), "/output.txt"));

#[test]
fn legitimate_output_survives_nondeterministic_file_removal() {
    assert_eq!(OUTPUT, "legitimate output");
}

// Verify that volatile files written by the build script are absent from the
// captured OUT_DIR TreeArtifact. The build script wrote each of these; the
// cargo_build_script_runner must have removed them before Bazel snapshotted
// the directory.

#[test]
fn config_log_removed() {
    assert!(
        !std::path::Path::new(concat!(env!("OUT_DIR"), "/config.log")).exists(),
        "config.log should have been removed from OUT_DIR"
    );
}

#[test]
fn config_status_removed() {
    assert!(
        !std::path::Path::new(concat!(env!("OUT_DIR"), "/config.status")).exists(),
        "config.status should have been removed from OUT_DIR"
    );
}

#[test]
fn makefile_removed() {
    assert!(
        !std::path::Path::new(concat!(env!("OUT_DIR"), "/Makefile")).exists(),
        "Makefile should have been removed from OUT_DIR"
    );
}

#[test]
fn makefile_config_removed() {
    assert!(
        !std::path::Path::new(concat!(env!("OUT_DIR"), "/Makefile.config")).exists(),
        "Makefile.config should have been removed from OUT_DIR"
    );
}

#[test]
fn config_cache_removed() {
    assert!(
        !std::path::Path::new(concat!(env!("OUT_DIR"), "/config.cache")).exists(),
        "config.cache should have been removed from OUT_DIR"
    );
}

#[test]
fn dot_d_files_removed() {
    assert!(
        !std::path::Path::new(concat!(env!("OUT_DIR"), "/foo.d")).exists(),
        "foo.d should have been removed from OUT_DIR"
    );
    assert!(
        !std::path::Path::new(concat!(env!("OUT_DIR"), "/baz.d")).exists(),
        "baz.d should have been removed from OUT_DIR"
    );
}

#[test]
fn dot_pc_file_removed() {
    assert!(
        !std::path::Path::new(concat!(env!("OUT_DIR"), "/foo.pc")).exists(),
        "foo.pc should have been removed from OUT_DIR"
    );
}
