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
    "//proto:toolchain.bzl",
    "rust_proto_toolchain",
    _generate_proto = "rust_generate_proto",
)
load("//rust:private/rustc.bzl", "CrateInfo", "CrateInfos", "DepInfo", "rustc_compile_action")
load("//rust:private/utils.bzl", "find_toolchain")

def _basename(f):
    return f.basename[:-len(f.extension) - 1]

def _gen_lib(ctx, grpc, deps, srcs, lib):
    """Generate a lib.rs file for the crates."""
    content = ["extern crate protobuf;"]
    if grpc:
        content.append("extern crate grpc;")
        content.append("extern crate tls_api;")
    for dep in deps:
        content.append("extern crate %s;" % dep.label.name)
        content.append("pub use %s::*;" % dep.label.name)
    for f in srcs:
        content.append("pub mod %s;" % _basename(f))
        content.append("pub use %s::*;" % _basename(f))
        if grpc:
            content.append("pub mod %s_grpc;" % _basename(f))
            content.append("pub use %s_grpc::*;" % _basename(f))
    ctx.actions.write(
        lib,
        "\n".join(content),
        False,
    )

def _expand_provider(lst, provider):
    return [el[provider] for el in lst if provider in el]

def _rust_proto_compile(inputs, descriptor_sets, imports, crate_name, ctx, deps, grpc, output_dir, compile_deps):
    # Create all the source in a specific folder
    toolchain = ctx.toolchains["@io_bazel_rules_rust//proto:toolchain"]

    # Generate the proto stubs
    srcs = _generate_proto(
        ctx,
        descriptor_sets,
        inputs = inputs,
        imports = imports,
        output_dir = output_dir,
        proto_toolchain = toolchain,
        grpc = grpc,
    )

    # and lib.rs
    lib_rs = ctx.actions.declare_file("%s/lib.rs" % output_dir)
    _gen_lib(ctx, grpc, deps, inputs, lib_rs)
    srcs.append(lib_rs)

    # Collect dependencies
    direct_deps = [
        dep
        for dep in deps
        if CrateInfo in dep
    ]

    # And simulate rust_library behavior
    output_hash = repr(hash(lib_rs.path))
    rust_lib = ctx.actions.declare_file("%s/lib%s-%s.rlib" % (
        output_dir, crate_name, output_hash))
    result = rustc_compile_action(
        ctx = ctx,
        toolchain = find_toolchain(ctx),
        crate_info = CrateInfo(
            name = crate_name,
            type = "rlib",
            root = lib_rs,
            srcs = srcs,
            deps = direct_deps + compile_deps,
            output = rust_lib,
        ),
        output_hash = output_hash,
    )
    return [result[0], result[1]]

def _rust_aspect_impl(target, ctx, grpc):
    """Implementation of the aspect that we apply on all proto_library
    that depends on a rust_(proto|grpc)_library.

    This aspect creates the rust stubs from the descriptor sets generated
    from the proto_library, then a lib.rs and compile the whole crates.

    Args:
        target: the target the aspect is applied to.
        ctx: the aspect context.
        grpc: wether to build for gRPC or for protobuf.
    """
    toolchain = ctx.toolchains["@io_bazel_rules_rust//proto:toolchain"]
    output_dir = "%s.%s.rust" % (target.label.name, "grpc" if grpc else "proto")
    compile_deps = toolchain.grpc_compile_deps if grpc else toolchain.proto_compile_deps
    return _rust_proto_compile(
        target.proto.direct_sources,
        target.proto.transitive_descriptor_sets,
        target.proto.transitive_imports,
        target.label.name,
        ctx,
        ctx.rule.attr.deps,
        grpc,
        output_dir,
        compile_deps
    )

# Proto aspect
def _rust_proto_aspect_impl(target, ctx):
    return _rust_aspect_impl(target, ctx, False)

_rust_proto_aspect = aspect(
    _rust_proto_aspect_impl,
    attr_aspects = ["deps"],
    host_fragments = ["cpp"],
    fragments = ["cpp"],
    attrs = {
        "_cc_toolchain": attr.label(default = "@bazel_tools//tools/cpp:current_cc_toolchain"),
    },
    toolchains = [
        "@io_bazel_rules_rust//proto:toolchain",
        "@io_bazel_rules_rust//rust:toolchain",
    ],
)

# gRPC aspect
def _rust_grpc_aspect_impl(target, ctx):
    return _rust_aspect_impl(target, ctx, True)

_rust_grpc_aspect = aspect(
    _rust_grpc_aspect_impl,
    attr_aspects = ["deps"],
    host_fragments = ["cpp"],
    fragments = ["cpp"],
    attrs = {
        "_cc_toolchain": attr.label(default = "@bazel_tools//tools/cpp:current_cc_toolchain"),
    },
    toolchains = [
        "@io_bazel_rules_rust//proto:toolchain",
        "@io_bazel_rules_rust//rust:toolchain",
    ],
)

def _rust_proto_library_impl(ctx):
    """Implementation of the rust_(proto|grpc)_library."""

    # Everything should be done by the aspect we just need to rexpose the correct
    # providers.
    depinfos = _expand_provider(ctx.attr.deps, DepInfo)
    crate_infos = _expand_provider(ctx.attr.deps, CrateInfo)
    files = [d.output for d in crate_infos]
    depinfo = DepInfo(
        direct_crates=depset(crate_infos),
        indirect_crates=depset(transitive=[d.indirect_crates for d in depinfos]),
        transitive_crates=depset(transitive=[d.transitive_crates for d in depinfos]),
        transitive_dylibs=depset(transitive=[d.transitive_dylibs for d in depinfos]),
        transitive_staticlibs=depset(transitive=[d.transitive_staticlibs for d in depinfos]),
        transitive_libs=depset(transitive=[d.transitive_libs for d in depinfos]),
    )
    # We return a rust_libs that can be used by rust_library
    return [
        CrateInfos(crate_infos=crate_infos),
        depinfo,
        DefaultInfo(files = depset(files))
    ]

rust_proto_library = rule(
    _rust_proto_library_impl,
    attrs = {
        "deps": attr.label_list(
            mandatory = True,
            providers = ["proto"],
            aspects = [_rust_proto_aspect],
        ),
    },
    toolchains = [
        "@io_bazel_rules_rust//proto:toolchain",
        "@io_bazel_rules_rust//rust:toolchain",
    ],
)
"""Builds a Rust library crate from a set of proto_library-s.

Args:
  name: name of the target.
  deps: list of proto_compile dependencies that will be built. One
    crate for each proto_compile will be created with the corresponding
    stubs.

Example:

```
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
"""

rust_grpc_library = rule(
    _rust_proto_library_impl,
    attrs = {
        "deps": attr.label_list(
            mandatory = True,
            providers = ["proto"],
            aspects = [_rust_grpc_aspect],
        ),
    },
    toolchains = [
        "@io_bazel_rules_rust//proto:toolchain",
        "@io_bazel_rules_rust//rust:toolchain",
    ],
)
"""Builds a Rust library crate from a set of proto_library-s suitable for gRPC.

Args:
  name: name of the target.
  deps: list of proto_compile dependencies that will be built. One
    crate for each proto_compile will be created with the corresponding
    gRPC stubs.

Example:

```
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
"""
