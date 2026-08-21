# rules_rust_cbindgen with a custom toolchain

This example uses [crate_universe](https://bazelbuild.github.io/rules_rust/crate_universe_bzlmod.html) to build
the [cbindgen](https://crates.io/crates/cbindgen) binary and register it as a `rust_cbindgen_toolchain` instead
of using the default toolchain provided by `rules_rust_cbindgen`.
