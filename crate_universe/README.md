# Crate Universe

Crate Universe is akin to a modified version of cargo-raze that can be run as
part of a Bazel build. Instead of generating BUILD files in advance with
cargo-raze, the BUILD files can be created automatically at build time. It can
expose crates gathered from Cargo.toml files like cargo-raze does, and also
supports declaring crates directly in BUILD files, for cases where compatibility
with Cargo is not required.

**Note**: `crate_universe` is experimental, and may have breaking API changes at any time. These instructions may also change without notice.

More information can be found in the [rules_rust documentation](https://bazelbuild.github.io/rules_rust/crate_universe.html).
