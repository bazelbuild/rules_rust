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

# buildifier: disable=module-docstring
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "C_COMPILE_ACTION_NAME")
load("//rust/private:common.bzl", "rust_common")
load("//rust/private:toolchain_utils.bzl", "find_sysroot")
load("//rust/private:utils.bzl", "find_cc_toolchain", "find_toolchain", "get_lib_name", "get_preferred_artifact")
load("//util/launcher:launcher.bzl", "create_launcher")

def get_cc_compile_env(cc_toolchain, feature_configuration):
    """Gather cc environment variables from the given `cc_toolchain`

    Args:
        cc_toolchain (cc_toolchain): The current rule's `cc_toolchain`.
        feature_configuration (FeatureConfiguration): Class used to construct command lines from CROSSTOOL features.

    Returns:
        dict: Returns environment variables to be set for given action.
    """
    compile_variables = cc_common.create_compile_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
    )
    return cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = C_COMPILE_ACTION_NAME,
        variables = compile_variables,
    )

def _rust_doc_test_impl(ctx):
    """The implementation for the `rust_doc_test` rule

    Args:
        ctx (ctx): The rule's context object

    Returns:
        list: A list containing a DefaultInfo provider
    """
    if ctx.attr.crate and ctx.attr.dep:
        fail("{} should only use the `crate` attribute. `dep` is deprecated".format(
            ctx.label,
        ))

    crate = ctx.attr.crate or ctx.attr.dep
    if not crate:
        fail("{} is missing the `crate` attribute".format(ctx.label))

    toolchain = find_toolchain(ctx)

    crate_info = crate[rust_common.crate_info]
    dep_info = crate[rust_common.dep_info]

    # Construct rustdoc test command, which will be written to a shell script
    # to be executed to run the test.
    flags, env, toolchain_tools = _build_rustdoc_flags(ctx, dep_info, crate_info, toolchain)

    # The test script compiles the crate and runs it, so it needs both compile and runtime inputs.
    compile_inputs = depset(
        [crate_info.output] +
        [toolchain.rust_doc] +
        [toolchain.rustc] +
        toolchain.crosstool_files,
        transitive = [
            crate_info.srcs,
            dep_info.transitive_libs,
            toolchain.rustc_lib.files,
            toolchain.rust_lib.files,
        ] + toolchain_tools,
    )

    rustdoc = ctx.actions.declare_file(ctx.label.name + toolchain.binary_ext)
    ctx.actions.symlink(
        output = rustdoc,
        target_file = toolchain.rust_doc,
        is_executable = True,
    )

    return create_launcher(
        ctx = ctx,
        args = [
            "--test",
            crate_info.root.path,
            "--crate-name={}".format(crate_info.name),
        ] + flags,
        env = env,
        toolchain = toolchain,
        providers = [DefaultInfo(
            files = toolchain.rustc_lib.files,
            runfiles = ctx.runfiles(transitive_files = compile_inputs),
        )],
        executable = rustdoc,
    )

# TODO: Replace with bazel-skylib's `path.dirname`. This requires addressing some dependency issues or
# generating docs will break.
def _dirname(path_str):
    """Returns the path of the direcotry from a unix path.

    Args:
        path_str (str): A string representing a unix path

    Returns:
        str: The parsed directory name of the provided path
    """
    return "/".join(path_str.split("/")[:-1])

