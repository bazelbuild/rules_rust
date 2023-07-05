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

# To find additional information on this release or newer ones visit:
# https://github.com/bazelbuild/rules_rust/releases
http_archive(
    name = "rules_rust",
    sha256 = "37f40490169dc94013c7566c75c861977a2c02ce5505b7e975da0f7d5f2231c8",
    urls = ["https://github.com/bazelbuild/rules_rust/releases/download/0.16.1/rules_rust-v0.16.1.tar.gz"],
)

load("@rules_rust//rust:repositories.bzl", "rules_rust_dependencies", "rust_register_toolchains")

rules_rust_dependencies()

rust_register_toolchains()
```

The rules are released, and releases can be found on [the GitHub Releases page](https://github.com/bazelbuild/rules_rust/releases). We recommend using the latest release from that page.

## Rules

- [defs](defs.md): standard rust rules for building and testing libraries and binaries.
- [rust_doc](rust_doc.md): rules for generating and testing rust documentation.
- [rust_clippy](rust_clippy.md): rules for running [clippy](https://github.com/rust-lang/rust-clippy#readme).
- [rust_fmt](rust_fmt.md): rules for running [rustfmt](https://github.com/rust-lang/rustfmt#readme).
- [rust_proto](rust_proto.md): rules for generating [protobuf](https://developers.google.com/protocol-buffers) and [gRPC](https://grpc.io) stubs.
- [rust_bindgen](rust_bindgen.md): rules for generating C++ bindings.
- [rust_wasm_bindgen](rust_wasm_bindgen.md): rules for generating [WebAssembly](https://www.rust-lang.org/what/wasm) bindings.
- [cargo](cargo.md): Rules dedicated to Cargo compatibility. ie: [`build.rs` scripts](https://doc.rust-lang.org/cargo/reference/build-scripts.html).
- [crate_universe](crate_universe.md): Rules for generating Bazel targets for external crate dependencies.

You can also browse the [full API in one page](flatten.md).

### Experimental rules

- [rust_analyzer](rust_analyzer.md): rules for generating `rust-project.json` files for [rust-analyzer](https://rust-analyzer.github.io/)

## Specifying Rust version

To build with a particular version of the Rust compiler, pass that version to [`rust_register_toolchains`](flatten.md#rust_register_toolchains):

```python
rust_register_toolchains(
    edition = "2021",
    versions = [
        "1.66.1"
    ],
)
```

As well as an exact version, `versions` can accept `nightly/{iso_date}` and `beta/{iso_date}` strings for toolchains from different release channels.

```python
rust_register_toolchains(
    edition = "2021"
    versions = [
        "nightly/2022-12-15",
    ],
)
```

By default, a `stable` and `nightly` toolchain will be registered if no versions are passed to `rust_register_toolchains`. However,
if only 1 version is passed and it is from the `nightly` or `beta` release channels (i.e. __not__ `stable`), then a build setting must
also be set in the project's `.bazelrc` file.

```text
build --@rules_rust//rust/toolchain/channel=nightly
```

Failure to do so will result in rules attempting to match a `stable` toolchain when one was not registered.

## External Dependencies

[crate_universe](crate_universe.md) is a tool built into `rules_rust` that can be used to fetch dependencies. Additionally, [cargo-raze](https://github.com/google/cargo-raze) is an older third-party which can also fetch dependencies.

## Supported bazel versions

The oldest version of Bazel the `main` branch is tested against is `6.0.0`. Previous versions may still be functional in certain environments, but this is the minimum version we strive to fully support.

We test these rules against the latest rolling releases of Bazel, and aim for compatibility with them, but prioritise stable releases over rolling releases where necessary.

## Supported platforms

We aim to support Linux, macOS, and Windows.

Windows support is less complete than the other two platforms, but most things work, and we welcome contributions to help improve its support.

Windows support for some features requires `--enable_runfiles` to be passed to Bazel, we recommend putting it in your bazelrc. See [Using Bazel on Windows](https://bazel.build/configure/windows) for more Windows-specific recommendations.
