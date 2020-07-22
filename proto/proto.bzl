# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load("@rules_proto//proto:defs.bzl", "ProtoInfo")

"""Rust Protobuf Rules

These build rules are used for building [protobufs][protobuf]/[gRPC][grpc] in [Rust][rust] with Bazel.

[rust]: http://www.rust-lang.org/
[protobuf]: https://developers.google.com/protocol-buffers/
[grpc]: https://grpc.io

### Setup

To use the Rust proto rules, add the following to your `WORKSPACE` file to add the
external repositories for the Rust proto toolchain (in addition to the [rust rules setup](..)):

```python
load("@io_bazel_rules_rust//proto:repositories.bzl", "rust_proto_repositories")

rust_proto_repositories()
```
"""

load(
    "@io_bazel_rules_rust//proto:toolchain.bzl",
    "GRPC_COMPILE_DEPS",
    "PROTO_COMPILE_DEPS",
    _generate_proto = "rust_generate_proto",
    _generated_file_stem = "generated_file_stem",
)
load("@io_bazel_rules_rust//rust:private/rustc.bzl", "CrateInfo", "rustc_compile_action")
load("@io_bazel_rules_rust//rust:private/utils.bzl", "find_toolchain")

RustProtoProvider = provider(
    fields = {
        "proto_sources": "List[string]: list of source paths of protos",
        "transitive_proto_sources": "depset[string]",
    },
)

def _compute_proto_source_path(file, source_root_attr):
    """Take the short path of file and make it suitable for protoc."""

    # Bazel creates symlinks to the .proto files under a directory called
    # "_virtual_imports/<rule name>" if we do any sort of munging of import
    # paths (e.g. using strip_import_prefix / import_prefix attributes)
    virtual_imports = "/_virtual_imports/"
    if virtual_imports in file.path:
        return file.path.split(virtual_imports)[1].split("/", 1)[1]

    # For proto, they need to be requested with their absolute name to be
    # compatible with the descriptor_set passed by proto_library.
    # I.e. if you compile a protobuf at @repo1//package:file.proto, the proto
    # compiler would generate a file descriptor with the path
    # `package/file.proto`. Since we compile from the proto descriptor, we need
    # to pass the list of descriptors and the list of path to compile.
    # For the precedent example, the file (noted `f`) would have
    # `f.short_path` returns `external/repo1/package/file.proto`.
    # In addition, proto_library can provide a proto_source_path to change the base
    # path, which should a be a prefix.
    path = file.short_path

    # Strip external prefix.
    path = path.split("/", 2)[2] if path.startswith("../") else path

    # Strip source_root.
    if path.startswith(source_root_attr):
        return path[len(source_root_attr):]
    else:
        return path

def _rust_proto_aspect_impl(target, ctx):
    if ProtoInfo not in target:
        return None

    if hasattr(ctx.rule.attr, "proto_source_root"):
        source_root = ctx.rule.attr.proto_source_root
    else:
        source_root = ""

    if source_root and source_root[-1] != "/":
        source_root += "/"

    sources = [
        _compute_proto_source_path(f, source_root)
        for f in target[ProtoInfo].direct_sources
    ]
    transitive_sources = [
        f[RustProtoProvider].transitive_proto_sources
        for f in ctx.rule.attr.deps
        if RustProtoProvider in f
    ]
    return RustProtoProvider(
        proto_sources = sources,
        transitive_proto_sources = depset(transitive = transitive_sources, direct = sources),
    )

_rust_proto_aspect = aspect(
    _rust_proto_aspect_impl,
    attr_aspects = ["deps"],
)

def _gen_lib(ctx, grpc, srcs, lib):
    """Generate a lib.rs file for the crates."""
    content = ["extern crate protobuf;"]
    if grpc:
        content.append("extern crate grpc;")
        content.append("extern crate tls_api;")
    for f in srcs.to_list():
        content.append("pub mod %s;" % _generated_file_stem(f))
        content.append("pub use %s::*;" % _generated_file_stem(f))
        if grpc:
            content.append("pub mod %s_grpc;" % _generated_file_stem(f))
            content.append("pub use %s_grpc::*;" % _generated_file_stem(f))
    ctx.actions.write(lib, "\n".join(content))

def _expand_provider(lst, provider):
    return [el[provider] for el in lst if provider in el]

