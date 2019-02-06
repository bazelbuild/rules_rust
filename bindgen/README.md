# Rust Bindgen Rules

<div class="toc">
  <h2>Rules</h2>
  <ul>
    <li><a href="docs/index.md#rust_bindgen_toolchain">rust_bindgen_toolchain</a></li>
    <li>rust_bindgen</li>
    <li>rust_bindgen_library</li>
  </ul>
</div>

## Overview

These rules are for using [Bindgen][bindgen] to generate [Rust][rust] bindings to C (and some C++) libraries.

[rust]: http://www.rust-lang.org/
[bindgen]: https://github.com/rust-lang/rust-bindgen

See the [bindgen example](../examples/ffi/rust_calling_c/simple/BUILD#L9) for a more complete example of use.

### Setup

To use the Rust bindgen rules, add the following to your `WORKSPACE` file to add the
external repositories for the Rust bindgen toolchain (in addition to the [rust rules setup](..)):

```python
load("@io_bazel_rules_rust//bindgen:repositories.bzl", "rust_bindgen_repositories")

rust_bindgen_repositories()
```
This makes the default toolchain defined in [`@io_bazel_rules_rust`](./BUILD) available.

[raze]: https://github.com/google/cargo-raze

It will load crate dependencies of bindgen that are generated using
[cargo raze][raze] inside the rules_rust
repository. However, using those dependencies might conflict with other uses
of [cargo raze][raze]. If you need to change
those dependencies, please see the [dedicated section below](#custom-deps).

For additional information, see the [Bazel toolchains documentation](https://docs.bazel.build/versions/master/toolchains.html).

## <a name="custom-deps">Customizing dependencies

These rules depends on the [`bindgen`](https://crates.io/crates/bindgen) binary crate, and it 
in turn depends on both a clang binary and the clang library. To obtain these dependencies,
`rust_bindgen_repositories` imports bindgen and its dependencies using BUILD files generated with
[`cargo raze`][raze], along with a tarball of clang.

If you want to change the bindgen used, or use [`cargo raze`][raze] in a more
complex scenario (with more dependencies), you must redefine those
dependencies.

To do this, once you've imported the needed dependencies (see our
[Cargo.toml](./raze/Cargo.toml) file to see the default dependencies), you
need to create your own toolchain. To do so you can create a BUILD
file with your [`rust_bindgen_toolchain`](../docs/index.md#rust_bindgen_toolchain) definition, for example:

```python
load("@io_bazel_rules_rust//bindgen:bindgen.bzl", "rust_bindgen_toolchain")

rust_bindgen_toolchain(
    name = "bindgen-toolchain-impl",
    bindgen = "//my/raze:cargo_bin_bindgen",
    clang = "//my/clang:clang",
    libclang = "//my/clang:libclang.so",
    libstdcxx = "//my/cpp:libstdc++",
)

toolchain(
    name = "bindgen-toolchain",
    toolchain = "bindgen-toolchain-impl",
    toolchain_type = "@io_bazel_rules_rust//bindgen:bindgen_toolchain",
)
```

Now that you have your own toolchain, you need to register it by
inserting the following statement in your `WORKSPACE` file:

```python
register_toolchains("//my/toolchains:bindgen-toolchain")
```
