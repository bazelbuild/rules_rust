use std::env::var;
use std::path::PathBuf;

fn main() {
    // Mirrors sys-crates like libssh2-sys consuming libz-sys: the producer's
    // build script advertised `$OUT_DIR/include` via `cargo:include=`, which
    // must arrive here as a resolvable path. A `${out_dir}` substitution
    // token would be left unresolved because only `${pwd}` is substituted in
    // dep env files, and the consumer's own OUT_DIR is a different directory.
    let include = var("DEP_Z_INCLUDE").expect("DEP_Z_INCLUDE should be set");
    assert!(
        !include.contains("${out_dir}"),
        "DEP_Z_INCLUDE contains an unresolved ${{out_dir}} token: {}",
        include
    );
    let header = PathBuf::from(&include).join("header.h");
    assert!(
        header.is_file(),
        "DEP_Z_INCLUDE does not point at the producer's OUT_DIR: {}",
        header.display()
    );
}
