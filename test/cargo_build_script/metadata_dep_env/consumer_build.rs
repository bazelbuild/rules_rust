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

    println!("cargo:rustc-env=METADATA_MODERN_VALUE={modern}");
    println!("cargo:rustc-env=METADATA_LEGACY_VALUE={legacy}");
}
