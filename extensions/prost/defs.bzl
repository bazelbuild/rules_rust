"""# Prost extension

These build rules are used for building [protobufs][protobuf]/[gRPC][grpc] in [Rust][rust] with Bazel
using [Prost][prost] and [Tonic][tonic]

[rust]: http://www.rust-lang.org/
[protobuf]: https://developers.google.com/protocol-buffers/
[grpc]: https://grpc.io
[prost]: https://github.com/tokio-rs/prost
[tonic]: https://github.com/tokio-rs/tonic

## Rules

- [rust_prost_library](#rust_prost_library)
- [rust_prost_toolchain](#rust_prost_toolchain)

## Setup

```python
bazel_dep(name = "rules_rust", version = "{SEE_RELEASE_NOTES}")
```

Load rules from the `rules_rust` extension package:

```python
load("@rules_rust//extensions/prost:defs.bzl", "rust_prost_library")
```

Register `@rules_rust//extensions/prost:default_prost_toolchain`, or define a custom
toolchain as described in [Customizing `prost` and `tonic` Dependencies](#custom-prost-deps).

For additional information about Bazel toolchains, see [here](https://docs.bazel.build/versions/master/toolchains.html).

#### <a name="custom-prost-deps">Customizing `prost` and `tonic` Dependencies

These rules depend on the [`prost`] and [`tonic`] dependencies. To setup the necessary toolchain
for these rules, you must define a toolchain with the [`prost`], [`prost-types`], [`tonic`], [`protoc-gen-prost`], and [`protoc-gen-tonic`] crates as well as the [`protoc`] binary.

[`prost`]: https://crates.io/crates/prost
[`prost-types`]: https://crates.io/crates/prost-types
[`protoc-gen-prost`]: https://crates.io/crates/protoc-gen-prost
[`protoc-gen-tonic`]: https://crates.io/crates/protoc-gen-tonic
[`tonic`]: https://crates.io/crates/tonic
[`protoc`]: https://github.com/protocolbuffers/protobuf

To get access to these crates, you can use the [crate_universe](./crate_universe.md) repository
rules. For example:

```python
load("//crate_universe:defs.bzl", "crate", "crates_repository")

crates_repository(
    name = "crates_io",
    annotations = {
        "protoc-gen-prost": [crate.annotation(
            gen_binaries = ["protoc-gen-prost"],
            patch_args = [
                "-p1",
            ],
            patches = [
                # Note: You will need to use this patch until a version greater than `0.2.2` of
                # `protoc-gen-prost` is released.
                "@rules_rust//proto/prost/private/3rdparty/patches:protoc-gen-prost.patch",
            ],
        )],
        "protoc-gen-tonic": [crate.annotation(
            gen_binaries = ["protoc-gen-tonic"],
        )],
    },
    cargo_lockfile = "Cargo.Bazel.lock",
    mode = "remote",
    packages = {
        "prost": crate.spec(
            version = "0",
        ),
        "prost-types": crate.spec(
            version = "0",
        ),
        "protoc-gen-prost": crate.spec(
            version = "0",
        ),
        "protoc-gen-tonic": crate.spec(
            version = "0",
        ),
        "tonic": crate.spec(
            version = "0",
        ),
    },
    repository_name = "crates_io",
    tags = ["manual"],
)
```

You can then define a toolchain with the `rust_prost_toolchain` rule which uses the crates
defined above. For example:

```python
load("@rules_rust//extensions/prost:defs.bzl", "rust_prost_toolchain")
load("@rules_rust//rust:defs.bzl", "rust_library_group")

rust_library_group(
    name = "prost_runtime",
    deps = [
        "@crates_io//:prost",
    ],
)

rust_library_group(
    name = "tonic_runtime",
    deps = [
        ":prost_runtime",
        "@crates_io//:tonic",
    ],
)

rust_prost_toolchain(
    name = "prost_toolchain_impl",
    prost_plugin = "@crates_io//:protoc-gen-prost__protoc-gen-prost",
    prost_runtime = ":prost_runtime",
    prost_types = "@crates_io//:prost-types",
    proto_compiler = "@com_google_protobuf//:protoc",
    tonic_plugin = "@crates_io//:protoc-gen-tonic__protoc-gen-tonic",
    tonic_runtime = ":tonic_runtime",
)

toolchain(
    name = "prost_toolchain",
    toolchain = "prost_toolchain_impl",
    toolchain_type = "@rules_rust//extensions/prost:toolchain_type",
)
```

Lastly, you must register the toolchain in your `MODULE.bazel` file. For example:

```python
register_toolchains("//toolchains:prost_toolchain")
```

---
---
"""

load(
    "//extensions/prost/private:prost.bzl",
    _rust_prost_library = "rust_prost_library",
    _rust_prost_toolchain = "rust_prost_toolchain",
)
load(
    "//extensions/prost/private:prost_transform.bzl",
    _rust_prost_transform = "rust_prost_transform",
)

rust_prost_library = _rust_prost_library
rust_prost_toolchain = _rust_prost_toolchain
rust_prost_transform = _rust_prost_transform
