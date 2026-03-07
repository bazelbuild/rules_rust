fn main() {
    println!("cargo::metadata=modern_version_1_10_0=1");
    // Legacy (pre-1.77-compatible) syntax where unknown cargo:KEY is treated as metadata.
    println!("cargo:legacy_version_1_10_0=2");
}
