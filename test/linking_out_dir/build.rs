use std::env;
use std::path::PathBuf;

const ARCHIVE_NAME: &'static str = "test_linking_out_dir_foo";

fn main() {
    let out_dir = PathBuf::from(env::var_os("OUT_DIR").unwrap());

    let src = env::var_os("ARCHIVE_PATH").unwrap();

    let dst = out_dir.join(format!("lib{ARCHIVE_NAME}.a"));

    std::fs::copy(&src, &dst).unwrap();

    println!("cargo:rustc-link-lib={ARCHIVE_NAME}");
    println!("cargo:rustc-link-search=native={}", out_dir.display());
}
