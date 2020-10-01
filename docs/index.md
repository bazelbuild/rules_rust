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
    name = "io_bazel_rules_rust",
    sha256 = "618cba29165b7a893960de7bc48510b0fb182b21a4286e1d3dbacfef89ace906",
    strip_prefix = "rules_rust-5998baf9016eca24fafbad60e15f4125dd1c5f46",
    urls = [
        # Master branch as of 2020-09-24
        "https://github.com/bazelbuild/rules_rust/archive/5998baf9016eca24fafbad60e15f4125dd1c5f46.tar.gz",
    ],
)

load("@io_bazel_rules_rust//rust:repositories.bzl", "rust_repositories")

rust_repositories()

load("@io_bazel_rules_rust//:workspace.bzl", "rust_workspace")

rust_workspace()
```

The rules are under active development, as such the lastest commit on the master branch should be used. `master` currently requires Bazel >= 0.26.0.

## Rules

- [rust](rust.md): standard rust rules for building and testing libraries and binaries.
- [rust_doc](rust_doc.md): rules for generating and testing rust documentation.
- [rust_proto](rust_proto.md): rules for generating [protobuf](https://developers.google.com/protocol-buffers).
  and [gRPC](https://grpc.io) stubs.
- [rust_bindgen](rust_bindgen.md): rules for generating C++ bindings.
- [rust_wasm_bindgen](rust_wasm_bindgen.md): rules for generating WebAssembly bindings, see the section about [WebAssembly](#webassembly).
- [cargo_build_script](cargo_build_script.md): a rule to run [`build.rs` script](https://doc.rust-lang.org/cargo/reference/build-scripts.html) from Bazel.

You can also browse the [full API in one page](flatten.md).

## Specifying Rust version

To build with a particular version of the Rust compiler, pass that version to [`rust_repositories`](flatten.md#rust_repositories):

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

To build a `rust_binary` for wasm32-unknown-unknown add the `--platforms=@io_bazel_rules_rust//rust/platform:wasm` flag.

```command
bazel build @examples//hello_world_wasm --platforms=@io_bazel_rules_rust//rust/platform:wasm
```

`rust_wasm_bindgen` will automatically transition to the wasm platform and can be used when
building wasm code for the host target.
