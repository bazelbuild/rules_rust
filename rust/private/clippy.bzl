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
    "get_cc_toolchain",
)
load(
    "@io_bazel_rules_rust//rust:private/rust.bzl",
    "crate_root_src",
)
load("@io_bazel_rules_rust//rust:private/utils.bzl", "determine_output_hash", "find_toolchain")

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

    compile_inputs, out_dir, build_env_file, build_flags_files = collect_inputs(
        ctx,
        ctx.rule.file,
        ctx.rule.files,
        toolchain,
        crate_info,
        dep_info,
        build_info,
    )

    # A marker file indicating clippy has executed successfully.
    # This file is necessary because "ctx.actions.run" mandates an output.
    clippy_marker = ctx.actions.declare_file(ctx.label.name + "_clippy.ok")

    cc_toolchain, feature_configuration = get_cc_toolchain(ctx)

    args, env = construct_arguments(
        ctx,
        ctx.file,
        toolchain,
        toolchain.clippy_driver.path,
        cc_toolchain,
        feature_configuration,
        crate_info,
        dep_info,
        output_hash = determine_output_hash(root),
        rust_flags = [],
        out_dir = out_dir,
        build_env_file = build_env_file,
        build_flags_files = build_flags_files,
        maker_path = clippy_marker.path,
    )

    # Deny the default-on clippy warning levels.
    #
    # If these are left as warnings, then Bazel will consider the execution
    # result of the aspect to be "success", and Clippy won't be re-triggered
    # unless the source file is modified.
    args.add("-Dclippy::style")
    args.add("-Dclippy::correctness")
    args.add("-Dclippy::complexity")
    args.add("-Dclippy::perf")

    ctx.actions.run(
        executable = ctx.executable._process_wrapper,
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
        "_process_wrapper": attr.label(
            default = "@io_bazel_rules_rust//util/process_wrapper",
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),
    },
    toolchains = [
        "@io_bazel_rules_rust//rust:toolchain",
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    implementation = _clippy_aspect_impl,
    doc = """\
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

```output
$ bazel build --aspects=@io_bazel_rules_rust//rust:rust.bzl%rust_clippy_aspect \
              --output_groups=clippy_checks //hello_lib:all
```
""",
)

def _rust_clippy_rule_impl(ctx):
    files = depset([], transitive = [dep[OutputGroupInfo].clippy_checks for dep in ctx.attr.deps])
    return [DefaultInfo(files = files)]

rust_clippy = rule(
    implementation = _rust_clippy_rule_impl,
    attrs = {
        "deps": attr.label_list(aspects = [rust_clippy_aspect]),
    },
    doc = """\
Executes the clippy checker on a specific target.

Similar to `rust_clippy_aspect`, but allows specifying a list of dependencies \
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