def _rust_proto_compile(protos, descriptor_sets, imports, crate_name, ctx, grpc, compile_deps):
    # Create all the source in a specific folder
    proto_toolchain = ctx.toolchains["@io_bazel_rules_rust//proto:toolchain"]
    output_dir = "%s.%s.rust" % (crate_name, "grpc" if grpc else "proto")

    # Generate the proto stubs
    srcs = _generate_proto(
        ctx,
        descriptor_sets,
        protos = protos,
        imports = imports,
        output_dir = output_dir,
        proto_toolchain = proto_toolchain,
        grpc = grpc,
    )

    # and lib.rs
    lib_rs = ctx.actions.declare_file("%s/lib.rs" % output_dir)
    _gen_lib(ctx, grpc, protos, lib_rs)
    srcs.append(lib_rs)

    # And simulate rust_library behavior
    output_hash = repr(hash(lib_rs.path))
    rust_lib = ctx.actions.declare_file("%s/lib%s-%s.rlib" % (
        output_dir,
        crate_name,
        output_hash,
    ))
    result = rustc_compile_action(
        ctx = ctx,
        toolchain = find_toolchain(ctx),
        crate_info = CrateInfo(
            name = crate_name,
            type = "rlib",
            root = lib_rs,
            srcs = srcs,
            deps = compile_deps,
            proc_macro_deps = [],
            aliases = {},
            output = rust_lib,
            edition = proto_toolchain.edition,
            rustc_env = {},
            is_test = False,
        ),
        output_hash = output_hash,
    )
    return result

def _rust_protogrpc_library_impl(ctx, grpc):
    """Implementation of the rust_(proto|grpc)_library."""
    proto = _expand_provider(ctx.attr.deps, ProtoInfo)
    transitive_sources = [
        f[RustProtoProvider].transitive_proto_sources
        for f in ctx.attr.deps
        if RustProtoProvider in f
    ]

    srcs = depset(transitive = transitive_sources)
    return _rust_proto_compile(
        srcs,
        depset(transitive = [p.transitive_descriptor_sets for p in proto]),
        depset(transitive = [p.transitive_imports for p in proto]),
        ctx.label.name,
        ctx,
        grpc,
        ctx.attr.rust_deps,
    )

def _rust_proto_library_impl(ctx):
    return _rust_protogrpc_library_impl(ctx, False)

def _rust_grpc_library_impl(ctx):
    return _rust_protogrpc_library_impl(ctx, True)

rust_proto_library = rule(
    _rust_proto_library_impl,
    attrs = {
        "deps": attr.label_list(
            doc = """
                List of proto_library dependencies that will be built.
                One crate for each proto_library will be created with the corresponding stubs.
            """,
            mandatory = True,
            providers = [ProtoInfo],
            aspects = [_rust_proto_aspect],
        ),
        "rust_deps": attr.label_list(
            doc = "The crates the generated library depends on.",
            default = PROTO_COMPILE_DEPS,
        ),
        "_cc_toolchain": attr.label(default = "@bazel_tools//tools/cpp:current_cc_toolchain"),
        "_rust_tool_wrapper": attr.label(
            default = "@io_bazel_rules_rust//rust/private/rust_tool_wrapper:rust_tool_wrapper",
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),
        "_optional_output_wrapper": attr.label(
            executable = True,
            cfg = "host",
            default = Label(
                "@io_bazel_rules_rust//proto:optional_output_wrapper",
            ),
        ),
    },
    fragments = ["cpp"],
    host_fragments = ["cpp"],
    toolchains = [
        "@io_bazel_rules_rust//proto:toolchain",
        "@io_bazel_rules_rust//rust:toolchain",
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    doc = """
Builds a Rust library crate from a set of `proto_library`s.

Example:

```
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
""",
)

rust_grpc_library = rule(
    _rust_grpc_library_impl,
    attrs = {
        "deps": attr.label_list(
            doc = """
                List of proto_library dependencies that will be built.
                One crate for each proto_library will be created with the corresponding gRPC stubs.
            """,
            mandatory = True,
            providers = [ProtoInfo],
            aspects = [_rust_proto_aspect],
        ),
        "rust_deps": attr.label_list(
            doc = "The crates the generated library depends on.",
            default = GRPC_COMPILE_DEPS,
        ),
        "_cc_toolchain": attr.label(default = "@bazel_tools//tools/cpp:current_cc_toolchain"),
        "_rust_tool_wrapper": attr.label(
            default = "@io_bazel_rules_rust//rust/private/rust_tool_wrapper:rust_tool_wrapper",
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),
        "_optional_output_wrapper": attr.label(
            executable = True,
            cfg = "host",
            default = Label(
                "@io_bazel_rules_rust//proto:optional_output_wrapper",
            ),
        ),
    },
    fragments = ["cpp"],
    host_fragments = ["cpp"],
    toolchains = [
        "@io_bazel_rules_rust//proto:toolchain",
        "@io_bazel_rules_rust//rust:toolchain",
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    doc = """
Builds a Rust library crate from a set of `proto_library`s suitable for gRPC.

Example:

```
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
""",
)
