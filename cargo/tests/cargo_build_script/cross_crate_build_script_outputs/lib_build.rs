use std::env;
use std::path::PathBuf;

fn main() {
    let out = PathBuf::from(env::var("OUT_DIR").unwrap());

    // Write an empty static archive into OUT_DIR. The downstream
    // `bin_link` target links against it via `-l`, forcing the linker to
    // locate the file through the transitive link search path. If the
    // path resolves incorrectly, linking fails with "library not found".
    let archive = env::var("OUT_DIR_TEST_ARCHIVE").unwrap_or_else(|_| "cross_crate_lib".to_owned());
    build_script_native_libs::empty_static_lib(&out, &archive);

    println!("cargo:rustc-link-search={}", out.display());
}
