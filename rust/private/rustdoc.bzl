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

load("@io_bazel_rules_rust//rust:private/rustc.bzl", "CrateInfo", "DepInfo", "setup_deps")
load("@io_bazel_rules_rust//rust:private/utils.bzl", "find_toolchain")

def _rust_doc_impl(ctx):
    if CrateInfo not in ctx.attr.dep:
        fail("Expected rust library or binary.", "dep")

    toolchain = find_toolchain(ctx)

    crate = ctx.attr.dep[CrateInfo]
    dep_info = ctx.attr.dep[DepInfo]

    rustdoc_inputs = (
        crate.srcs +
        [c.output for c in dep_info.transitive_crates] +
        [toolchain.rust_doc] +
        toolchain.rustc_lib +
        toolchain.rust_lib
    )

    output_dir = ctx.actions.declare_directory(ctx.label.name)
    args = ctx.actions.args()
    args.add(crate.root.path)
    args.add("--crate-name", crate.name)
    args.add("--output", output_dir)
    args.add_all(dep_info.transitive_crates, before_each = "--extern", map_each = _crate_to_link_flag)
    args.add_all(ctx.files.markdown_css, before_each = "--markdown-css")
    if ctx.file.html_in_header:
        args.add("--html-in-header", ctx.file.html_in_header)
    if ctx.file.html_before_content:
        args.add("--html-before-content", ctx.file.html_before_content)
    if ctx.file.html_after_content:
        args.add("--html-after-content", ctx.file.html_after_content)

    # nb. rustdoc can't do anything with native link flags; we must omit them.
    ctx.actions.run(
        executable = toolchain.rust_doc,
        inputs = rustdoc_inputs,
        outputs = [output_dir],
        arguments = [args],
        mnemonic = "Rustdoc",
        progress_message = "Generating rustdoc for {} ({} files)".format(crate.name, len(crate.srcs)),
    )

    # nb. This rule does nothing without a single-file output, though the directory should've sufficed.
    _zip_action(ctx, output_dir, ctx.outputs.rust_doc_zip)

def _crate_to_link_flag(crate_info):
    return "{}={}".format(crate_info.name, crate_info.output.path)

def _zip_action(ctx, input_dir, output_zip):
    args = ctx.actions.args()

    # Create but not compress.
    args.add("c", output_zip)
    args.add_all([input_dir], expand_directories = True)
    ctx.actions.run(
        executable = ctx.executable._zipper,
        inputs = [input_dir],
        outputs = [output_zip],
        arguments = [args],
    )

def _rust_doc_test_impl(ctx):
    if CrateInfo not in ctx.attr.dep:
        fail("Expected rust library or binary.", "dep")

    crate = ctx.attr.dep[CrateInfo]
    rust_doc_test = ctx.outputs.executable

    toolchain = find_toolchain(ctx)

    working_dir = "."
    dep_info = setup_deps(
        [ctx.attr.dep],
        crate.name,
        working_dir,
        toolchain,
        in_runfiles = True,
    )

    # Construct rustdoc test command, which will be written to a shell script
    # to be executed to run the test.
    ctx.file_action(
        output = rust_doc_test,
        content = _build_rustdoc_test_script(toolchain, dep_info, crate),
        executable = True,
    )

    doc_test_inputs = (
        crate.srcs +
        [crate.output] +
        dep_info.transitive_libs +
        [toolchain.rust_doc] +
        toolchain.rustc_lib +
        toolchain.rust_lib
    )

    runfiles = ctx.runfiles(files = doc_test_inputs, collect_data = True)
    return struct(runfiles = runfiles)

def _build_rustdoc_test_script(toolchain, dep_info, crate):
    """
    Constructs the rustdoc script used to test `crate`.
    """
    return " ".join(
        ["#!/usr/bin/env bash\n"] +
        ["set -e\n"] +
        dep_info.setup_cmd +
        [
            toolchain.rust_doc.path,
            "--test",
            crate.root.path,
            "--crate-name",
            crate.name,
        ] +
        dep_info.link_search_flags +
        dep_info.link_flags,
    )

_rust_doc_common_attrs = {
    "dep": attr.label(mandatory = True),
    "_zipper": attr.label(default = Label("@bazel_tools//tools/zip:zipper"), cfg = "host", executable = True),
}

_rust_doc_attrs = {
    "markdown_css": attr.label_list(allow_files = [".css"]),
    "html_in_header": attr.label(allow_files = [".html", ".md"], single_file = True),
    "html_before_content": attr.label(allow_files = [".html", ".md"], single_file = True),
    "html_after_content": attr.label(allow_files = [".html", ".md"], single_file = True),
}

rust_doc = rule(
    _rust_doc_impl,
    attrs = dict(_rust_doc_common_attrs.items() +
                 _rust_doc_attrs.items()),
    outputs = {
        "rust_doc_zip": "%{name}.zip",
    },
    toolchains = ["@io_bazel_rules_rust//rust:toolchain"],
)

"""Generates code documentation.

Args:
  name: A unique name for this rule.
  dep: The label of the target to generate code documentation for.

    `rust_doc` can generate HTML code documentation for the source files of
    `rust_library` or `rust_binary` targets.
  markdown_css: CSS files to include via `<link>` in a rendered
    Markdown file.
  html_in_header: File to add to `<head>`.
  html_before_content: File to add in `<body>`, before content.
  html_after_content: File to add in `<body>`, after content.

Example:
  Suppose you have the following directory structure for a Rust library crate:

  ```
  [workspace]/
      WORKSPACE
      hello_lib/
          BUILD
          src/
              lib.rs
  ```

  To build [`rustdoc`][rustdoc] documentation for the `hello_lib` crate, define
  a `rust_doc` rule that depends on the the `hello_lib` `rust_library` target:

  [rustdoc]: https://doc.rust-lang.org/book/documentation.html

  ```python
  package(default_visibility = ["//visibility:public"])

  load("@io_bazel_rules_rust//rust:rust.bzl", "rust_library", "rust_doc")

  rust_library(
      name = "hello_lib",
      srcs = ["src/lib.rs"],
  )

  rust_doc(
      name = "hello_lib_doc",
      dep = ":hello_lib",
  )
  ```

  Running `bazel build //hello_lib:hello_lib_doc` will build a zip file containing
  the documentation for the `hello_lib` library crate generated by `rustdoc`.
"""

rust_doc_test = rule(
    _rust_doc_test_impl,
    attrs = _rust_doc_common_attrs,
    executable = True,
    test = True,
    toolchains = ["@io_bazel_rules_rust//rust:toolchain"],
)

"""Runs Rust documentation tests.

Args:
  name: A unique name for this rule.
  dep: The label of the target to run documentation tests for.

    `rust_doc_test` can run documentation tests for the source files of
    `rust_library` or `rust_binary` targets.

Example:
  Suppose you have the following directory structure for a Rust library crate:

  ```
  [workspace]/
      WORKSPACE
      hello_lib/
          BUILD
          src/
              lib.rs
  ```

  To run [documentation tests][doc-test] for the `hello_lib` crate, define a
  `rust_doc_test` target that depends on the `hello_lib` `rust_library` target:

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

  Running `bazel test //hello_lib:hello_lib_doc_test` will run all documentation
  tests for the `hello_lib` library crate.
"""
