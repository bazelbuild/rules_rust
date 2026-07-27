fn main() {
    println!("cargo::warning=this should be suppressed when emit_warnings=False");
    println!("cargo::rustc-env=FROM_BUILD_SCRIPT=ok");
}
