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

load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("//rust/private:common.bzl", "rust_common")
load("//rust/private:providers.bzl", "CrateInfo")
load("//rust/private:rustdoc.bzl", "rustdoc_compile_action")
load("//rust/private:utils.bzl", "dedent", "filter_deps", "find_toolchain", "transform_deps")

def _rust_doc_test_impl(ctx):
    """The implementation for the `rust_doc_test` rule

    Args:
        ctx (ctx): The rule's context object

    Returns:
        list: A list containing a DefaultInfo provider
    """

    toolchain = find_toolchain(ctx)

    crate = ctx.attr.crate[rust_common.crate_info]

    deps, proc_macro_deps = filter_deps(ctx)
    deps = transform_deps(deps)
    proc_macro_deps = transform_deps(proc_macro_deps)

    crate_info = rust_common.create_crate_info(
        name = crate.name,
        type = crate.type,
        root = crate.root,
        srcs = crate.srcs,
        deps = depset(deps, transitive = [crate.deps]),
        proc_macro_deps = depset(proc_macro_deps, transitive = [crate.proc_macro_deps]),
        aliases = crate.aliases,
        output = crate.output,
        edition = crate.edition,
        rustc_env = crate.rustc_env,
        rustc_env_files = crate.rustc_env_files,
        is_test = True,
        compile_data = crate.compile_data,
        compile_data_targets = crate.compile_data_targets,
        wrapped_crate_type = crate.type,
        owner = ctx.label,
    )

    test_runner_name = ctx.label.name
    if ctx.executable._test_runner.extension:
        test_runner_name += "." + ctx.executable._test_runner.extension

    test_runner = ctx.actions.declare_file(test_runner_name)
    stdout_file = ctx.actions.declare_file(test_runner.basename + ".rustdoc_test.stdout", sibling = test_runner)
    stderr_file = ctx.actions.declare_file(test_runner.basename + ".rustdoc_test.stderr", sibling = test_runner)
    exit_code_file = ctx.actions.declare_file(test_runner.basename + ".rustdoc_test.exit_code", sibling = test_runner)

    # Add the current crate as an extern for the compile action
    rustdoc_flags = [
        "--extern",
        "{}={}".format(crate_info.name, crate_info.output.path),
        "--test",
    ]

    rustdoc_flags.extend(ctx.attr.rustdoc_flags)

    action = rustdoc_compile_action(
        ctx = ctx,
        toolchain = toolchain,
        crate_info = crate_info,
        rustdoc_flags = rustdoc_flags,
        is_test = True,
    )

    action.process_wrapper_flags.add("--stdout-file", stdout_file)
    action.process_wrapper_flags.add("--stderr-file", stderr_file)
    action.process_wrapper_flags.add("--captured-exit-code-file", exit_code_file)

    ctx.actions.run(
        mnemonic = "RustdocTest",
        progress_message = "Running Rustdoc test for %{label}",
        executable = action.executable,
        inputs = action.inputs,
        tools = action.tools,
        arguments = action.arguments,
        env = action.env,
        outputs = [stdout_file, stderr_file, exit_code_file],
        toolchain = Label("//rust:toolchain_type"),
    )

    ctx.actions.symlink(
        output = test_runner,
        target_file = ctx.executable._test_runner,
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [stdout_file, stderr_file, exit_code_file])
    runfiles = runfiles.merge(ctx.attr._test_runner[DefaultInfo].default_runfiles)

    return [DefaultInfo(
        files = depset([test_runner]),
        runfiles = runfiles,
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
        "crate_features": attr.string_list(
            doc = dedent("""\
                List of features to enable for the crate being documented.
            """),
        ),
        "deps": attr.label_list(
            doc = dedent("""\
                List of other libraries to be linked to this library target.

                These can be either other `rust_library` targets or `cc_library` targets if
                linking a native library.
            """),
            providers = [[CrateInfo], [CcInfo]],
        ),
        "proc_macro_deps": attr.label_list(
            doc = dedent("""\
                List of `rust_proc_macro` targets used to help build this library target.
            """),
            cfg = "exec",
            providers = [rust_common.crate_info],
        ),
        "rustdoc_flags": attr.string_list(
            doc = dedent("""\
                List of flags passed to `rustdoc`.

                These strings are subject to Make variable expansion for predefined
                source/output path variables like `$location`, `$execpath`, and
                `$rootpath`. This expansion is useful if you wish to pass a generated
                file of arguments to rustc: `@$(location //package:target)`.
            """),
        ),
        "_test_runner": attr.label(
            doc = "A binary used for replaying rustdoc test build action results.",
            cfg = "exec",
            default = Label("//rust/private/rustdoc:rustdoc_test_runner"),
            executable = True,
        ),
    },
    test = True,
    fragments = ["cpp"],
    toolchains = [
        str(Label("//rust:toolchain_type")),
        config_common.toolchain_type("@bazel_tools//tools/cpp:toolchain_type", mandatory = False),
    ],
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
