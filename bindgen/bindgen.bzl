# Copyright 2015 The Bazel Authors. All rights reserved.
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

load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("@io_bazel_rules_rust//rust:rust.bzl", "rust_library")

def rust_bindgen_library(name, header, cc_lib, bindgen_flags = []):
    rust_bindgen(
        name = name + "__bindgen",
        header = header,
        cc_lib = cc_lib,
        bindgen_flags = bindgen_flags,
    )
    rust_library(
        name = name,
        srcs = [name + "__bindgen.rs"],
        deps = [cc_lib]
    )

def _rust_bindgen_toolchain(ctx):
    return platform_common.ToolchainInfo(
        bindgen = ctx.executable.bindgen,
        clang = ctx.executable.clang,
        libclang = ctx.attr.libclang,
        libstdcxx = ctx.attr.libstdcxx,
        rustfmt = ctx.executable.rustfmt,
    )

rust_bindgen_toolchain = rule(
    _rust_bindgen_toolchain,
    attrs = {
        "bindgen": attr.label(
            doc = "The location of a `bindgen` executable.",
            executable = True,
            cfg = "host",
        ),
        "clang": attr.label(
            executable = True,
            cfg = "host",
        ),
        "libclang": attr.label(),
        "libstdcxx": attr.label(),
        "rustfmt": attr.label(
            executable = True,
            cfg = "host",
            mandatory = False,
        ),
    },
)

def _rust_bindgen(ctx):
    bt = ctx.toolchains["@io_bazel_rules_rust//bindgen:bindgen_toolchain"]

    bindgen = bt.bindgen
    rustfmt = bt.rustfmt
    clang = bt.clang
    libclang = bt.libclang
    # TODO: This should not need to be explicitly provided, see below TODO.
    libstdcxx = bt.libstdcxx

    cc_toolchain = find_cpp_toolchain(ctx)

    # nb. We can't grab the cc_library`s direct headers, so a header must be provided.
    cc_lib = ctx.attr.cc_lib
    if not hasattr(cc_lib, "cc"):
        fail("{} is not a cc_library".format(cc_lib))
    header = ctx.file.header
    if header not in cc_lib.cc.transitive_headers:
        fail("Header {} is not in {}'s transitive closure of headers.".format(ctx.attr.header, cc_lib))

    # rustfmt is not in the usual place, so bindgen would fail to find it
    bindgen_args = ["--no-rustfmt-bindings"] + ctx.attr.bindgen_flags
    clang_args = []

    output = ctx.outputs.out

    libclang_dir = libclang.cc.libs.to_list()[0].dirname
    include_directories = depset(
        [f.dirname for f in cc_lib.cc.transitive_headers]
    )

    if rustfmt:
        unformatted = ctx.actions.declare_file(output.basename + ".unformatted")
    else:
        unformatted = output

    args = ctx.actions.args()
    args.add_all(bindgen_args)
    args.add(header.path)
    args.add("--output", unformatted.path)
    args.add("--")
    args.add_all(include_directories, before_each="-I")
    args.add_all(clang_args)
    ctx.actions.run(
        executable=bindgen,
        inputs=depset(
            [header],
            transitive=[cc_lib.cc.transitive_headers, libclang.cc.libs, libstdcxx.cc.libs],
        ),
        outputs=[unformatted],
        mnemonic="RustBindgen",
        progress_message="Generating bindings for {}..".format(header.path),
        env={
            "RUST_BACKTRACE": "1",
            "CLANG_PATH": clang.path,
            # Bindgen loads libclang at runtime, which also needs libstdc++, so we setup LD_LIBRARY_PATH
            "LIBCLANG_PATH": libclang_dir,
            # TODO: If libclang were built by bazel w/ properly specified dependencies, it
            #       would have the correct rpaths and not require this nor would this rule
            #       have a direct dependency on libstdc++.so
            "LD_LIBRARY_PATH": ":".join([f.dirname for f in libstdcxx.cc.libs]),
        },
        arguments=[args],
        tools=[clang],
    )

    if rustfmt:
        ctx.actions.run_shell(
            inputs=depset([rustfmt, unformatted]),
            outputs=[output],
            command="{} --emit stdout --quiet {} > {}".format(rustfmt.path, unformatted.path, output.path),
            tools=[rustfmt],
        )

rust_bindgen = rule(
    _rust_bindgen,
    attrs = {
        "header": attr.label(allow_single_file = True),
        "cc_lib": attr.label(),
        # An instance of cc_toolchain, used to find the standard library headers.
        "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
        "libstdcxx": attr.label(),
        "bindgen_flags": attr.string_list(),
    },
    fragments = ["cpp"],
    outputs = {"out": "%{name}.rs"},
    toolchains = [
        "@io_bazel_rules_rust//rust:toolchain",
        "@io_bazel_rules_rust//bindgen:bindgen_toolchain",
    ],
)

"""
Generates a rust file from a cc_library and one of it's headers.

TODO: Update docs for configuring toolchain.

and then use it as follows:

```python
load("@io_bazel_rules_rust//bindgen:bindgen.bzl", "rust_bindgen_library")

rust_bindgen_library(
    name = "example_ffi",
    cc_lib = "//example:lib",
    header = "//example:api.h",
)
```
"""
