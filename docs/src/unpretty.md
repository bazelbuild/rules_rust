# Unpretty

The unpretty rules expose `rustc`'s [`-Zunpretty=<mode>`][unpretty] flag as a
Bazel action. Given a Rust target, they emit an alternate textual representation
of it — the fully macro-expanded source, the HIR, the MIR CFG, etc. — useful for
inspecting what the compiler sees after macro expansion, lowering, or
optimization.

Because `-Zunpretty` is a nightly-only compiler flag, these rules require a
nightly `rust_toolchain` to be registered.

[unpretty]: https://doc.rust-lang.org/nightly/unstable-book/compiler-flags/unpretty.html

## Rules

- [rust_unpretty](./rust_unpretty.md) — Rule form. Explicitly declare an unpretty
  target that emits the chosen representation for a specific crate.
- [rust_unpretty_aspect](./rust_unpretty_aspect.md) — Aspect form. Attach at the
  command line (`--aspects=@rules_rust//rust:defs.bzl%rust_unpretty_aspect
  --output_groups=+rust_unpretty`) to emit the representation for every Rust
  target in the build without adding rule instances.
