use std::fs;
use std::path::PathBuf;

fn main() {
    println!("cargo::metadata=modern_version_1_10_0=1");
    // Legacy (pre-1.77-compatible) syntax where unknown cargo:KEY is treated as metadata.
    println!("cargo:legacy_version_1_10_0=2");

    // Expose an `OUT_DIR`-relative include directory through the
    // `links`/metadata convention, exactly as a `-sys` crate does with
    // `cargo:include=$OUT_DIR/include`. The dependent build script must
    // receive this through `DEP_PRODUCER_INCLUDE` as a fully resolved path
    // that actually exists — not a literal `${out_dir}` token.
    let out_dir = PathBuf::from(std::env::var("OUT_DIR").expect("OUT_DIR set by rules_rust"));
    let include = out_dir.join("include");
    fs::create_dir_all(&include).expect("create include dir");
    fs::write(include.join("marker.h"), "/* marker */\n").expect("write marker header");
    println!("cargo:include={}", include.display());
}
