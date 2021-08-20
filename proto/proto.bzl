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
load("//proto:repositories.bzl", "rust_proto_repositories")

rust_proto_repositories()
```
"""

load("@rules_proto//proto:defs.bzl", "ProtoInfo")
load(
    "//proto:toolchain.bzl",
    _generate_proto = "rust_generate_proto",
    _generated_file_stem = "generated_file_stem",
)
load("//rust:rust.bzl", "rust_common")

# buildifier: disable=bzl-visibility
load("//rust/private:rustc.bzl", "rustc_compile_action")

# buildifier: disable=bzl-visibility
load("//rust/private:utils.bzl", "determine_output_hash", "find_toolchain")

RustProtoInfo = provider(
    doc = "Rust protobuf provider info",
    fields = {
        "proto_sources": "List[string]: list of source paths of protos",
        "transitive_proto_sources": "depset[string]",
    },
)

def _compute_proto_source_path(file, source_root_attr):
    """Take the short path of file and make it suitable for protoc.

    Args:
        file (File): The target source file.
        source_root_attr (str): The directory relative to which the `.proto` \
            files defined in the proto_library are defined.

    Returns:
        str: The protoc suitible path of `file`
    """

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
    """The implementation of the `rust_proto_aspect` aspect

    Args:
        target (Target): The target to which the aspect is applied
        ctx (ctx): The rule context which the targetis created from

    Returns:
        list: A list containg a `RustProtoInfo` provider
    """
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
        f[RustProtoInfo].transitive_proto_sources
        for f in ctx.rule.attr.deps
        if RustProtoInfo in f
    ]
    return [RustProtoInfo(
        proto_sources = sources,
        transitive_proto_sources = depset(transitive = transitive_sources, direct = sources),
    )]

_rust_proto_aspect = aspect(
    doc = "An aspect that gathers rust proto direct and transitive sources",
    implementation = _rust_proto_aspect_impl,
    attr_aspects = ["deps"],
)

def _gen_lib(ctx, grpc, srcs, lib):
    """Generate a lib.rs file for the crates.

    Args:
        ctx (ctx): The current rule's context object
        grpc (bool): True if the current rule is a `gRPC` rule.
        srcs (list): A list of protoc suitible file paths (str).
        lib (File): The File object where the rust source file should be written
    """
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
    """Gathers a list of a specific provider from a list of targets.

    Args:
        lst (list): A list of Targets
        provider (Provider): The target provider type to extract `lst`

    Returns:
        list: A list of providers of the type from `provider`.
    """
    return [el[provider] for el in lst if provider in el]

def _rust_proto_compile(protos, descriptor_sets, imports, crate_name, ctx, is_grpc, compile_deps):
    """Create and run a rustc compile action based on the current rule's attributes

    Args:
        protos (depset): Paths of protos to compile.
        descriptor_sets (depset): A set of transitive protobuf `FileDescriptorSet`s
        imports (depset): A set of transitive protobuf Imports.
        crate_name (str): The name of the Crate for the current target
        ctx (ctx): The current rule's context object
        is_grpc (bool): True if the current rule is a `gRPC` rule.
        compile_deps (list): A list of Rust dependencies (`List[Target]`)

    Returns:
        list: A list of providers, see `rustc_compile_action`
    """

    # Create all the source in a specific folder
    proto_toolchain = ctx.toolchains[Label("//proto:toolchain")]
    output_dir = "%s.%s.rust" % (crate_name, "grpc" if is_grpc else "proto")

    # Generate the proto stubs
    srcs = _generate_proto(
        ctx,
        descriptor_sets,
        protos = protos,
        imports = imports,
        output_dir = output_dir,
        proto_toolchain = proto_toolchain,
        is_grpc = is_grpc,
    )

    # and lib.rs
    lib_rs = ctx.actions.declare_file("%s/lib.rs" % output_dir)
    _gen_lib(ctx, is_grpc, protos, lib_rs)
    srcs.append(lib_rs)

    # And simulate rust_library behavior
    output_hash = determine_output_hash(lib_rs)
    rust_lib = ctx.actions.declare_file("%s/lib%s-%s.rlib" % (
        output_dir,
        crate_name,
        output_hash,
    ))

    # Gather all dependencies for compilation
    compile_action_deps = depset(
        compile_deps +
        proto_toolchain.grpc_compile_deps if is_grpc else proto_toolchain.proto_compile_deps,
    )

    return rustc_compile_action(
        ctx = ctx,
        attr = ctx.attr,
        toolchain = find_toolchain(ctx),
        crate_info = rust_common.create_crate_info(
            name = crate_name,
            type = "rlib",
            root = lib_rs,
            srcs = depset(srcs),
            deps = compile_action_deps,
            proc_macro_deps = depset([]),
            aliases = {},
            output = rust_lib,
            edition = proto_toolchain.edition,
            rustc_env = {},
            is_test = False,
            compile_data = depset([target.files for target in getattr(ctx.attr, "compile_data", [])]),
            wrapped_crate_type = None,
        ),
        output_hash = output_hash,
    )

def _rust_protogrpc_library_impl(ctx, is_grpc):
    """Implementation of the rust_(proto|grpc)_library.

    Args:
        ctx (ctx): The current rule's context object
        is_grpc (bool): True if the current rule is a `gRPC` rule.

    Returns:
        list: A list of providers, see `_rust_proto_compile`
    """
    proto = _expand_provider(ctx.attr.deps, ProtoInfo)
    transitive_sources = [
        f[RustProtoInfo].transitive_proto_sources
        for f in ctx.attr.deps
        if RustProtoInfo in f
    ]

    return _rust_proto_compile(
        protos = depset(transitive = transitive_sources),
        descriptor_sets = depset(transitive = [p.transitive_descriptor_sets for p in proto]),
        imports = depset(transitive = [p.transitive_imports for p in proto]),
        crate_name = ctx.label.name,
        ctx = ctx,
        is_grpc = is_grpc,
        compile_deps = ctx.attr.rust_deps,
    )

def _rust_proto_library_impl(ctx):
    """The implementation of the `rust_proto_library` rule

    Args:
        ctx (ctx): The rule's context object.

    Returns:
        list: A list of providers, see `_rust_protogrpc_library_impl`
    """
    return _rust_protogrpc_library_impl(ctx, False)

rust_proto_library = rule(
    implementation = _rust_proto_library_impl,
    attrs = {
        "deps": attr.label_list(
            doc = (
                "List of proto_library dependencies that will be built. " +
                "One crate for each proto_library will be created with the corresponding stubs."
            ),
            mandatory = True,
            providers = [ProtoInfo],
            aspects = [_rust_proto_aspect],
        ),
        "rust_deps": attr.label_list(
            doc = "The crates the generated library depends on.",
        ),
        "_cc_toolchain": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
        "_optional_output_wrapper": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//proto:optional_output_wrapper"),
        ),
        "_process_wrapper": attr.label(
            default = Label("//util/process_wrapper"),
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),
    },
    fragments = ["cpp"],
    host_fragments = ["cpp"],
    toolchains = [
        str(Label("//proto:toolchain")),
        str(Label("//rust:toolchain")),
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    # TODO: Remove once (bazelbuild/bazel#11584) is closed and the rules use
    # the version of Bazel that issue was closed on as the min supported version
    incompatible_use_toolchain_transition = True,
    doc = """\
Builds a Rust library crate from a set of `proto_library`s.

Example:

```python
load("@rules_rust//proto:proto.bzl", "rust_proto_library")

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
    deps = [":rust"],
)
```
""",
)

def _rust_grpc_library_impl(ctx):
    """The implementation of the `rust_grpc_library` rule

    Args:
        ctx (ctx): The rule's context object

    Returns:
        list: A list of providers. See `_rust_protogrpc_library_impl`
    """
    return _rust_protogrpc_library_impl(ctx, True)

rust_grpc_library = rule(
    implementation = _rust_grpc_library_impl,
    attrs = {
        "deps": attr.label_list(
            doc = (
                "List of proto_library dependencies that will be built. " +
                "One crate for each proto_library will be created with the corresponding gRPC stubs."
            ),
            mandatory = True,
            providers = [ProtoInfo],
            aspects = [_rust_proto_aspect],
        ),
        "rust_deps": attr.label_list(
            doc = "The crates the generated library depends on.",
        ),
        "_cc_toolchain": attr.label(
            default = "@bazel_tools//tools/cpp:current_cc_toolchain",
        ),
        "_optional_output_wrapper": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//proto:optional_output_wrapper"),
        ),
        "_process_wrapper": attr.label(
            default = Label("//util/process_wrapper"),
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),
    },
    fragments = ["cpp"],
    host_fragments = ["cpp"],
    toolchains = [
        str(Label("//proto:toolchain")),
        str(Label("//rust:toolchain")),
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    # TODO: Remove once (bazelbuild/bazel#11584) is closed and the rules use
    # the version of Bazel that issue was closed on as the min supported version
    incompatible_use_toolchain_transition = True,
    doc = """\
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
""",
)
