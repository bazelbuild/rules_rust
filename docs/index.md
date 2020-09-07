# Rules rust

## Overview

This repository provides rules for building [Rust][rust] projects with [Bazel](https://bazel.build/).

[rust]: http://www.rust-lang.org/

<!-- TODO: Render generated docs on the github pages site again, https://bazelbuild.github.io/rules_rust/ -->

<a name="setup"></a>
## Setup

To use the Rust rules, add the following to your `WORKSPACE` file to add the external repositories for the Rust toolchain:

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "bazel_skylib",
    urls = [
        "https://github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz",
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz",
    ],
    sha256 = "1c531376ac7e5a180e0237938a2536de0c54d93f5c278634818e0efc952dd56c",
)

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")
bazel_skylib_workspace()

http_archive(
    name = "io_bazel_rules_rust",
    sha256 = "b6da34e057a31b8a85e343c732de4af92a762f804fc36b0baa6c001423a70ebc",
    strip_prefix = "rules_rust-55f77017a7f5b08e525ebeab6e11d8896a4499d2",
    urls = [
        # Master branch as of 2019-10-07
        "https://github.com/bazelbuild/rules_rust/archive/55f77017a7f5b08e525ebeab6e11d8896a4499d2.tar.gz",
    ],
)

load("@io_bazel_rules_rust//rust:repositories.bzl", "rust_repositories")
rust_repositories()

load("@io_bazel_rules_rust//:workspace.bzl", "bazel_version")
bazel_version(name = "bazel_version")
```
The rules are under active development, as such the lastest commit on the master branch should be used. `master` currently requires Bazel >= 0.26.0.

## Rules

* [rust](rust.md): standard rust rules for building and testing libraries and binaries.
* [rust_doc](rust_doc.md): rules for generating and testing rust documentation.
* [rust_proto](rust_proto.md): rules for generating [protobuf](https://developers.google.com/protocol-buffers).
  and [gRPC](https://grpc.io) stubs.
* [rust_bindgen](rust_bindgen.md): rules for generating C++ bindings.
* [rust_wasm_bindgen](rust_wasm_bindgen.md): rules for generating WebAssembly bindings, see the section about [WebAssembly](#webassembly).
* [cargo_build_script](cargo_build_script.md): a rule to run [`build.rs` script](https://doc.rust-lang.org/cargo/reference/build-scripts.html) from Bazel.

You can also browse the [full API in one page](flatten.md).

## Specifying Rust version

To build with a particular version of the Rust compiler, pass that version to `rust_repositories`:

```python
rust_repositories(version = "1.42.0", edition="2018")
```

As well as an exact version, `version` can be set to `"nightly"` or `"beta"`. If set to these values, `iso_date` must also be set:

```python
rust_repositories(version = "nightly", iso_date = "2020-04-19", edition="2018")
```

Similarly, `rustfmt_version` may also be configured:

```python
rust_repositories(rustfmt_version = "1.4.8")
```

## External Dependencies

Currently the most common approach to managing external dependencies is using
[cargo-raze](https://github.com/google/cargo-raze) to generate `BUILD` files for Cargo crates.

## WebAssembly

To build a `rust_binary` for wasm32-unknown-unknown add the `--platforms=//rust/platform:wasm` flag.

    bazel build @examples//hello_world_wasm --platforms=//rust/platform:wasm

`rust_wasm_bindgen` will automatically transition to the wasm platform and can be used when
building wasm code for the host target.
