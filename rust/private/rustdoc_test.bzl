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
load("@io_bazel_rules_rust//rust:private/rustc.bzl", "CrateInfo", "DepInfo")
load("@io_bazel_rules_rust//rust:private/utils.bzl", "find_toolchain", "get_lib_name")

def _rust_doc_test_impl(ctx):
    """The implementation for the `rust_doc_test` rule

    Args:
        ctx (ctx): The rule's context object

    Returns:
        list: A list containing a DefaultInfo provider
    """
    if CrateInfo not in ctx.attr.dep:
        fail("Expected rust library or binary.", "dep")

    crate = ctx.attr.dep[CrateInfo]

    toolchain = find_toolchain(ctx)

    dep_info = ctx.attr.dep[DepInfo]

    # Construct rustdoc test command, which will be written to a shell script
    # to be executed to run the test.
    flags = _build_rustdoc_flags(dep_info, crate)
    if toolchain.os != "windows":
        rust_doc_test = _build_rustdoc_test_bash_script(ctx, toolchain, flags, crate)
    else:
        rust_doc_test = _build_rustdoc_test_batch_script(ctx, toolchain, flags, crate)

    # The test script compiles the crate and runs it, so it needs both compile and runtime inputs.
    compile_inputs = depset(
        crate.srcs +
        [crate.output] +
        dep_info.transitive_libs +
        [toolchain.rust_doc] +
        [toolchain.rustc] +
        toolchain.crosstool_files,
        transitive = [
            toolchain.rustc_lib.files,
            toolchain.rust_lib.files,
        ],
    )

    return [DefaultInfo(
        runfiles = ctx.runfiles(
            files = compile_inputs.to_list(),
            collect_data = True,
        ),
        executable = rust_doc_test,
    )]

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

def _build_rustdoc_flags(dep_info, crate):
    """Constructs the rustdoc script used to test `crate`. 

    Args:
        dep_info (DepInfo): The DepInfo provider
        crate (CrateInfo): The CrateInfo provider

    Returns:
        list: A list of rustdoc flags (str)
    """

    d = dep_info

    # nb. Paths must be constructed wrt runfiles, so we construct relative link flags for doctest.
    link_flags = []
    link_search_flags = []

    link_flags.append("--extern=" + crate.name + "=" + crate.output.short_path)
    link_flags += ["--extern=" + c.name + "=" + c.dep.output.short_path for c in d.direct_crates.to_list()]
    link_search_flags += ["-Ldependency={}".format(_dirname(c.output.short_path)) for c in d.transitive_crates.to_list()]

    link_flags += ["-ldylib=" + get_lib_name(lib) for lib in d.transitive_dylibs.to_list()]
    link_search_flags += ["-Lnative={}".format(_dirname(lib.short_path)) for lib in d.transitive_dylibs.to_list()]
    link_flags += ["-lstatic=" + get_lib_name(lib) for lib in d.transitive_staticlibs.to_list()]
    link_search_flags += ["-Lnative={}".format(_dirname(lib.short_path)) for lib in d.transitive_staticlibs.to_list()]

    edition_flags = ["--edition={}".format(crate.edition)] if crate.edition != "2015" else []

    return link_search_flags + link_flags + edition_flags

_rustdoc_test_bash_script = """\
#!/usr/bin/env bash

set -e;

{rust_doc} --test \\
    {crate_root} \\
    --crate-name={crate_name} \\
    {flags}
"""

def _build_rustdoc_test_bash_script(ctx, toolchain, flags, crate):
    """Generates a helper script for executing a rustdoc test for unix systems

    Args:
        ctx (ctx): The `rust_doc_test` rule's context object
        toolchain (ToolchainInfo): A rustdoc toolchain
        flags (list): A list of rustdoc flags (str)
        crate (CrateInfo): The CrateInfo provider

    Returns:
        File: An executable containing information for a rustdoc test
    """
    rust_doc_test = ctx.actions.declare_file(
        ctx.label.name + ".sh",
    )
    ctx.actions.write(
        output = rust_doc_test,
        content = _rustdoc_test_bash_script.format(
            rust_doc = toolchain.rust_doc.short_path,
            crate_root = crate.root.path,
            crate_name = crate.name,
            # TODO: Should be possible to do this with ctx.actions.Args, but can't seem to get them as a str and into the template.
            flags = " \\\n    ".join(flags),
        ),
        is_executable = True,
    )
    return rust_doc_test

_rustdoc_test_batch_script = """\
{rust_doc} --test ^
    {crate_root} ^
    --crate-name={crate_name} ^
    {flags}
"""

def _build_rustdoc_test_batch_script(ctx, toolchain, flags, crate):
    """Generates a helper script for executing a rustdoc test for windows systems

    Args:
        ctx (ctx): The `rust_doc_test` rule's context object
        toolchain (ToolchainInfo): A rustdoc toolchain
        flags (list): A list of rustdoc flags (str)
        crate (CrateInfo): The CrateInfo provider

    Returns:
        File: An executable containing information for a rustdoc test
    """
    rust_doc_test = ctx.actions.declare_file(
        ctx.label.name + ".bat",
    )
    ctx.actions.write(
        output = rust_doc_test,
        content = _rustdoc_test_batch_script.format(
            rust_doc = toolchain.rust_doc.short_path.replace("/", "\\"),
            crate_root = crate.root.path,
            crate_name = crate.name,
            # TODO: Should be possible to do this with ctx.actions.Args, but can't seem to get them as a str and into the template.
            flags = " ^\n    ".join(flags),
        ),
        is_executable = True,
    )
    return rust_doc_test

rust_doc_test = rule(
    implementation = _rust_doc_test_impl,
    attrs = {
        "dep": attr.label(
            doc = (
                "The label of the target to run documentation tests for.\n" +
                "\n" +
                "`rust_doc_test` can run documentation tests for the source files of " +
                "`rust_library` or `rust_binary` targets."
            ),
            mandatory = True,
            providers = [CrateInfo],
        ),
    },
    executable = True,
    test = True,
    toolchains = ["@io_bazel_rules_rust//rust:toolchain"],
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

load("@io_bazel_rules_rust//rust:rust.bzl", "rust_library", "rust_doc_test")

rust_library(
    name = "hello_lib",
    srcs = ["src/lib.rs"],
)

rust_doc_test(
    name = "hello_lib_doc_test",
    dep = ":hello_lib",
)
```

Running `bazel test //hello_lib:hello_lib_doc_test` will run all documentation tests for the `hello_lib` library crate.
""",
)
