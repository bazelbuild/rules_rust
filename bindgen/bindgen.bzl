# Copyright 2019 The Bazel Authors. All rights reserved.
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

load("@io_bazel_rules_rust//rust:private/legacy_cc_starlark_api_shim.bzl", "get_libs_for_static_executable")
load("@io_bazel_rules_rust//rust:private/utils.bzl", "find_toolchain")
load("@io_bazel_rules_rust//rust:rust.bzl", "rust_library")

def rust_bindgen_library(
        name,
        header,
        cc_lib,
        bindgen_flags = None,
        clang_flags = None,
        **kwargs):
    """Generates a rust source file for `header`, and builds a rust_library.

    Arguments are the same as `rust_bindgen`, and `kwargs` are passed directly to rust_library.

    Args:
        name (str): A unique name for this target.
        header (str): The label of the .h file to generate bindings for.
        cc_lib (str): The label of the cc_library that contains the .h file. This is used to find the transitive includes.
        bindgen_flags (list, optional): Flags to pass directly to the bindgen executable. See https://rust-lang.github.io/rust-bindgen/ for details.
        clang_flags (list, optional): Flags to pass directly to the clang executable.
        **kwargs: Arguments to forward to the underlying `rust_library` rule.
    """

    rust_bindgen(
        name = name + "__bindgen",
        header = header,
        cc_lib = cc_lib,
        bindgen_flags = bindgen_flags or [],
        clang_flags = clang_flags or [],
    )
    rust_library(
        name = name,
        srcs = [name + "__bindgen.rs"],
        deps = [cc_lib],
        **kwargs
    )

def _rust_bindgen_impl(ctx):
    rust_toolchain = find_toolchain(ctx)

    # nb. We can't grab the cc_library`s direct headers, so a header must be provided.
    cc_lib = ctx.attr.cc_lib
    header = ctx.file.header
    cc_header_list = ctx.attr.cc_lib[CcInfo].compilation_context.headers.to_list()
    if header not in cc_header_list:
        fail("Header {} is not in {}'s transitive headers.".format(ctx.attr.header, cc_lib), "header")

    toolchain = ctx.toolchains["@io_bazel_rules_rust//bindgen:bindgen_toolchain"]
    bindgen_bin = toolchain.bindgen
    rustfmt_bin = toolchain.rustfmt or rust_toolchain.rustfmt
    clang_bin = toolchain.clang
    libclang = toolchain.libclang

    # TODO: This rule shouldn't need to depend on libstdc++
    #  This rule requires an explicit dependency on a libstdc++ because
    #    1. It is a runtime dependency of libclang.so
    #    2. We cannot locate it in the cc_toolchain yet
    #  Depending on how libclang.so was compiled, it may try to locate its libstdc++ dependency
    #  in a way that makes our handling here unnecessary (eg. system /usr/lib/x86_64-linux-gnu/libstdc++.so.6)
    libstdcxx = toolchain.libstdcxx

    # rustfmt is not where bindgen expects to find it, so we format manually
    bindgen_args = ["--no-rustfmt-bindings"] + ctx.attr.bindgen_flags
    clang_args = ctx.attr.clang_flags

    output = ctx.outputs.out

    # libclang should only have 1 output file
    libclang_dir = get_libs_for_static_executable(libclang).to_list()[0].dirname
    include_directories = cc_lib[CcInfo].compilation_context.includes.to_list()
    quote_include_directories = cc_lib[CcInfo].compilation_context.quote_includes.to_list()
    system_include_directories = cc_lib[CcInfo].compilation_context.system_includes.to_list()

    # Vanilla usage of bindgen produces formatted output, here we do the same if we have `rustfmt` in our toolchain.
    if rustfmt_bin:
        unformatted_output = ctx.actions.declare_file(output.basename + ".unformatted")
    else:
        unformatted_output = output

    args = ctx.actions.args()
    args.add_all(bindgen_args)
    args.add(header.path)
    args.add("--output", unformatted_output.path)
    args.add("--")
    args.add_all(include_directories, before_each = "-I")
    args.add_all(quote_include_directories, before_each = "-iquote")
    args.add_all(system_include_directories, before_each = "-isystem")
    args.add_all(clang_args)

    env = {
        "CLANG_PATH": clang_bin.path,
        "LIBCLANG_PATH": libclang_dir,
        "RUST_BACKTRACE": "1",
    }

    if libstdcxx:
        env["LD_LIBRARY_PATH"] = ":".join([f.dirname for f in get_libs_for_static_executable(libstdcxx).to_list()])

    ctx.actions.run(
        executable = bindgen_bin,
        inputs = depset(
            [header],
            transitive = [
                cc_lib[CcInfo].compilation_context.headers,
                get_libs_for_static_executable(libclang),
            ] + [
                get_libs_for_static_executable(libstdcxx),
            ] if libstdcxx else [],
        ),
        outputs = [unformatted_output],
        mnemonic = "RustBindgen",
        progress_message = "Generating bindings for {}..".format(header.path),
        env = env,
        arguments = [args],
        tools = [clang_bin],
    )

    if rustfmt_bin:
        rustfmt_args = ctx.actions.args()
        rustfmt_args.add("--stdout-file", output.path)
        rustfmt_args.add("--")
        rustfmt_args.add(rustfmt_bin.path)
        rustfmt_args.add("--emit", "stdout")
        rustfmt_args.add("--quiet")
        rustfmt_args.add(unformatted_output.path)

        ctx.actions.run(
            executable = ctx.executable._process_wrapper,
            inputs = [unformatted_output],
            outputs = [output],
            arguments = [rustfmt_args],
            tools = [rustfmt_bin],
            mnemonic = "Rustfmt",
        )

