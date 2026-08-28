# Cargo

Rules for interoperating with tooling from the [Cargo][cargo] ecosystem — most
importantly, Cargo [`build.rs` scripts][build_scripts]. These rules let a Bazel
build consume the same crate-side conventions that Cargo uses (build scripts,
generated env vars, `[lints]` tables) without switching build systems.

[cargo]: https://doc.rust-lang.org/cargo/
[build_scripts]: https://doc.rust-lang.org/cargo/reference/build-scripts.html

## Rules

- [cargo_build_script](./cargo_build_script.md) — Compile and run a crate's
  `build.rs` at build time, then feed the emitted `cargo:*` directives (env vars,
  link args, rerun-if-changed inputs) into consumers of the crate.
- [cargo_env](./cargo_env.md) — Helper that returns Cargo's standard
  `CARGO_*` env-var dict, used by rules that need to reproduce Cargo's
  compilation environment.
- [extract_cargo_lints](./extract_cargo_lints.md) — Read the `[lints]` table
  from a `Cargo.toml` and produce a [`rust_lint_config`](./rust_lint_config.md)
  target from it, so Cargo-defined lints apply to Bazel-built crates.
