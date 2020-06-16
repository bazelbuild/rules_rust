# Copyright 2020 The Bazel Authors. All rights reserved.
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

load(
    "@io_bazel_rules_rust//rust:private/rustc.bzl",
    "CrateInfo",
    "collect_deps",
    "collect_inputs",
    "construct_arguments",
    "construct_compile_command",
)
load(
    "@io_bazel_rules_rust//rust:private/rust.bzl",
    "crate_root_src",
    "get_edition"
)
load("@io_bazel_rules_rust//rust:private/utils.bzl", "find_toolchain")

_rust_extensions = [
    "rs",
]

def _is_rust_target(srcs):
    return any([src.extension in _rust_extensions for src in srcs])

def _rust_sources(target, rule):
    srcs = []
    if "srcs" in dir(rule.attr):
        srcs += [f for src in rule.attr.srcs for f in src.files.to_list()]
    if "hdrs" in dir(rule.attr):
        srcs += [f for hdr in rule.attr.hdrs for f in hdr.files.to_list()]
    return [src for src in srcs if src.extension in _rust_extensions]

def _clippy_aspect_impl(target, ctx):
    if CrateInfo not in target:
        return []
    rust_srcs = _rust_sources(target, ctx.rule)
    if rust_srcs == []:
        return []

    toolchain = find_toolchain(ctx)
    crate_name = ctx.label.name.replace("-", "_")
    crate_type = getattr(ctx.rule.attr, "crate_type") if hasattr(ctx.rule.attr, "crate_type") else "lib"
    crate_info = CrateInfo(
        name = crate_name,
        type = crate_type,
        root = crate_root_src(ctx, srcs = rust_srcs),
        srcs = rust_srcs,
        deps = ctx.rule.attr.deps,
        proc_macro_deps = ctx.rule.attr.proc_macro_deps,
        aliases = ctx.rule.attr.aliases,
        output = None,
        edition = get_edition(ctx.rule.attr, toolchain),
        rustc_env = ctx.rule.attr.rustc_env,
    )

    dep_info, build_info = collect_deps(
        ctx.label,
        crate_info.deps,
        crate_info.proc_macro_deps,
        crate_info.aliases,
        toolchain,
    )

    compile_inputs, out_dir = collect_inputs(
        ctx,
        toolchain,
        crate_info,
        dep_info,
        build_info
    )

    args, env = construct_arguments(
        ctx,
        toolchain,
        crate_info,
        dep_info,
        output_hash = None,
        rust_flags = [])

    # A marker file indicating clang tidy has executed successfully.
    # This file is necessary because "ctx.actions.run" mandates an output.
    clippy_marker = ctx.actions.declare_file(ctx.label.name + "_clippy.ok")

    command = construct_compile_command(
        ctx,
        toolchain.clippy_driver.path,
        toolchain,
        crate_info,
        build_info,
        out_dir,
    ) + (" && touch %s" % clippy_marker.path)

    # Deny the default-on clippy warning levels.
    #
    # If these are left as warnings, then Bazel will consider the execution
    # result of the aspect to be "success", and Clippy won't be re-triggered
    # unless the source file is modified.
    args.add("-Dclippy::style")
    args.add("-Dclippy::correctness");
    args.add("-Dclippy::complexity");
    args.add("-Dclippy::perf");

    ctx.actions.run_shell(
        command = command,
        inputs = compile_inputs,
        outputs = [clippy_marker],
        env = env,
        tools = [toolchain.clippy_driver],
        arguments = [args],
        mnemonic = "Clippy",
    )

    return [
        OutputGroupInfo(clippy_checks = depset([clippy_marker])),
    ]

# Executes a "compile command" on all specified targets.
#
# Example: Run the clang-tidy checker on all targets in the codebase.
#   bazel build --aspects=@rules_rust//rust:clippy.bzl%rust_clippy_aspect \
#               --output_groups=clippy_checks \
#               //...
rust_clippy_aspect = aspect(
    fragments = ["cpp"],
    host_fragments = ["cpp"],
    attrs = {
        "_cc_toolchain": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
    },
    toolchains = [
        "@io_bazel_rules_rust//rust:toolchain",
        "@bazel_tools//tools/cpp:toolchain_type"
    ],
    implementation = _clippy_aspect_impl,
)

def _rust_clippy_rule_impl(ctx):
    files = depset([], transitive = [dep[OutputGroupInfo].clippy_checks for dep in ctx.attr.deps])
    return [DefaultInfo(files = files)]

rust_clippy = rule(
    implementation = _rust_clippy_rule_impl,
    attrs = {
        'deps': attr.label_list(aspects = [rust_clippy_aspect]),
    },
)
