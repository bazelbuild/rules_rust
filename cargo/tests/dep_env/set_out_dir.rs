use std::env::var;
use std::fs;
use std::path::PathBuf;

fn main() {
    // Mirrors sys-crates like libz-sys: generate a header into OUT_DIR and
    // advertise its location to dependents via a `cargo:include=` metadata
    // key, which downstream build scripts receive as `DEP_Z_INCLUDE`.
    let out_dir = PathBuf::from(var("OUT_DIR").expect("OUT_DIR should be set"));
    let include_dir = out_dir.join("include");
    fs::create_dir_all(&include_dir).expect("Failed to create include dir");
    fs::write(include_dir.join("header.h"), "// generated\n").expect("Failed to write header");
    println!("cargo:include={}", include_dir.display());
}
