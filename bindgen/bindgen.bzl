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

"""Rust Bindgen rules"""

load("//rust:defs.bzl", "rust_library")

# buildifier: disable=bzl-visibility
load("//rust/private:rustc.bzl", "get_linker_and_args")

# buildifier: disable=bzl-visibility
load("//rust/private:utils.bzl", "find_cc_toolchain", "get_preferred_artifact")

# TODO(hlopko): use the more robust logic from rustc.bzl also here, through a reasonable API.
def _get_libs_for_static_executable(dep):
    """find the libraries used for linking a static executable.

    Args:
        dep (Target): A cc_library target.

    Returns:
        depset: A depset[File]
    """
    linker_inputs = dep[CcInfo].linking_context.linker_inputs.to_list()
    return depset([get_preferred_artifact(lib, use_pic = False) for li in linker_inputs for lib in li.libraries])

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

    tags = kwargs.get("tags") or []
    if "tags" in kwargs:
        kwargs.pop("tags")

    deps = kwargs.get("deps") or []
    if "deps" in kwargs:
        kwargs.pop("deps")

    rust_bindgen(
        name = name + "__bindgen",
        header = header,
        cc_lib = cc_lib,
        bindgen_flags = bindgen_flags or [],
        clang_flags = clang_flags or [],
        tags = tags,
    )

    rust_library(
        name = name,
        srcs = [name + "__bindgen.rs"],
        tags = tags + ["__bindgen", "noclippy"],
        deps = deps + [cc_lib],
        **kwargs
    )

def _rust_bindgen_impl(ctx):
    toolchain = ctx.toolchains[Label("//bindgen:toolchain_type")]

    # nb. We can't grab the cc_library`s direct headers, so a header must be provided.
    cc_lib = ctx.attr.cc_lib
    header = ctx.file.header
    cc_header_list = ctx.attr.cc_lib[CcInfo].compilation_context.headers.to_list()
    if header not in cc_header_list:
        fail("Header {} is not in {}'s transitive headers.".format(ctx.attr.header, cc_lib), "header")

    toolchain = ctx.toolchains[Label("//bindgen:toolchain_type")]
    bindgen_bin = toolchain.bindgen
    clang_bin = toolchain.clang
    libclang = toolchain.libclang
    libstdcxx = toolchain.libstdcxx

    output = ctx.outputs.out
    tools = depset([clang_bin])

    # libclang should only have 1 output file
    libclang_dir = _get_libs_for_static_executable(libclang).to_list()[0].dirname
    include_directories = cc_lib[CcInfo].compilation_context.includes.to_list()
    quote_include_directories = cc_lib[CcInfo].compilation_context.quote_includes.to_list()
    system_include_directories = cc_lib[CcInfo].compilation_context.system_includes.to_list()

    env = {
        "CLANG_PATH": clang_bin.path,
        "LIBCLANG_PATH": libclang_dir,
        "RUST_BACKTRACE": "1",
    }

    args = ctx.actions.args()

    # Configure Bindgen Arguments
    args.add_all(ctx.attr.bindgen_flags)
    args.add(header)
    args.add("--output", output)

    # Vanilla usage of bindgen produces formatted output, here we do the same if we have `rustfmt` in our toolchain.
    rustfmt_toolchain = ctx.toolchains[Label("//rust/rustfmt:toolchain_type")]
    if toolchain.default_rustfmt:
        # Bindgen is able to find rustfmt using the RUSTFMT environment variable
        env.update({"RUSTFMT": rustfmt_toolchain.rustfmt.path})
        tools = depset(transitive = [tools, rustfmt_toolchain.all_files])
    else:
        args.add("--no-rustfmt-bindings")

    # Configure Clang Arguments
    args.add("--")
    args.add_all(include_directories, before_each = "-I")
    args.add_all(quote_include_directories, before_each = "-iquote")
    args.add_all(system_include_directories, before_each = "-isystem")
    args.add_all(ctx.attr.clang_flags)

    cc_toolchain, feature_configuration = find_cc_toolchain(ctx)
    _, _, linker_env = get_linker_and_args(ctx, ctx.attr, "bin", cc_toolchain, feature_configuration, None)
    env.update(**linker_env)

    # Allow sysroots configured by the toolchain to be added to Clang arguments.
    if "no-rust-bindgen-cc-sysroot" not in ctx.features:
        if cc_toolchain.sysroot:
            tools = depset(transitive = [tools, cc_toolchain.all_files])
            sysroot_args = ["--sysroot", cc_toolchain.sysroot]
            for arg in ctx.attr.clang_flags:
                if arg.startswith("--sysroot"):
                    sysroot_args = []
                    break
            args.add_all(sysroot_args)

    # Set the dynamic linker search path so that clang uses the libstdcxx from the toolchain.
    # DYLD_LIBRARY_PATH is LD_LIBRARY_PATH on macOS.
    if libstdcxx:
        env["LD_LIBRARY_PATH"] = ":".join([f.dirname for f in _get_libs_for_static_executable(libstdcxx).to_list()])
        env["DYLD_LIBRARY_PATH"] = env["LD_LIBRARY_PATH"]

    ctx.actions.run(
        executable = bindgen_bin,
        inputs = depset(
            [header],
            transitive = [
                cc_lib[CcInfo].compilation_context.headers,
                _get_libs_for_static_executable(libclang),
            ] + ([
                _get_libs_for_static_executable(libstdcxx),
            ] if libstdcxx else []),
        ),
        outputs = [output],
        mnemonic = "RustBindgen",
        progress_message = "Generating bindings for {}..".format(header.path),
        env = env,
        arguments = [args],
        tools = tools,
    )

