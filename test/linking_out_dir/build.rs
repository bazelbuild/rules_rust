use std::env;
use std::path::PathBuf;

fn main() {
    let out_dir = PathBuf::from(env::var_os("OUT_DIR").unwrap());

    let src = env::var_os("ARCHIVE_PATH").unwrap();

    let dst = out_dir.join("libfoo.a");

    std::fs::copy(&src, &dst).unwrap();

    println!("cargo:rustc-link-lib=foo");
    println!("cargo:rustc-link-search=native={}", out_dir.display());
}
