# Patches

All patches pair with the versions of the referenced repositories defined in `@rules_rust//bindgen:repositories.bzl`.

## [llvm-project.cxx17](./llvm-project.cxx17.patch)

The llvm-project requires a compiler that builds with at least C++14 but there's no configuration
for this on the targets defined in the repo. This patch plumbs through flags for setting the C++
version on targets to avoid any need for bazel configuration flags. If this patch causes issues
for users with their current toolchain or toolchain definitions then simply defining the `llvm-raw`
repository before loading `rust_bindgen_dependencies` should avoid this.

## [llvm-project.incompatible_disallow_empty_glob](./llvm-project.incompatible_disallow_empty_glob.patch)

Uses of `glob` are updated to have `allow_empty = True` added so the llvm-project repo is compatible
with consumers building with [--incompatible_disallow_empty_glob](https://bazel.build/reference/command-line-reference#flag--incompatible_disallow_empty_glob).

Most of this patch is generated using the following regex and replace patterns. There are a handful
of additional modifications for more extravagant globs.

| regex | replace |
| --- | --- |
| `glob\(([\[\w\d_\-\*\/\.\],=\n\s"]+)\) \+` | `glob($1, allow_empty = True) +` |
| `glob\(([\[\w\d_\-\*\/\.\],=\n\s"]+)\),` | `glob($1, allow_empty = True),` |
| `(,[\s\n]+), ` | `$1` |