rust_bindgen = rule(
    doc = "Generates a rust source file from a cc_library and a header.",
    implementation = _rust_bindgen_impl,
    attrs = {
        "header": attr.label(
            doc = "The .h file to generate bindings for.",
            allow_single_file = True,
        ),
        "cc_lib": attr.label(
            doc = "The cc_library that contains the .h file. This is used to find the transitive includes.",
            providers = [CcInfo],
        ),
        "bindgen_flags": attr.string_list(
            doc = "Flags to pass directly to the bindgen executable. See https://rust-lang.github.io/rust-bindgen/ for details.",
        ),
        "clang_flags": attr.string_list(
            doc = "Flags to pass directly to the clang executable.",
        ),
        "_process_wrapper": attr.label(
            default = "@io_bazel_rules_rust//util/process_wrapper",
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),
    },
    outputs = {"out": "%{name}.rs"},
    toolchains = [
        "@io_bazel_rules_rust//bindgen:bindgen_toolchain",
        "@io_bazel_rules_rust//rust:toolchain",
    ],
)

def _rust_bindgen_toolchain_impl(ctx):
    return platform_common.ToolchainInfo(
        bindgen = ctx.executable.bindgen,
        clang = ctx.executable.clang,
        libclang = ctx.attr.libclang,
        libstdcxx = ctx.attr.libstdcxx,
        rustfmt = ctx.executable.rustfmt,
    )

rust_bindgen_toolchain = rule(
    _rust_bindgen_toolchain_impl,
    doc = "The tools required for the `rust_bindgen` rule.",
    attrs = {
        "bindgen": attr.label(
            doc = "The label of a `bindgen` executable.",
            executable = True,
            cfg = "host",
        ),
        "rustfmt": attr.label(
            doc = "The label of a `rustfmt` executable. If this is provided, generated sources will be formatted.",
            executable = True,
            cfg = "host",
            mandatory = False,
        ),
        "clang": attr.label(
            doc = "The label of a `clang` executable.",
            executable = True,
            cfg = "host",
        ),
        "libclang": attr.label(
            doc = "A cc_library that provides bindgen's runtime dependency on libclang.",
            cfg = "host",
            providers = [CcInfo],
        ),
        "libstdcxx": attr.label(
            doc = "A cc_library that satisfies libclang's libstdc++ dependency.",
            cfg = "host",
            providers = [CcInfo],
        ),
    },
)
