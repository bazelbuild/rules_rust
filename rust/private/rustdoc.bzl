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

load("@io_bazel_rules_rust//rust:private/rustc.bzl", "setup_deps", "CrateInfo")
load("@io_bazel_rules_rust//rust:private/utils.bzl", "find_toolchain")

_ZIP_PATH = "/usr/bin/zip"

def _rust_doc_impl(ctx):
    if CrateInfo not in ctx.attr.dep:
        fail("Expected rust library or binary.", "dep")

    crate = ctx.attr.dep[CrateInfo]
    rust_doc_zip = ctx.outputs.rust_doc_zip

    toolchain = find_toolchain(ctx)

    output_dir = rust_doc_zip.dirname ## different output dir
    dep_info = setup_deps(
        crate.deps,
        crate.name,
        output_dir,
        toolchain,
    )

    rustdoc_inputs = (
        crate.srcs +
        dep_info.transitive_libs +
        [toolchain.rust_doc] +
        toolchain.rustc_lib +
        toolchain.rust_lib
    )

    doc_flags = _collect_rustdoc_flags(ctx)
    doc_cmd = _build_rustdoc_command(toolchain, rust_doc_zip, dep_info, crate, doc_flags)
    ctx.action(
        inputs = rustdoc_inputs,
        outputs = [rust_doc_zip],
        mnemonic = "Rustdoc",
        command = doc_cmd,
        use_default_shell_env = True,
        progress_message = "Generating rustdoc for {} ({} files)".format(crate.name, len(crate.srcs)),
    )

def _collect_rustdoc_flags(ctx):
    doc_flags = []
    doc_flags += [
        "--markdown-css {}".format(css.path)
        for css in ctx.files.markdown_css
    ]
    if hasattr(ctx.file, "html_in_header"):
        doc_flags += ["--html-in-header {}".format(ctx.file.html_in_header.path)]
    if hasattr(ctx.file, "html_before_content"):
        doc_flags += ["--html-before-content {}".format(ctx.file.html_before_content.path)]
    if hasattr(ctx.file, "html_after_content"):
        doc_flags += ["--html-after-content {}".format(ctx.file.html_after_content.path)]
    return doc_flags

def _build_rustdoc_command(toolchain, rust_doc_zip, dep_info, crate, doc_flags):
    """
    Constructs the rustdoc command used to build documentation for `crate`.
    """

    docs_dir = rust_doc_zip.dirname + "/_rust_docs"
    return " ".join(
        ["set -e;"] +
        dep_info.setup_cmd +
        [
            "rm -rf %s;" % docs_dir,
            "mkdir %s;" % docs_dir,
        ] + [
            toolchain.rust_doc.path,
            crate.root.path,
            "--crate-name",
            crate.name,
            "--output",
            docs_dir,
        ] +
        doc_flags +
        dep_info.link_search_flags +
        # rustdoc can't do anything with native link flags, and blows up on them
        [f for f in dep_info.link_flags if f.startswith("--extern")] +
        [
            "&&",
            "(cd",
            docs_dir,
            "&&",
            _ZIP_PATH,
            "-qR",
            rust_doc_zip.basename,
            "$(find . -type f) )",
            "&&",
            "mv %s/%s %s" % (docs_dir, rust_doc_zip.basename, rust_doc_zip.path),
        ],
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
}

_rust_doc_attrs = {
    "markdown_css": attr.label_list(allow_files = [".css"]),
    "html_in_header": attr.label(allow_files = [".html", ".md"]),
    "html_before_content": attr.label(allow_files = [".html", ".md"]),
    "html_after_content": attr.label(allow_files = [".html", ".md"]),
}

rust_doc = rule(
    _rust_doc_impl,
    attrs = dict(_rust_doc_common_attrs.items() +
                 _rust_doc_attrs.items()),
    outputs = {
        "rust_doc_zip": "%{name}-docs.zip",
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
