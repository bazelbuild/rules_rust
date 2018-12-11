[![Build status](https://badge.buildkite.com/76523cc666caab9ca91c2a08d9ac8f84af28cb25a92f387293.svg?branch=master)](https://buildkite.com/bazel/rustlang-rules-rust-postsubmit?branch=master)

# Rust Rules

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

The rules are under active development, as such the lastest commit on the master branch should be used.

```python
http_archive(
    name = "io_bazel_rules_rust",
    sha256 = "c82118824b2448b77146f1dae97b6eaa717babedad0822aca4879f3cbbf2b7b5",
    strip_prefix = "rules_rust-3228ccd3814c2ad0d7307d2f87fb8ff9616149d7",
    urls = [
        # Master branch as of 2018-12-11
        "https://github.com/bazelbuild/rules_rust/archive/3228ccd3814c2ad0d7307d2f87fb8ff9616149d7.tar.gz",
    ],
)

load("@io_bazel_rules_rust//rust:repositories.bzl", "rust_repositories")

rust_repositories()

```
nb. `master` currently requires Bazel >= 0.17.0 to work.

### External Dependencies

Currently the most common approach to managing external dependencies is using 
[cargo-raze](https://github.com/google/cargo-raze) to generate `BUILD` files for Cargo crates.  

<a name="roadmap"></a>
## Roadmap

* Improve expressiveness of features and support for [Cargo's feature groups](http://doc.crates.io/manifest.html#the-[features]-section).
* Add `cargo_crate` workspace rule for pulling crates from [Cargo](https://crates.io/).