def _build_rustdoc_flags(ctx, dep_info, crate_info, toolchain):
    """Constructs the rustdoc script used to test `crate`.

    Args:
        ctx (ctx): The rule's context object.
        dep_info (DepInfo): The DepInfo provider
        crate_info (CrateInfo): The CrateInfo provider
        toolchain (rust_toolchain): The curret `rust_toolchain`.

    Returns:
        list: A list of rustdoc flags (str)
    """

    d = dep_info

    # nb. Paths must be constructed wrt runfiles, so we construct relative link flags for doctest.
    link_flags = []
    link_search_flags = []

    link_flags.append("--extern=" + crate_info.name + "=" + crate_info.output.short_path)
    link_flags += ["--extern=" + c.name + "=" + c.dep.output.short_path for c in d.direct_crates.to_list()]
    link_search_flags += ["-Ldependency={}".format(_dirname(c.output.short_path)) for c in d.transitive_crates.to_list()]

    sysroot = find_sysroot(toolchain, short_path = True)
    if sysroot:
        link_search_flags.append("--sysroot=${{pwd}}/{}".format(sysroot))
    link_search_flags.append("--target={}".format(toolchain.target_flag_value))

    # TODO(hlopko): use the more robust logic from rustc.bzl also here, through a reasonable API.
    for lib_to_link in dep_info.transitive_noncrates.to_list():
        is_static = bool(lib_to_link.static_library or lib_to_link.pic_static_library)
        f = get_preferred_artifact(lib_to_link)
        if not is_static:
            link_flags.append("-ldylib=" + get_lib_name(f))
        else:
            link_flags.append("-lstatic=" + get_lib_name(f))
        link_flags.append("-Lnative={}".format(_dirname(f.short_path)))
        link_search_flags.append("-Lnative={}".format(_dirname(f.short_path)))

    if crate_info.type == "proc-macro":
        link_flags.extend(["--extern", "proc_macro"])

    edition_flags = ["--edition={}".format(crate_info.edition)] if crate_info.edition != "2015" else []

    flags = link_search_flags + link_flags + edition_flags

    # Build a set of environment variables to use for the test
    env = {}
    toolchain_tools = []
    cc_toolchain, feature_configuration = find_cc_toolchain(ctx)
    cc_env = get_cc_compile_env(cc_toolchain, feature_configuration)

    # MSVC requires INCLUDE to be set
    include = cc_env.get("INCLUDE")
    if include:
        env["INCLUDE"] = include

    if cc_toolchain:
        toolchain_tools.append(cc_toolchain.all_files)

        cc_executable = cc_toolchain.compiler_executable
        if cc_executable:
            env["CC"] = cc_executable
        ar_executable = cc_toolchain.ar_executable
        if ar_executable:
            # The default MacOS toolchain uses libtool as ar_executable not ar.
            # This doesn't work when used as $AR, so simply don't set it - tools will probably fall back to
            # /usr/bin/ar which is probably good enough.
            if not ar_executable.endswith("libtool"):
                env["AR"] = ar_executable
        if cc_toolchain.sysroot:
            env["SYSROOT"] = cc_toolchain.sysroot

    env["SYSROOT"] = "${{pwd}}/{}".format(sysroot)
    return flags, env, toolchain_tools

rust_doc_test = rule(
    implementation = _rust_doc_test_impl,
    attrs = {
        "crate": attr.label(
            doc = (
                "The label of the target to generate code documentation for.\n" +
                "\n" +
                "`rust_doc_test` can generate HTML code documentation for the source files of " +
                "`rust_library` or `rust_binary` targets."
            ),
            providers = [rust_common.crate_info],
            # TODO: Make this attribute mandatory once `dep` is removed
        ),
        "dep": attr.label(
            doc = "__deprecated__: use `crate`",
            providers = [rust_common.crate_info],
        ),
        "_cc_toolchain": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
        "_launcher": attr.label(
            executable = True,
            default = Label("//util/launcher:launcher"),
            cfg = "exec",
            doc = (
                "A launcher executable for loading environment and argument files passed in via the " +
                "`env` attribute and ensuring the variables are set for the underlying test executable."
            ),
        ),
    },
    test = True,
    fragments = ["cpp"],
    toolchains = [
        str(Label("//rust:toolchain")),
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    incompatible_use_toolchain_transition = True,
    doc = """Runs Rust documentation tests.

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

load("@rules_rust//rust:rust.bzl", "rust_library", "rust_doc_test")

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
""",
)
