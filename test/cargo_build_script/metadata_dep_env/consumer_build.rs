fn main() {
    let modern = std::env::var("DEP_PRODUCER_MODERN_VERSION_1_10_0")
        .expect("DEP_PRODUCER_MODERN_VERSION_1_10_0 should be set by producer build script");
    assert_eq!(
        modern, "1",
        "unexpected DEP_PRODUCER_MODERN_VERSION_1_10_0 value"
    );

    let legacy = std::env::var("DEP_PRODUCER_LEGACY_VERSION_1_10_0")
        .expect("DEP_PRODUCER_LEGACY_VERSION_1_10_0 should be set by producer build script");
    assert_eq!(
        legacy, "2",
        "unexpected DEP_PRODUCER_LEGACY_VERSION_1_10_0 value"
    );

    // `DEP_PRODUCER_INCLUDE` points into the producer crate's `OUT_DIR`.
    // It must reach this dependent build script as a fully resolved, existing
    // path. Before the fix it arrived with the producer's `OUT_DIR` rewritten
    // to the literal, unresolved `${out_dir}` token (e.g.
    // `<execroot>/${out_dir}/include`), so the directory did not exist.
    let include = std::env::var("DEP_PRODUCER_INCLUDE")
        .expect("DEP_PRODUCER_INCLUDE should be set by producer build script");
    let resolved = !include.contains("${out_dir}")
        && std::path::Path::new(&include).join("marker.h").is_file();
    println!(
        "cargo:rustc-env=METADATA_INCLUDE_RESOLVED={}",
        if resolved { "1" } else { "0" }
    );

    println!("cargo:rustc-env=METADATA_MODERN_VALUE={modern}");
    println!("cargo:rustc-env=METADATA_LEGACY_VALUE={legacy}");
}
