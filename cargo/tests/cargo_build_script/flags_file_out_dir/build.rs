//! Emit `OUT_DIR` paths through the directives that land in the build
//! script's `.flags` file (`cargo:rustc-flags` and unscoped
//! `cargo:rustc-link-arg`), as opposed to `.linksearchpaths` / `.linkflags`.
//!
//! Both artifacts are empty but valid, so the only way the consumer fails to
//! link is if the path written into the flags file does not resolve in the
//! consuming `Rustc` action's sandbox.

use std::env;
use std::path::PathBuf;

fn main() {
    let out = PathBuf::from(env::var("OUT_DIR").unwrap());

    // Found through `-L<OUT_DIR>` from `cargo:rustc-flags`.
    build_script_native_libs::empty_static_lib(&out, "flags_file_search");
    println!("cargo:rustc-flags=-L{}", out.display());
    println!("cargo:rustc-link-lib=static=flags_file_search");

    // Passed to the linker by absolute path from `cargo:rustc-link-arg`.
    let object = build_script_native_libs::empty_object(&out, "flags_file_direct");
    println!("cargo:rustc-link-arg={}", object.display());
}
