//! A `links` crate's build script that publishes paths under its own
//! `OUT_DIR` to dependents via `cargo::metadata`, the way `-sys` crates
//! export `DEP_<LINKS>_INCLUDE` / `DEP_<LINKS>_LIB_DIR`.

use std::env;
use std::fs;
use std::path::PathBuf;

fn main() {
    let out = PathBuf::from(env::var("OUT_DIR").unwrap());

    let include = out.join("include");
    fs::create_dir_all(&include).unwrap();
    fs::write(include.join("producer.txt"), "producer").unwrap();

    let lib = out.join("lib");
    fs::create_dir_all(&lib).unwrap();
    build_script_native_libs::empty_static_lib(&lib, "transitive_producer");

    println!("cargo::metadata=include={}", include.display());
    println!("cargo::metadata=lib_dir={}", lib.display());
}
