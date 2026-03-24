"""# rules_rust_bindgen

These rules are for using [Bindgen][bindgen] to generate [Rust][rust] bindings to C (and some C++) libraries.

[rust]: http://www.rust-lang.org/
[bindgen]: https://github.com/rust-lang/rust-bindgen

## Rules

- [rust_bindgen](#rust_bindgen)
- [rust_bindgen_library](#rust_bindgen_library)
- [rust_bindgen_toolchain](#rust_bindgen_toolchain)

## Setup

### Bzlmod

To use the Rust bindgen rules, add the following to your `MODULE.bazel` file:

```python
bazel_dep(name = "rules_rust_bindgen", version = "{SEE_RELEASE_NOTES}")
```

rules_rust_bindgen does not automatically register a bindgen toolchain.
You need to register either your own or the default toolchain by adding the following to your `MODULE.bazel` file:

```python
register_toolchains("@rules_rust_bindgen//:default_bindgen_toolchain")
```

The default toolchain builds libclang from source via the [llvm-project](https://registry.bazel.build/modules/llvm-project) bazel_dep.
[examples/bindgen_toolchain](https://github.com/bazelbuild/rules_rust/tree/main/examples/bindgen_toolchain) shows how to use a prebuilt libclang.

### Workspace

Or add the following if you're still using `WORKSPACE` to add the
external repositories for the Rust bindgen toolchain (in addition to the [rust rules setup](https://bazelbuild.github.io/rules_rust/#setup)):

```python
load("@rules_rust_bindgen//:repositories.bzl", "rust_bindgen_dependencies", "rust_bindgen_register_toolchains")

rust_bindgen_dependencies()

rust_bindgen_register_toolchains()

load("@rules_rust_bindgen//:transitive_repositories.bzl", "rust_bindgen_transitive_dependencies")

rust_bindgen_transitive_dependencies()
```

Bindgen aims to be as hermetic as possible so will end up building `libclang` from [llvm-project][llvm_proj] from
source. If this is found to be undesirable then no Bindgen related calls should be added to your WORKSPACE and instead
users should define their own repositories using something akin to [crate_universe][cra_uni] and define their own
toolchains following the instructions for [rust_bindgen_toolchain](#rust_bindgen_toolchain).

[llvm_proj]: https://github.com/llvm/llvm-project
[cra_uni]: https://bazelbuild.github.io/rules_rust/crate_universe_workspace.html

## Replacing `-sys` crate build scripts

Many `-sys` crates have build scripts that compile C code and/or run bindgen. To replace
these in Bazel, use `rust_bindgen` to generate bindings and `cargo_build_info` from
`@rules_rust//cargo:defs.bzl` to package them as a `BuildInfo` provider:

```python
load("@rules_rust//cargo:defs.bzl", "cargo_build_info")
load("@rules_rust_bindgen//:defs.bzl", "rust_bindgen")

rust_bindgen(
    name = "my_sys_bindings",
    header = "@my_native_lib//:include/my_lib.h",
    cc_lib = "@my_native_lib",
)

cargo_build_info(
    name = "my_sys_bs",
    out_dir_files = {"bindings.rs": ":my_sys_bindings"},
    cc_lib = "@my_native_lib",
    links = "my_lib",
)
```

Then use `override_target_build_script` in your crate annotation:

```python
crate.annotation(
    crate = "my-native-sys",
    override_target_build_script = "//path:my_sys_bs",
)
```

Alternatively, `rust_bindgen_library` produces a standalone `rust_library` from the generated
bindings. This requires more manual wiring -- you need to use `override_target_lib` and handle
`OUT_DIR` / `dep_env` yourself via `cargo_dep_env`:

```python
load("@rules_rust_bindgen//:defs.bzl", "rust_bindgen_library")

rust_bindgen_library(
    name = "my_sys_bindings",
    cc_lib = "@my_native_lib",
    header = "@my_native_lib//:include/my_lib.h",
)
```
"""

load(
    "//private:bindgen.bzl",
    _BindgenInfo = "BindgenInfo",
    _rust_bindgen = "rust_bindgen",
    _rust_bindgen_library = "rust_bindgen_library",
    _rust_bindgen_toolchain = "rust_bindgen_toolchain",
)

BindgenInfo = _BindgenInfo
rust_bindgen = _rust_bindgen
rust_bindgen_library = _rust_bindgen_library
rust_bindgen_toolchain = _rust_bindgen_toolchain
