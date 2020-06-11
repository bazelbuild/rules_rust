# Rust Rules

* Postsubmit [![Build status](https://badge.buildkite.com/76523cc666caab9ca91c2a08d9ac8f84af28cb25a92f387293.svg?branch=master)](https://buildkite.com/bazel/rustlang-rules-rust-postsubmit?branch=master)
* Postsubmit + Current Bazel Incompatible Flags [![Build status](https://badge.buildkite.com/64e1f18bbd4cb612f8efd44f755f8dc493ffd69b7140d973a9.svg?branch=master)](https://buildkite.com/bazel/rules-rust-plus-bazelisk-migrate)

## Overview

This repository provides rules for building [Rust][rust] projects with [Bazel](https://bazel.build/).

[rust]: http://www.rust-lang.org/

<!-- TODO: Render generated docs on the github pages site again, https://bazelbuild.github.io/rules_rust/ -->

### Basics
<div class="toc">
  <ul>
    <li><a href="docs/index.md#rust_library">rust_library</a></li>
    <li><a href="docs/index.md#rust_binary">rust_binary</a></li>
    <li><a href="docs/index.md#rust_test">rust_test</a></li>
    <!-- TODO: <li><a href="docs/index.md#rust_benchmark">rust_benchmark</a></li> -->
    <li><a href="docs/index.md#rust_doc">rust_doc</a></li>
    <li><a href="docs/index.md#rust_doc_test">rust_doc_test</a></li>
  </ul>
</div>

#### WebAssembly

To build a `rust_binary` for wasm32-unknown-unknown add the `--platforms=//rust/platform:wasm` flag.

    bazel build @examples//hello_world_wasm --platforms=//rust/platform:wasm

`rust_wasm_bindgen` will automatically transition to the wasm platform and can be used when
building wasm code for the host target.

### Protobuf
<div class="toc">
  <ul>
    <li><a href="proto/README.md#rust_proto_library">rust_proto_library</a></li>
    <li><a href="proto/README.md#rust_grpc_library">rust_grpc_library</a></li>
  </ul>
</div>

with an overview [here](proto/README.md).

<a name="setup"></a>
## Setup

To use the Rust rules, add the following to your `WORKSPACE` file to add the external repositories for the Rust toolchain:

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "io_bazel_rules_rust",
    sha256 = "b6da34e057a31b8a85e343c732de4af92a762f804fc36b0baa6c001423a70ebc",
    strip_prefix = "rules_rust-55f77017a7f5b08e525ebeab6e11d8896a4499d2",
    urls = [
        # Master branch as of 2019-10-07
        "https://github.com/bazelbuild/rules_rust/archive/55f77017a7f5b08e525ebeab6e11d8896a4499d2.tar.gz",
    ],
)

http_archive(
    name = "bazel_skylib",
    sha256 = "9a737999532daca978a158f94e77e9af6a6a169709c0cee274f0a4c3359519bd",
    strip_prefix = "bazel-skylib-1.0.0",
    url = "https://github.com/bazelbuild/bazel-skylib/archive/1.0.0.tar.gz",
)

load("@io_bazel_rules_rust//rust:repositories.bzl", "rust_repositories")
rust_repositories()

load("@io_bazel_rules_rust//:workspace.bzl", "bazel_version")
bazel_version(name = "bazel_version")
```
The rules are under active development, as such the lastest commit on the master branch should be used. `master` currently requires Bazel >= 0.26.0.

### Specifying Rust version

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

### External Dependencies

Currently the most common approach to managing external dependencies is using
[cargo-raze](https://github.com/google/cargo-raze) to generate `BUILD` files for Cargo crates.

<a name="roadmap"></a>
## Roadmap

* Improve expressiveness of features and support for [Cargo's feature groups](http://doc.crates.io/manifest.html#the-[features]-section).
* Add `cargo_crate` workspace rule for pulling crates from [Cargo](https://crates.io/).
