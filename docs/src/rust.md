# Rust rules

The core Rust rules for building and testing libraries, binaries, and procedural
macros. Each rule is documented on its own page; this page is an overview of what
each rule does and when to use it.

All rules are loadable from `@rules_rust//rust:defs.bzl` or from their individual
`.bzl` file (e.g. `@rules_rust//rust:rust_binary.bzl`). Loading from the
individual file is preferred for new code.

## Core rules

The rules below are the primary entry points for compiling Rust code. They map
directly to the crate types Cargo produces.

- [rust_binary](./rust_binary.md) — Build a Rust executable (`--crate-type=bin`).
- [rust_library](./rust_library.md) — Build an `rlib` (`--crate-type=lib`) that
  other Rust targets can depend on.
- [rust_static_library](./rust_static_library.md) — Build a `staticlib`
  (`--crate-type=staticlib`) for linking Rust code into a C/C++ binary.
- [rust_cdylib_library](./rust_cdylib_library.md) — Build a `cdylib`
  (`--crate-type=cdylib`) for use as a shared library from C/C++ or other
  languages.
- [rust_dylib_library](./rust_dylib_library.md) — Build a `dylib`
  (`--crate-type=dylib`) for use as a shared library with the unstable Rust ABI.
- [rust_shared_library](./rust_shared_library.md) — Convenience alias over
  `rust_cdylib_library`.
- [rust_proc_macro](./rust_proc_macro.md) — Build a procedural macro crate
  (`--crate-type=proc-macro`) that other Rust targets can consume as a compile-time
  plugin.
- [rust_test](./rust_test.md) — Compile and run a Rust test binary. Can wrap a
  `rust_library`/`rust_binary` (via `crate = ...`) to run its inline `#[test]`s,
  or compile a standalone test binary from its own `srcs`.

## Additional rules

Non-core rules that ship in the same ruleset:

- [rust_library_group](./rust_library_group.md) — Group several `rust_library`
  targets so they can be depended on as a single unit without generating an
  intermediate `rlib`.
- [rust_lint_config](./rust_lint_config.md) — Declare a reusable set of `rustc`,
  `clippy`, and `rustdoc` lint levels that can be attached to other rules via
  their `lint_config` attribute.
- [rust_test_suite](./rust_test_suite.md) — Convenience macro that expands into
  one `rust_test` per source file, sharing a common set of dependencies. Useful
  for `tests/**.rs` layouts that mirror Cargo's integration-test directory.

## Related pages

Rules that layer on top of the core rules live on their own pages:

- [rustdoc](./rustdoc.md) — Generate and test Rust documentation.
- [clippy](./clippy.md) — Run [Clippy](https://github.com/rust-lang/rust-clippy)
  over Rust targets.
- [rustfmt](./rustfmt.md) — Run [rustfmt](https://github.com/rust-lang/rustfmt)
  over Rust targets.
- [unpretty](./unpretty.md) — Emit `rustc -Zunpretty=...` output for a crate.
- [cargo](./cargo.md) — `cargo_build_script` and related Cargo-compatibility rules.
- [rust_analyzer](./rust_analyzer.md) — Generate a `rust-project.json` file for
  the [rust-analyzer](https://rust-analyzer.github.io) IDE server.
- [Rust Toolchains](./rust_toolchains.md) — Declare and register Rust toolchains.
