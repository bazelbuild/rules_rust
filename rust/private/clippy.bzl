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

"""A module defining clippy rules"""

load("//rust/private:common.bzl", "rust_common")
load(
    "//rust/private:rustc.bzl",
    "collect_deps",
    "collect_inputs",
    "construct_arguments",
)
load("//rust/private:utils.bzl", "determine_output_hash", "find_cc_toolchain", "find_toolchain")

def _clippy_aspect_impl(target, ctx):
    if rust_common.crate_info not in target:
        return []

    toolchain = find_toolchain(ctx)
    cc_toolchain, feature_configuration = find_cc_toolchain(ctx)
    crate_info = target[rust_common.crate_info]
    crate_type = crate_info.type

    dep_info, build_info = collect_deps(
        label = ctx.label,
        deps = crate_info.deps,
        proc_macro_deps = crate_info.proc_macro_deps,
        aliases = crate_info.aliases,
    )

    compile_inputs, out_dir, build_env_files, build_flags_files = collect_inputs(
        ctx,
        ctx.rule.file,
        ctx.rule.files,
        toolchain,
        cc_toolchain,
        crate_info,
        dep_info,
        build_info,
    )

    # A marker file indicating clippy has executed successfully.
    # This file is necessary because "ctx.actions.run" mandates an output.
    clippy_marker = ctx.actions.declare_file(ctx.label.name + ".clippy.ok")

    args, env = construct_arguments(
        ctx,
        ctx.rule.attr,
        ctx.file,
        toolchain,
        toolchain.clippy_driver.path,
        cc_toolchain,
        feature_configuration,
        crate_type,
        crate_info,
        dep_info,
        output_hash = determine_output_hash(crate_info.root),
        rust_flags = [],
        out_dir = out_dir,
        build_env_files = build_env_files,
        build_flags_files = build_flags_files,
        maker_path = clippy_marker.path,
        emit = ["dep-info", "metadata"],
    )

    # Turn any warnings from clippy or rustc into an error, as otherwise
    # Bazel will consider the execution result of the aspect to be "success",
    # and Clippy won't be re-triggered unless the source file is modified.
    if "__bindgen" in ctx.rule.attr.tags:
        # bindgen-generated content is likely to trigger warnings, so
        # only fail on clippy warnings
        args.add("-Dclippy::style")
        args.add("-Dclippy::correctness")
        args.add("-Dclippy::complexity")
        args.add("-Dclippy::perf")
    else:
        # fail on any warning
        args.add("-Dwarnings")

    if crate_info.is_test:
        args.add("--test")

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
#   bazel build --aspects=@rules_rust//rust:defs.bzl%rust_clippy_aspect \
#               --output_groups=clippy_checks \
#               //...
rust_clippy_aspect = aspect(
    fragments = ["cpp"],
    host_fragments = ["cpp"],
    attrs = {
        "_cc_toolchain": attr.label(
            doc = (
                "Required attribute to access the cc_toolchain. See [Accessing the C++ toolchain]" +
                "(https://docs.bazel.build/versions/master/integrating-with-rules-cc.html#accessing-the-c-toolchain)"
            ),
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
        "_error_format": attr.label(
            doc = "The desired `--error-format` flags for clippy",
            default = "//:error_format",
        ),
        "_process_wrapper": attr.label(
            doc = "A process wrapper for running clippy on all platforms",
            default = Label("//util/process_wrapper"),
            executable = True,
            cfg = "exec",
        ),
    },
    toolchains = [
        str(Label("//rust:toolchain")),
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    incompatible_use_toolchain_transition = True,
    implementation = _clippy_aspect_impl,
    doc = """\
Executes the clippy checker on specified targets.

This aspect applies to existing rust_library, rust_test, and rust_binary rules.

As an example, if the following is defined in `examples/hello_lib/BUILD.bazel`:

```python
load("@rules_rust//rust:defs.bzl", "rust_library", "rust_test")

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
$ bazel build --aspects=@rules_rust//rust:defs.bzl%rust_clippy_aspect \
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
        "deps": attr.label_list(
            doc = "Rust targets to run clippy on.",
            providers = [rust_common.crate_info],
            aspects = [rust_clippy_aspect],
        ),
    },
    doc = """\
Executes the clippy checker on a specific target.

Similar to `rust_clippy_aspect`, but allows specifying a list of dependencies \
within the build system.

For example, given the following example targets:

```python
load("@rules_rust//rust:defs.bzl", "rust_library", "rust_test")

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
load("@rules_rust//rust:defs.bzl", "rust_clippy")

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
