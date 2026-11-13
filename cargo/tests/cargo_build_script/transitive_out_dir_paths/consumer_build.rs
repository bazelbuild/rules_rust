//! Forward a dependency's `OUT_DIR` paths (received as `DEP_*` variables) into
//! directives consumed by this crate's `Rustc` action. The producer's
//! `OUT_DIR` is an input of that action, so these paths must resolve to
//! wherever Bazel stages it, including the path-mapped location.

fn main() {
    let include = std::env::var("DEP_TRANSITIVE_PRODUCER_INCLUDE")
        .expect("DEP_TRANSITIVE_PRODUCER_INCLUDE should be set by the producer build script");
    let lib_dir = std::env::var("DEP_TRANSITIVE_PRODUCER_LIB_DIR")
        .expect("DEP_TRANSITIVE_PRODUCER_LIB_DIR should be set by the producer build script");

    println!("cargo:rustc-env=TRANSITIVE_PRODUCER_INCLUDE={include}");
    println!("cargo:rustc-link-search=native={lib_dir}");
    println!("cargo:rustc-link-lib=static=transitive_producer");
}
