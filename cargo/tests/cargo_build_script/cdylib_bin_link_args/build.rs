fn main() {
    // Emit a benign linker flag (an extra library search path) as the cdylib/bin
    // link arg. It exercises the real pipeline end to end -- the consumers below
    // link with it applied -- while being a no-op that doesn't break any linker.
    let out_dir = std::env::var("OUT_DIR").unwrap();
    let search = if std::env::var("CARGO_CFG_TARGET_ENV").as_deref() == Ok("msvc") {
        format!("/LIBPATH:{out_dir}")
    } else {
        format!("-L{out_dir}")
    };
    println!("cargo::rustc-link-arg-cdylib={search}");
    println!("cargo:rustc-cdylib-link-arg={search}");
    println!("cargo::rustc-link-arg-bins={search}");
    println!("cargo::rustc-link-arg-bin=my-bin={search}");
    println!("cargo::rustc-link-arg-bin=my_bin={search}");
    println!("cargo::rustc-link-arg-bin=unrelated=--this-must-never-reach-the-linker");
}
