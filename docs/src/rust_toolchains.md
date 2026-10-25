# Toolchains

A Rust build in Bazel selects its compiler, standard library, and companion tools
through a set of registered [Bazel toolchains][bazel_toolchains]. `rules_rust`
ships one toolchain type per companion tool so that Rust, `rust-analyzer`,
`rustfmt`, and `cargo` can be resolved independently.

[bazel_toolchains]: https://bazel.build/extending/toolchains

Most users register toolchains via the `rust` module extension (see
[Bzlmod](./rust_bzlmod.md)) rather than declaring these rules directly. The rules
below exist for users who need to define custom toolchains — for example, to point
at a locally built `rustc` or to add a target triple that the extension doesn't
cover.

## Toolchain rules

- [rust_toolchain](./rust_toolchain.md) — Declare a Rust compilation toolchain: the
  `rustc` binary, standard library, linker, and per-target compilation settings.
- [rustfmt_toolchain](./rustfmt_toolchain.md) — Declare a toolchain providing the
  `rustfmt` binary used by [rustfmt](./rustfmt.md) rules.
- [rust_analyzer_toolchain](./rust_analyzer_toolchain.md) — Declare a toolchain
  providing the `rust-analyzer` binary and proc-macro server used by the
  [rust_analyzer](./rust_analyzer.md) integration.
- [cargo_toolchain](./cargo_toolchain.md) — Declare a toolchain providing the
  `cargo` binary used by rules which run Cargo, such as
  [cargo_build_script](./cargo_build_script.md) and
  [crates_vendor](./crates_vendor.md). The `rust` module extension declares one
  in the repository of every `rust_toolchain` it registers and registers the two
  together, so Cargo always comes from the same release as `rustc`; the
  toolchain carries the same `version`, `iso_date` and `channel` identifiers and
  `cargo_build_script` fails when they differ. The `cargo` attribute of
  `rust_toolchain` is deprecated in its favor and is only consulted when no
  `cargo_toolchain` is registered.

## Data rules

- [rust_stdlib_filegroup](./rust_stdlib_filegroup.md) — Group the files of a Rust
  standard library archive into a target that can be attached to a
  `rust_toolchain` via the `rust_std` attribute.
