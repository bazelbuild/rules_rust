# Rustdoc

[Rustdoc][rustdoc] is Rust's built-in documentation generator. It reads the `///`
and `//!` doc comments in your source and produces browsable HTML — the same
tooling that generates the [standard library docs][std_docs] and every crate on
[docs.rs][docs_rs].

[rustdoc]: https://doc.rust-lang.org/rustdoc/
[std_docs]: https://doc.rust-lang.org/std/
[docs_rs]: https://docs.rs/

## Rules

- [rust_doc](./rust_doc.md) — Build HTML documentation for a `rust_library`,
  `rust_binary`, or `rust_proc_macro` target. Output is a directory tree suitable
  for hosting on a static site.
- [rust_doc_test](./rust_doc_test.md) — Compile and run the code samples embedded
  in a crate's doc comments as tests, matching Cargo's `cargo test --doc` behavior.
