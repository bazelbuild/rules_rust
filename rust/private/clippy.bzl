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
    root = crate_root_src(ctx.rule.attr, srcs = rust_srcs)
    crate_info = target[CrateInfo]

    dep_info, build_info = collect_deps(
        ctx.label,
        crate_info.deps,
        crate_info.proc_macro_deps,
        crate_info.aliases,
        toolchain,
    )

    compile_inputs, out_dir = collect_inputs(
        ctx,
        ctx.rule.file,
        ctx.rule.files,
        toolchain,
        crate_info,
        dep_info,
        build_info
    )

    args, env = construct_arguments(
        ctx,
        ctx.rule.file,
        toolchain,
        crate_info,
        dep_info,
        output_hash = repr(hash(root.path)),
        rust_flags = [])

    # A marker file indicating clippy has executed successfully.
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

# Example: Run the clippy checker on all targets in the codebase.
#   bazel build --aspects=@io_bazel_rules_rust//rust:rust.bzl%rust_clippy_aspect \
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
    doc = """
Executes the clippy checker on specified targets.

This aspect applies to existing rust_library, rust_test, and rust_binary rules.

As an example, if the following is defined in `hello_lib/BUILD`:

```python
package(default_visibility = ["//visibility:public"])

load("@io_bazel_rules_rust//rust:rust.bzl", "rust_library", "rust_test")

rust_library(
    name = "hello_lib",
    srcs = ["src/lib.rs"],
)

rust_test(
    name = "greeting_test",
    srcs = ["tests/greeting.rs"],
    deps = [":hello_lib"],
)
```

Then the targets can be analyzed with clippy using the following command:

$ bazel build --aspects=@io_bazel_rules_rust//rust:rust.bzl%rust_clippy_aspect \
              --output_groups=clippy_checks //hello_lib:all
""",

)

def _rust_clippy_rule_impl(ctx):
    files = depset([], transitive = [dep[OutputGroupInfo].clippy_checks for dep in ctx.attr.deps])
    return [DefaultInfo(files = files)]

rust_clippy = rule(
    implementation = _rust_clippy_rule_impl,
    attrs = {
        'deps': attr.label_list(aspects = [rust_clippy_aspect]),
    },
    doc = """
Executes the clippy checker on a specific target.

Similar to `rust_clippy_aspect`, but allows specifying a list of dependencies
within the build system.

For example, given the following example targets:

```python
package(default_visibility = ["//visibility:public"])

load("@io_bazel_rules_rust//rust:rust.bzl", "rust_library", "rust_test")

rust_library(
    name = "hello_lib",
    srcs = ["src/lib.rs"],
)

rust_test(
    name = "greeting_test",
    srcs = ["tests/greeting.rs"],
    deps = [":hello_lib"],
)
```

Rust clippy can be set as a build target with the following:

```python
rust_clippy(
    name = "hello_library_clippy",
    testonly = True,
    deps = [
        ":hello_lib",
        ":greeting_test",
    ],
)
```
""",
)