rust_bindgen = rule(
    doc = "Generates a rust source file from a cc_library and a header.",
    implementation = _rust_bindgen_impl,
    attrs = {
        "bindgen_flags": attr.string_list(
            doc = "Flags to pass directly to the bindgen executable. See https://rust-lang.github.io/rust-bindgen/ for details.",
        ),
        "cc_lib": attr.label(
            doc = "The cc_library that contains the `.h` file. This is used to find the transitive includes.",
            providers = [CcInfo],
        ),
        "clang_flags": attr.string_list(
            doc = "Flags to pass directly to the clang executable.",
        ),
        "header": attr.label(
            doc = "The `.h` file to generate bindings for.",
            allow_single_file = True,
        ),
        "_cc_toolchain": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
        "_process_wrapper": attr.label(
            default = Label("//util/process_wrapper"),
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),
    },
    outputs = {"out": "%{name}.rs"},
    fragments = ["cpp"],
    toolchains = [
        str(Label("//bindgen:toolchain_type")),
        str(Label("//rust:toolchain_type")),
        str(Label("//rust/rustfmt:toolchain_type")),
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    incompatible_use_toolchain_transition = True,
)

def _rust_bindgen_toolchain_impl(ctx):
    return platform_common.ToolchainInfo(
        bindgen = ctx.executable.bindgen,
        clang = ctx.executable.clang,
        libclang = ctx.attr.libclang,
        libstdcxx = ctx.attr.libstdcxx,
        default_rustfmt = ctx.attr.default_rustfmt,
    )

rust_bindgen_toolchain = rule(
    _rust_bindgen_toolchain_impl,
    doc = """\
The tools required for the `rust_bindgen` rule.

This rule depends on the [`bindgen`](https://crates.io/crates/bindgen) binary crate, and it 
in turn depends on both a clang binary and the clang library. To obtain these dependencies,
`rust_bindgen_dependencies` imports bindgen and its dependencies.

```python
load("@rules_rust//bindgen:bindgen.bzl", "rust_bindgen_toolchain")

rust_bindgen_toolchain(
    name = "bindgen_toolchain_impl",
    bindgen = "//my/rust:bindgen",
    clang = "//my/clang:clang",
    libclang = "//my/clang:libclang.so",
    libstdcxx = "//my/cpp:libstdc++",
)

toolchain(
    name = "bindgen_toolchain",
    toolchain = "bindgen_toolchain_impl",
    toolchain_type = "@rules_rust//bindgen:toolchain_type",
)
```

This toolchain will then need to be registered in the current `WORKSPACE`.
For additional information, see the [Bazel toolchains documentation](https://docs.bazel.build/versions/master/toolchains.html).
""",
    attrs = {
        "bindgen": attr.label(
            doc = "The label of a `bindgen` executable.",
            executable = True,
            cfg = "exec",
        ),
        "clang": attr.label(
            doc = "The label of a `clang` executable.",
            executable = True,
            cfg = "exec",
        ),
        "default_rustfmt": attr.bool(
            doc = "If set, `rust_bindgen` targets will always format generated sources with `rustfmt`.",
            mandatory = False,
            default = True,
        ),
        "libclang": attr.label(
            doc = "A cc_library that provides bindgen's runtime dependency on libclang.",
            cfg = "exec",
            providers = [CcInfo],
        ),
        "libstdcxx": attr.label(
            doc = "A cc_library that satisfies libclang's libstdc++ dependency. This is used to make the execution of clang hermetic. If None, system libraries will be used instead.",
            cfg = "exec",
            providers = [CcInfo],
            mandatory = False,
        ),
    },
)
