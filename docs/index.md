# [Rules rust](https://github.com/bazelbuild/rules_rust)

## Overview

This repository provides rules for building [Rust][rust] projects with [Bazel][bazel].

[bazel]: https://bazel.build/
[rust]: http://www.rust-lang.org/

<!-- TODO: Render generated docs on the github pages site again, https://bazelbuild.github.io/rules_rust/ -->

<a name="setup"></a>

## Setup

To use the Rust rules, add the following to your `WORKSPACE` file to add the external repositories for the Rust toolchain:

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "rules_rust",
    sha256 = "531bdd470728b61ce41cf7604dc4f9a115983e455d46ac1d0c1632f613ab9fc3",
    strip_prefix = "rules_rust-d8238877c0e552639d3e057aadd6bfcf37592408",
    urls = [
        # `main` branch as of 2021-08-23
        "https://github.com/bazelbuild/rules_rust/archive/d8238877c0e552639d3e057aadd6bfcf37592408.tar.gz",
    ],
)

load("@rules_rust//rust:repositories.bzl", "rules_rust_dependencies", "rust_register_toolchains")

rules_rust_dependencies()

rust_register_toolchains()
```

The rules are under active development, as such the lastest commit on the
`main` branch should be used. `main` is only tested against `4.0.0` as the
minimum supported version of Bazel. Though previous versions may still be
functional in certain environments.

## Rules

- [defs](defs.md): standard rust rules for building and testing libraries and binaries.
- [rust_doc](rust_doc.md): rules for generating and testing rust documentation.
- [rust_clippy](rust_clippy.md): rules for running [clippy](https://github.com/rust-lang/rust-clippy#readme).
- [rust_fmt](rust_fmt.md): rules for running [rustfmt](https://github.com/rust-lang/rustfmt#readme).
- [rust_proto](rust_proto.md): rules for generating [protobuf](https://developers.google.com/protocol-buffers).
  and [gRPC](https://grpc.io) stubs.
- [rust_bindgen](rust_bindgen.md): rules for generating C++ bindings.
- [rust_wasm_bindgen](rust_wasm_bindgen.md): rules for generating [WebAssembly](https://www.rust-lang.org/what/wasm) bindings.
- [cargo](cargo.md): Rules dedicated to Cargo compatibility. ie: [`build.rs` scripts](https://doc.rust-lang.org/cargo/reference/build-scripts.html).

You can also browse the [full API in one page](flatten.md).

### Experimental rules

- [crate_universe](crate_universe.md): A repository rule for fetching dependencies from a crate registry.
- [rust_analyzer](rust_analyzer.md): rules for generating `rust-project.json` files for [rust-analyzer](https://rust-analyzer.github.io/)

## Specifying Rust version

To build with a particular version of the Rust compiler, pass that version to [`rust_repositories`](flatten.md#rust_repositories):

```python
rust_repositories(version = "1.53.0", edition="2018")
```

As well as an exact version, `version` can be set to `"nightly"` or `"beta"`. If set to these values, `iso_date` must also be set:

```python
rust_repositories(version = "nightly", iso_date = "2021-06-16", edition="2018")
```

Similarly, `rustfmt_version` may also be configured:

```python
rust_repositories(rustfmt_version = "1.53.0")
```

## External Dependencies

Currently, the most common approach to managing external dependencies is using
[cargo-raze](https://github.com/google/cargo-raze) to generate `BUILD` files for Cargo crates.
