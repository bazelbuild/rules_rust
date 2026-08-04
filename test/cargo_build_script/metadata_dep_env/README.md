# metadata_dep_env test

This package contains end-to-end tests for metadata forwarding through `cargo_build_script`
for both syntax forms:
- modern syntax: `cargo::metadata=KEY=VALUE`
- legacy syntax: `cargo:KEY=VALUE`

## What it verifies

1. `producer_build_rs` emits both:
   - `cargo::metadata=modern_version_1_10_0=1`
   - `cargo:legacy_version_1_10_0=2`
2. `rules_rust` converts that to a dependent build-script env var:
   - `DEP_PRODUCER_MODERN_VERSION_1_10_0=1`
   - `DEP_PRODUCER_LEGACY_VERSION_1_10_0=1`
3. `consumer_build_rs` reads both and exports:
   - `cargo:rustc-env=METADATA_MODERN_VALUE=1`
   - `cargo:rustc-env=METADATA_LEGACY_VALUE=2`
4. Two `rust_test` targets assert each value independently:
   - `metadata_dep_env_modern_test`: `env!("METADATA_MODERN_VALUE") == "1"`
   - `metadata_dep_env_legacy_test`: `env!("METADATA_LEGACY_VALUE") == "2"`

## Why `producer_lib.rs` exists

`cargo_build_script` targets cannot directly depend on other `cargo_build_script` targets.
To model a realistic dependency edge, we attach `producer_build_rs` to a tiny Rust library (`producer_lib`),
and the consumer build script depends on that library via `link_deps`.
