# Sys Crate Examples

This repository demonstrates how to use `rules_rust` to build projects that depend on `-sys` crates.

`-sys` crates provide low-level bindings to native libraries, allowing Rust code to interact with C libraries through the Foreign Function Interface (FFI). For more details, see the [Rust FFI documentation](https://doc.rust-lang.org/nomicon/ffi.html) or the [Rust-bindgen project](https://github.com/rust-lang/rust-bindgen).

This workspace includes:

1. **Basic Example**: Using `bzip2-sys` to interface with the `bzip2` compression library.
2. **Complex Example**: Using `libgit2-sys` to interact with the `libgit2` library.
