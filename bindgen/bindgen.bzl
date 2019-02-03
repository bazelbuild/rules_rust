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

load("@io_bazel_rules_rust//rust:rust.bzl", "rust_library")

def rust_bindgen_library(name, header, cc_lib, **kwargs):
    """Generates a rust source file for `header`, and builds a rust_library."""

    rust_bindgen(
        name = name + "__bindgen",
        header = header,
        cc_lib = cc_lib,
        **kwargs
    )
    rust_library(
        name = name,
        srcs = [name + "__bindgen.rs"],
        deps = [cc_lib],
    )

def _rust_bindgen_impl(ctx):
    # nb. We can't grab the cc_library`s direct headers, so a header must be provided.
    cc_lib = ctx.attr.cc_lib
    header = ctx.file.header
    if header not in cc_lib.cc.transitive_headers:
        fail("Header {} is not in {}'s transitive headers.".format(ctx.attr.header, cc_lib), "header")

    toolchain = ctx.toolchains["@io_bazel_rules_rust//bindgen:bindgen_toolchain"]
    bindgen_bin = toolchain.bindgen
    rustfmt_bin = toolchain.rustfmt
    clang_bin = toolchain.clang
    libclang = toolchain.libclang

    # TODO: This should not need to be explicitly provided, see below TODO.
    libstdcxx = toolchain.libstdcxx

    # rustfmt is not where bindgen expects to find it, so we format manually
    bindgen_args = ["--no-rustfmt-bindings"] + ctx.attr.bindgen_flags
    clang_args = ctx.attr.clang_flags

    output = ctx.outputs.out

    # libclang should only have 1 output file
    libclang_dir = libclang.cc.libs.to_list()[0].dirname
    include_directories = depset(
        [f.dirname for f in cc_lib.cc.transitive_headers],
    )

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
    args.add_all(clang_args)
    ctx.actions.run(
        executable = bindgen_bin,
        inputs = depset(
            [header],
            transitive = [cc_lib.cc.transitive_headers, libclang.cc.libs, libstdcxx.cc.libs],
        ),
        outputs = [unformatted_output],
        mnemonic = "RustBindgen",
        progress_message = "Generating bindings for {}..".format(header.path),
        env = {
            "RUST_BACKTRACE": "1",
            "CLANG_PATH": clang_bin.path,
            # Bindgen loads libclang at runtime, which also needs libstdc++, so we setup LD_LIBRARY_PATH
            "LIBCLANG_PATH": libclang_dir,
            # TODO: If libclang were built by bazel from source w/ properly specified dependencies, it
            #       would have the correct rpaths and not require this nor would this rule
            #       have a direct dependency on libstdc++.so
            #       This is unnecessary if the system libstdc++ suffices, which may not always be the case.
            "LD_LIBRARY_PATH": ":".join([f.dirname for f in libstdcxx.cc.libs]),
        },
        arguments = [args],
        tools = [clang_bin],
    )

    if rustfmt_bin:
        ctx.actions.run_shell(
            inputs = depset([rustfmt_bin, unformatted_output]),
            outputs = [output],
            command = "{} --emit stdout --quiet {} > {}".format(rustfmt_bin.path, unformatted_output.path, output.path),
            tools = [rustfmt_bin],
        )

rust_bindgen = rule(
    _rust_bindgen_impl,
    doc = "Generates a rust source file from a cc_library and a header.",
    attrs = {
        "header": attr.label(
            doc = "The .h file to generate bindings for.",
            allow_single_file = True,
        ),
        "cc_lib": attr.label(
            doc = "The cc_library that contains the .h file. This is used to find the transitive includes.",
            providers = ["cc"],
        ),
        "bindgen_flags": attr.string_list(
            doc = "Flags to pass directly to the bindgen executable. See https://rust-lang.github.io/rust-bindgen/ for details.",
        ),
        "clang_flags": attr.string_list(
            doc = "Flags to pass directly to the clang executable.",
        ),
    },
    outputs = {"out": "%{name}.rs"},
    toolchains = [
        "@io_bazel_rules_rust//bindgen:bindgen_toolchain",
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
            providers = ["cc"],
        ),
        "libstdcxx": attr.label(
            doc = "A cc_library that satisfies libclang's libstdc++ dependency.",
            providers = ["cc"],
        ),
    },
)