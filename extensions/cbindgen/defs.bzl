"""# rules_rust_cbindgen

These rules are for using [cbindgen][cbindgen] to generate C (and C++) headers for [Rust][rust] libraries.

[rust]: http://www.rust-lang.org/
[cbindgen]: https://github.com/mozilla/cbindgen

## Rules

- [rust_cbindgen_library](#rust_cbindgen_library)
- [rust_cbindgen_toolchain](#rust_cbindgen_toolchain)

## Setup

To use the Rust cbindgen rules, add the following to your `MODULE.bazel` file:

```python
bazel_dep(name = "rules_rust_cbindgen", version = "{SEE_RELEASE_NOTES}")
```

rules_rust_cbindgen does not automatically register a cbindgen toolchain.
You need to register either your own or the default toolchain by adding the following to your `MODULE.bazel` file:

```python
register_toolchains("@rules_rust_cbindgen//:default_cbindgen_toolchain")
```

The default toolchain builds the [cbindgen](https://crates.io/crates/cbindgen) binary from source. If this
is found to be undesirable, users should define their own repositories using something akin to
[crate_universe][cra_uni] and define their own toolchains following the instructions for
[rust_cbindgen_toolchain](#rust_cbindgen_toolchain).

[cra_uni]: https://bazelbuild.github.io/rules_rust/crate_universe_bzlmod.html

---
---
"""

load(
    "//private:cbindgen.bzl",
    _rust_cbindgen_library = "rust_cbindgen_library",
    _rust_cbindgen_toolchain = "rust_cbindgen_toolchain",
)

rust_cbindgen_library = _rust_cbindgen_library
rust_cbindgen_toolchain = _rust_cbindgen_toolchain
