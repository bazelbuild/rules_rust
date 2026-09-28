fn main() {
    let out_dir = std::path::PathBuf::from(std::env::var_os("OUT_DIR").expect("missing OUT_DIR"));
    std::fs::write(
        out_dir.join("generated.rs"),
        "const GENERATED_VALUE: &str = \"from_build_script\";\n",
    )
    .expect("could not write the generated fixture");
    println!("cargo:rustc-cfg=build_script_cfg");
    println!("cargo:rustc-env=BUILD_SCRIPT_VALUE=from_build_script");

    let library = if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows") {
        "kernel32"
    } else {
        "c"
    };
    println!("cargo:rustc-link-lib=dylib={library}");
}
