fn main() {
    let library = if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows") {
        "kernel32"
    } else {
        "c"
    };
    println!("cargo:rustc-link-lib=dylib={library}");
}
