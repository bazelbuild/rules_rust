fn main() {
    println!("cargo:rustc-link-lib=static=first");
    println!("cargo:rustc-link-lib=static=second");
}
