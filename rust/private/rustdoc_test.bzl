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

"""Rules for performing `rustdoc --test` on Bazel built crates"""

load("//rust/private:common.bzl", "rust_common")
load("//rust/private:providers.bzl", "CrateInfo")
load("//rust/private:rustdoc.bzl", "rustdoc_compile_action")
load("//rust/private:utils.bzl", "dedent", "find_toolchain", "transform_deps")

def _construct_writer_arguments(ctx, test_runner, action, crate_info):
    """Construct arguments and environment variables specific to `rustdoc_test_writer`.

    This is largely solving for the fact that tests run from a runfiles directory
    where actions run in an execroot. But it also tracks what environment variables
    were explicitly added to the action.

    Args:
        ctx (ctx): The rule's context object.
        test_runner (File): The test_runner output file declared by `rustdoc_test`.
        action (struct): Action arguments generated by `rustdoc_compile_action`.
        crate_info (CrateInfo): The provider of the crate who's docs are being tested.

    Returns:
        tuple: A tuple of `rustdoc_test_writer` specific inputs
            - Args: Arguments for the test writer
            - dict: Required environment variables
    """

    writer_args = ctx.actions.args()

    # Track the output path where the test writer should write the test
    writer_args.add("--output={}".format(test_runner.path))

    # Track what environment variables should be written to the test runner
    writer_args.add("--action_env=DEVELOPER_DIR")
    writer_args.add("--action_env=PATHEXT")
    writer_args.add("--action_env=SDKROOT")
    writer_args.add("--action_env=SYSROOT")
    for var in action.env.keys():
        writer_args.add("--action_env={}".format(var))

    # Since the test runner will be running from a runfiles directory, the
    # paths originally generated for the build action will not map to any
    # files. To ensure rustdoc can find the appropriate dependencies, the
    # file roots are identified and tracked for each dependency so it can be
    # stripped from the test runner.
    for dep in crate_info.deps.to_list():
        dep_crate_info = getattr(dep, "crate_info", None)
        dep_dep_info = getattr(dep, "dep_info", None)
        if dep_crate_info:
            root = dep_crate_info.output.root.path
            writer_args.add("--strip_substring={}/".format(root))
        if dep_dep_info:
            for direct_dep in dep_dep_info.direct_crates.to_list():
                root = direct_dep.dep.output.root.path
                writer_args.add("--strip_substring={}/".format(root))
            for transitive_dep in dep_dep_info.transitive_crates.to_list():
                root = transitive_dep.output.root.path
                writer_args.add("--strip_substring={}/".format(root))

    # Indicate that the rustdoc_test args are over.
    writer_args.add("--")

    # Prepare for the process runner to ingest the rest of the arguments
    # to match the expectations of `rustc_compile_action`.
    writer_args.add(ctx.executable._process_wrapper.short_path)

    return (writer_args, action.env)

