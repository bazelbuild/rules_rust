fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rustc-env=RANDOM_NUMBER=4");
}
