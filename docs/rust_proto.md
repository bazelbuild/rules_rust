<!-- Generated with Stardoc: http://skydoc.bazel.build -->
# Rust Proto

* [rust_grpc_library](#rust_grpc_library)
* [rust_proto_library](#rust_proto_library)
* [rust_proto_repositories](#rust_proto_repositories)
* [rust_proto_transitive_repositories](#rust_proto_transitive_repositories)
* [rust_proto_toolchain](#rust_proto_toolchain)


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
load("@rules_rust//proto:repositories.bzl", "rust_proto_repositories")

rust_proto_repositories()

load("@rules_rust//proto:transitive_repositories.bzl", "rust_proto_transitive_repositories")

rust_proto_transitive_repositories()
```

[raze]: https://github.com/google/cargo-raze

This will load crate dependencies of protobuf that are generated using
[cargo raze][raze] inside the rules_rust
repository. However, using those dependencies might conflict with other uses
of [cargo raze][raze]. If you need to change
those dependencies, please see the [dedicated section below](#custom-deps).

For additional information about Bazel toolchains, see [here](https://docs.bazel.build/versions/master/toolchains.html).

## <a name="custom-deps">Customizing dependencies

These rules depends on the [`protobuf`](https://crates.io/crates/protobuf) and
the [`grpc`](https://crates.io/crates/grpc) crates in addition to the [protobuf
compiler](https://github.com/google/protobuf). To obtain these crates,
`rust_proto_repositories` imports the given crates using BUILD files generated with
[`cargo raze`][raze].

If you want to either change the protobuf and gRPC rust compilers, or to
simply use [`cargo raze`][raze] in a more
complex scenario (with more dependencies), you must redefine those
dependencies.

To do this, once you've imported the needed dependencies (see our
[Cargo.toml](raze/Cargo.toml) file to see the default dependencies), you
need to create your own toolchain. To do so you can create a BUILD
file with your toolchain definition, for example:

```python
load("@rules_rust//proto:toolchain.bzl", "rust_proto_toolchain")

rust_proto_toolchain(
    name = "proto-toolchain-impl",
    # Path to the protobuf compiler.
    protoc = "@com_google_protobuf//:protoc",
    # Protobuf compiler plugin to generate rust gRPC stubs.
    grpc_plugin = "//cargo_raze/remote:cargo_bin_protoc_gen_rust_grpc",
    # Protobuf compiler plugin to generate rust protobuf stubs.
    proto_plugin = "//cargo_raze/remote:cargo_bin_protoc_gen_rust",
)

toolchain(
    name = "proto-toolchain",
    toolchain = ":proto-toolchain-impl",
    toolchain_type = "@rules_rust//proto:toolchain_type",
)
```

Now that you have your own toolchain, you need to register it by
inserting the following statement in your `WORKSPACE` file:

```python
register_toolchains("//my/toolchains:proto-toolchain")
```

Finally, you might want to set the `rust_deps` attribute in
`rust_proto_library` and `rust_grpc_library` to change the compile-time
dependencies:

```python
rust_proto_library(
    ...
    rust_deps = ["//cargo_raze/remote:protobuf"],
    ...
)

rust_grpc_library(
    ...
    rust_deps = [
        "//cargo_raze/remote:protobuf",
        "//cargo_raze/remote:grpc",
        "//cargo_raze/remote:tls_api",
        "//cargo_raze/remote:tls_api_stub",
    ],
    ...
)
```

__Note__: Ideally, we would inject those dependencies from the toolchain,
but due to [bazelbuild/bazel#6889](https://github.com/bazelbuild/bazel/issues/6889)
all dependencies added via the toolchain ends-up being in the wrong
configuration.


<a id="rust_grpc_library"></a>

## rust_grpc_library

<pre>
rust_grpc_library(<a href="#rust_grpc_library-name">name</a>, <a href="#rust_grpc_library-deps">deps</a>, <a href="#rust_grpc_library-rust_deps">rust_deps</a>)
</pre>

Builds a Rust library crate from a set of `proto_library`s suitable for gRPC.

Example:

```python
load("//proto:proto.bzl", "rust_grpc_library")

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
    deps = [":rust"],
)
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_grpc_library-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="rust_grpc_library-deps"></a>deps |  List of proto_library dependencies that will be built. One crate for each proto_library will be created with the corresponding gRPC stubs.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="rust_grpc_library-rust_deps"></a>rust_deps |  The crates the generated library depends on.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |


<a id="rust_proto_library"></a>

## rust_proto_library

<pre>
rust_proto_library(<a href="#rust_proto_library-name">name</a>, <a href="#rust_proto_library-deps">deps</a>, <a href="#rust_proto_library-rust_deps">rust_deps</a>)
</pre>

Builds a Rust library crate from a set of `proto_library`s.

Example:

```python
load("@rules_rust//proto:proto.bzl", "rust_proto_library")

proto_library(
    name = "my_proto",
    srcs = ["my.proto"]
)

rust_proto_library(
    name = "rust",
    deps = [":my_proto"],
)

rust_binary(
    name = "my_proto_binary",
    srcs = ["my_proto_binary.rs"],
    deps = [":rust"],
)
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_proto_library-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="rust_proto_library-deps"></a>deps |  List of proto_library dependencies that will be built. One crate for each proto_library will be created with the corresponding stubs.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="rust_proto_library-rust_deps"></a>rust_deps |  The crates the generated library depends on.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |


<a id="rust_proto_toolchain"></a>

## rust_proto_toolchain

<pre>
rust_proto_toolchain(<a href="#rust_proto_toolchain-name">name</a>, <a href="#rust_proto_toolchain-edition">edition</a>, <a href="#rust_proto_toolchain-grpc_compile_deps">grpc_compile_deps</a>, <a href="#rust_proto_toolchain-grpc_plugin">grpc_plugin</a>, <a href="#rust_proto_toolchain-proto_compile_deps">proto_compile_deps</a>,
                     <a href="#rust_proto_toolchain-proto_plugin">proto_plugin</a>, <a href="#rust_proto_toolchain-protoc">protoc</a>)
</pre>

Declares a Rust Proto toolchain for use.

This is used to configure proto compilation and can be used to set different protobuf compiler plugin.

Example:

Suppose a new nicer gRPC plugin has came out. The new plugin can be used in Bazel by defining a new toolchain definition and declaration:

```python
load('@rules_rust//proto:toolchain.bzl', 'rust_proto_toolchain')

rust_proto_toolchain(
   name="rust_proto_impl",
   grpc_plugin="@rust_grpc//:grpc_plugin",
   grpc_compile_deps=["@rust_grpc//:grpc_deps"],
)

toolchain(
    name="rust_proto",
    exec_compatible_with = [
        "@platforms//cpu:cpuX",
    ],
    target_compatible_with = [
        "@platforms//cpu:cpuX",
    ],
    toolchain = ":rust_proto_impl",
)
```

Then, either add the label of the toolchain rule to register_toolchains in the WORKSPACE, or pass it to the `--extra_toolchains` flag for Bazel, and it will be used.

See @rules_rust//proto:BUILD for examples of defining the toolchain.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_proto_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="rust_proto_toolchain-edition"></a>edition |  The edition used by the generated rust source.   | String | optional | <code>""</code> |
| <a id="rust_proto_toolchain-grpc_compile_deps"></a>grpc_compile_deps |  The crates the generated grpc libraries depends on.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[Label("//proto/3rdparty/crates:protobuf"), Label("//proto/3rdparty/crates:grpc"), Label("//proto/3rdparty/crates:tls-api"), Label("//proto/3rdparty/crates:tls-api-stub")]</code> |
| <a id="rust_proto_toolchain-grpc_plugin"></a>grpc_plugin |  The location of the Rust protobuf compiler plugin to generate rust gRPC stubs.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | <code>//proto:protoc_gen_rust_grpc</code> |
| <a id="rust_proto_toolchain-proto_compile_deps"></a>proto_compile_deps |  The crates the generated protobuf libraries depends on.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[Label("//proto/3rdparty/crates:protobuf")]</code> |
| <a id="rust_proto_toolchain-proto_plugin"></a>proto_plugin |  The location of the Rust protobuf compiler plugin used to generate rust sources.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | <code>//proto:protoc_gen_rust</code> |
| <a id="rust_proto_toolchain-protoc"></a>protoc |  The location of the <code>protoc</code> binary. It should be an executable target.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | <code>@com_google_protobuf//:protoc</code> |


<a id="rust_proto_repositories"></a>

## rust_proto_repositories

<pre>
rust_proto_repositories(<a href="#rust_proto_repositories-register_default_toolchain">register_default_toolchain</a>)
</pre>

Declare dependencies needed for proto compilation.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rust_proto_repositories-register_default_toolchain"></a>register_default_toolchain |  If True, the default [rust_proto_toolchain](#rust_proto_toolchain) (<code>@rules_rust//proto:default-proto-toolchain</code>) is registered. This toolchain requires a set of dependencies that were generated using [cargo raze](https://github.com/google/cargo-raze). These will also be loaded.   |  `True` |


<a id="rust_proto_transitive_repositories"></a>

## rust_proto_transitive_repositories

<pre>
rust_proto_transitive_repositories()
</pre>

Load transitive dependencies of the `@rules_rust//proto` rules.

This macro should be called immediately after the `rust_proto_repositories` macro.