def _rust_doc_test_impl(ctx):
    """The implementation for the `rust_doc_test` rule

    Args:
        ctx (ctx): The rule's context object

    Returns:
        list: A list containing a DefaultInfo provider
    """

    toolchain = find_toolchain(ctx)

    crate = ctx.attr.crate[rust_common.crate_info]
    deps = transform_deps(ctx.attr.deps)

    crate_info = rust_common.create_crate_info(
        name = crate.name,
        type = crate.type,
        root = crate.root,
        srcs = crate.srcs,
        deps = depset(deps, transitive = [crate.deps]),
        proc_macro_deps = crate.proc_macro_deps,
        aliases = {},
        output = crate.output,
        edition = crate.edition,
        rustc_env = crate.rustc_env,
        rustc_env_files = crate.rustc_env_files,
        is_test = True,
        compile_data = crate.compile_data,
        wrapped_crate_type = crate.type,
        owner = ctx.label,
    )

    if toolchain.os == "windows":
        test_runner = ctx.actions.declare_file(ctx.label.name + ".rustdoc_test.bat")
    else:
        test_runner = ctx.actions.declare_file(ctx.label.name + ".rustdoc_test.sh")

    # Add the current crate as an extern for the compile action
    rustdoc_flags = [
        "--extern",
        "{}={}".format(crate_info.name, crate_info.output.short_path),
        "--test",
    ]

    action = rustdoc_compile_action(
        ctx = ctx,
        toolchain = toolchain,
        crate_info = crate_info,
        rustdoc_flags = rustdoc_flags,
        is_test = True,
    )

    tools = action.tools + [ctx.executable._process_wrapper]

    writer_args, env = _construct_writer_arguments(
        ctx = ctx,
        test_runner = test_runner,
        action = action,
        crate_info = crate_info,
    )

    # Allow writer environment variables to override those from the action.
    action.env.update(env)

    ctx.actions.run(
        mnemonic = "RustdocTestWriter",
        progress_message = "Generating Rustdoc test runner for {}".format(ctx.attr.crate.label),
        executable = ctx.executable._test_writer,
        inputs = action.inputs,
        tools = tools,
        arguments = [writer_args] + action.arguments,
        env = action.env,
        outputs = [test_runner],
    )

    return [DefaultInfo(
        files = depset([test_runner]),
        runfiles = ctx.runfiles(files = tools, transitive_files = action.inputs),
        executable = test_runner,
    )]

rust_doc_test = rule(
    implementation = _rust_doc_test_impl,
    attrs = {
        "crate": attr.label(
            doc = (
                "The label of the target to generate code documentation for. " +
                "`rust_doc_test` can generate HTML code documentation for the " +
                "source files of `rust_library` or `rust_binary` targets."
            ),
            providers = [rust_common.crate_info],
            mandatory = True,
        ),
        "deps": attr.label_list(
            doc = dedent("""\
                List of other libraries to be linked to this library target.

                These can be either other `rust_library` targets or `cc_library` targets if
                linking a native library.
            """),
            providers = [CrateInfo, CcInfo],
        ),
        "_cc_toolchain": attr.label(
            doc = (
                "In order to use find_cc_toolchain, your rule has to depend " +
                "on C++ toolchain. See @rules_cc//cc:find_cc_toolchain.bzl " +
                "docs for details."
            ),
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
        "_process_wrapper": attr.label(
            doc = "A process wrapper for running rustdoc on all platforms",
            cfg = "exec",
            default = Label("//util/process_wrapper"),
            executable = True,
        ),
        "_test_writer": attr.label(
            doc = "A binary used for writing script for use as the test executable.",
            cfg = "exec",
            default = Label("//tools/rustdoc:rustdoc_test_writer"),
            executable = True,
        ),
    },
    test = True,
    fragments = ["cpp"],
    host_fragments = ["cpp"],
    toolchains = [
        str(Label("//rust:toolchain")),
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    incompatible_use_toolchain_transition = True,
    doc = dedent("""\
        Runs Rust documentation tests.

        Example:

        Suppose you have the following directory structure for a Rust library crate:

        ```output
        [workspace]/
        WORKSPACE
        hello_lib/
            BUILD
            src/
                lib.rs
        ```

        To run [documentation tests][doc-test] for the `hello_lib` crate, define a `rust_doc_test` \
        target that depends on the `hello_lib` `rust_library` target:

        [doc-test]: https://doc.rust-lang.org/book/documentation.html#documentation-as-tests

        ```python
        package(default_visibility = ["//visibility:public"])

        load("@rules_rust//rust:defs.bzl", "rust_library", "rust_doc_test")

        rust_library(
            name = "hello_lib",
            srcs = ["src/lib.rs"],
        )

        rust_doc_test(
            name = "hello_lib_doc_test",
            crate = ":hello_lib",
        )
        ```

        Running `bazel test //hello_lib:hello_lib_doc_test` will run all documentation tests for the `hello_lib` library crate.
    """),
)
