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
            list of <code>proto_compile</code> dependencies that will be built. One
            crate for each <code>proto_compile</code> will be created with the corresponding
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

proto_compile(
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
            list of <code>proto_compile</code> dependencies that will be built. One
            crate for each <code>proto_compile</code> will be created with the corresponding
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

proto_compile(
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
