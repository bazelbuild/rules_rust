# Rust Protobuf Rules

<div class="toc">
  <h2>Rules</h2>
  <ul>
    <li><a href="#rust_proto_library">rust_proto_library</a></li>
    <li><a href="#rust_grpc_library">rust_grpc_library</a></li>
  </ul>
</div>

## Overview

These build rules are used for building [protobufs][protobuf]/[gRPC][grpc] in [Rust][rust] with Bazel.

[rust]: http://www.rust-lang.org/
[protobuf]: https://developers.google.com/protocol-buffers/
[grpc]: https://grpc.io

See the [protobuf example](../examples/proto) for a more complete example of use.

### Setup

To use the Rust proto rules, add the following to your `WORKSPACE` file to add the
external repositories for the Rust proto toolchain (in addition to the [rust rules setup](..)):

```python
load("@io_bazel_rules_rust//proto:repositories.bzl", "rust_proto_repositories")

rust_proto_repositories()
```

This will load crate dependencies of protobuf that are generated using
[cargo raze](https://github.com/google/cargo-raze) inside the rules_rust
repository. However, using those dependencies might conflict with other uses
of [cargo raze](https://github.com/google/cargo-raze). If you need to change
those dependencies, please see the [dedicated section below](#custom-deps).

<a name="rust_proto_library"></a>
## rust_proto_library

```python
rust_proto_library(name, deps)
```

Builds a Rust library crate from a set of proto_library-s.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <code>Name, required</code>
        <p>A unique name for this rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <code>List of labels, required</code>
        <p>
            list of <code>proto_library</code> dependencies that will be built. One
            crate for each <code>proto_library</code> will be created with the corresponding
            stubs.
        </p>
      </td>
    </tr>
  </tbody>
</table>

## Example

```python
load("@io_bazel_rules_rust//proto:proto.bzl", "rust_proto_library")
load("@io_bazel_rules_rust//proto:toolchain.bzl", "PROTO_COMPILE_DEPS")

proto_library(
    name = "my_proto",
    srcs = ["my.proto"]
)

proto_rust_library(
    name = "rust",
    deps = [":my_proto"],
)

rust_binary(
    name = "my_proto_binary",
    srcs = ["my_proto_binary.rs"],
    deps = [":rust"] + PROTO_COMPILE_DEPS,
)
```


<a name="rust_grpc_library"></a>
## rust_grpc_library

```python
rust_grpc_library(name, deps)
```

Builds a Rust library crate from a set of proto_library-s suitable for gRPC.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <code>Name, required</code>
        <p>A unique name for this rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <code>List of labels, required</code>
        <p>
            list of <code>proto_library</code> dependencies that will be built. One
            crate for each <code>proto_library</code> will be created with the corresponding
            gRPC stubs.
        </p>
      </td>
    </tr>
  </tbody>
</table>

## Example

```python
load("@io_bazel_rules_rust//proto:proto.bzl", "rust_grpc_library")
load("@io_bazel_rules_rust//proto:toolchain.bzl", "GRPC_COMPILE_DEPS")

proto_library(
    name = "my_proto",
    srcs = ["my.proto"]
)

rust_grpc_library(
    name = "rust",
    deps = [":my_proto"],
)

rust_binary(
    name = "my_service",
    srcs = ["my_service.rs"],
    deps = [":rust"] + GRPC_COMPILE_DEPS,
)
```

## <a name="custom-deps">Customizing dependencies

These rules depends on the [`protobuf`](https://crates.io/crates/protobuf) and
the [`grpc`](https://crates.io/crates/grpc) crates in addition to the [protobuf
compiler](https://github.com/google/protobuf). To do so the
`rust_proto_repositories` import the given crates using file generated with
[`cargo raze`](https://github.com/google/cargo-raze).

If you want to either change the protobuf and gRPC rust compilers, or to
simply use [`cargo raze`](https://github.com/google/cargo-raze) in a more
complex scenario (with more dependencies), you must redefine those
dependencies.

To do this, once you imported th needed dependencies (see our
[Cargo.toml](raze/Cargo.toml) file to see the default dependencies), you
need to point to the correct toolchain, to do so you can create a BUILD
file with the toolchain definition, for example:

```python
load("@io_bazel_rules_rust//proto:toolchain.bzl", "rust_proto_toolchain")

toolchain(
    name = "toolchain",
    toolchain = ":toolchain-impl",
    toolchain_type = "@io_bazel_rules_rust//proto:toolchain",
)

rust_proto_toolchain(
    name = "toolchain-impl",
    # Path to the protobuf compiler.
    protoc = "@com_google_protobuf//:protoc",
    # Compile-time dependencies for gRPC crates.
    grpc_compile_deps = [
      "//cargo_raze/remote:protobuf",
      "//cargo_raze/remote:grpc",
      "//cargo_raze/remote:tls_api",
      "//cargo_raze/remote:tls_api_stub",
    ]
    # Protobuf compiler plugin to generate rust gRPC stubs.
    grpc_plugin = "//cargo_raze/remote:cargo_bin_protoc_gen_rust_grpc",
    # Compile-time dependencies for protobuf crates.
    proto_compile_deps = ["//cargo_raze/remote:protobuf"],
    # Protobuf compiler plugin to generate rust protobuf stubs.
    proto_plugin = "//cargo_raze/remote:cargo_bin_protoc_gen_rust",
)
```

Finally, now that you have your own toolchain, you need to register it by
inserting the following statement in your `WORKSPACE` file:

```python
register_toolchains(["//package:toolchain"])
```
