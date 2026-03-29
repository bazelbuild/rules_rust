# Sys Crate Examples

This repository demonstrates how to use `rules_rust` to build projects that depend on `-sys` crates.

`-sys` crates provide low-level bindings to native libraries, allowing Rust code to interact with C libraries through the Foreign Function Interface (FFI). For more details, see the [Rust FFI documentation](https://doc.rust-lang.org/nomicon/ffi.html) or the [Rust-bindgen project](https://github.com/rust-lang/rust-bindgen).

For a comprehensive guide on handling `-sys` crates in Bazel, including when to let the build script run vs. when to replace it with native Bazel targets, see the [Handling -sys Crates](https://bazelbuild.github.io/rules_rust/crate_universe_bzlmod.html#handling-sys-crates) section of the crate_universe docs.

## Examples

### Basic: Letting the build script run

The [`basic/`](basic/) example uses `bzip2-sys` with its build script enabled (`gen_build_script = True`). The build script compiles the bundled bzip2 C source using [`cc-rs`](https://github.com/rust-lang/cc-rs), which works out of the box because `rules_rust` provides a C++ toolchain and sets `CC`, `CXX`, etc.

This is the right approach when the build script is simple and works without intervention.

### Complex: Replacing the build script with a `cc_library`

The [`complex/`](complex/) example uses `libgit2-sys` and `libz-sys` with their build scripts disabled (`gen_build_script = False`). Instead, pre-built Bazel `cc_library` targets (`@libgit2`, `@zlib`) are added to the crate's `deps` via annotations:

```python
annotations = {
    "libgit2-sys": [crate.annotation(
        gen_build_script = False,
        deps = ["@libgit2"],
    )],
    "libz-sys": [crate.annotation(
        gen_build_script = False,
        deps = ["@zlib"],
    )],
}
```

This is the right approach when you already have the native library as a Bazel target and the crate's `lib.rs` only contains `extern "C"` declarations.
