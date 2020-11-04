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
load("@io_bazel_rules_rust//rust:private/rustc.bzl", "CrateInfo", "DepInfo", "add_crate_link_flags", "add_edition_flags")
load("@io_bazel_rules_rust//rust:private/utils.bzl", "find_toolchain")

_DocInfo = provider(
    doc = "A provider containing information about a Rust documentation target.",
    fields = {
        "zip_file": "File: the zip file with rustdoc(1) output",
    },
)

_rust_doc_doc = """Generates code documentation.

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

  To build [`rustdoc`][rustdoc] documentation for the `hello_lib` crate, define \
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

  Running `bazel build //hello_lib:hello_lib_doc` will build a zip file containing \
  the documentation for the `hello_lib` library crate generated by `rustdoc`.
"""

def _rust_doc_impl(ctx):
    """The implementation of the `rust_doc` rule

    Args:
        ctx (ctx): The rule's context object
    """
    if CrateInfo not in ctx.attr.dep:
        fail("Expected rust_library or rust_binary.", "dep")

    crate = ctx.attr.dep[CrateInfo]
    dep_info = ctx.attr.dep[DepInfo]
    doc_info = _DocInfo(zip_file = ctx.outputs.rust_doc_zip)

    toolchain = find_toolchain(ctx)

    rustdoc_inputs = depset(
        crate.srcs +
        [c.output for c in dep_info.transitive_crates.to_list()] +
        [toolchain.rust_doc],
        transitive = [
            toolchain.rustc_lib.files,
            toolchain.rust_lib.files,
        ],
    )

    output_dir = ctx.actions.declare_directory(ctx.label.name)
    args = ctx.actions.args()
    args.add(crate.root.path)
    args.add("--crate-name", crate.name)
    args.add("--crate-type", crate.type)
    args.add("--output", output_dir.path)
    add_edition_flags(args, crate)

    # nb. rustdoc can't do anything with native link flags; we must omit them.
    add_crate_link_flags(args, dep_info)

    args.add_all(ctx.files.markdown_css, before_each = "--markdown-css")
    if ctx.file.html_in_header:
        args.add("--html-in-header", ctx.file.html_in_header)
    if ctx.file.html_before_content:
        args.add("--html-before-content", ctx.file.html_before_content)
    if ctx.file.html_after_content:
        args.add("--html-after-content", ctx.file.html_after_content)

    ctx.actions.run(
        executable = toolchain.rust_doc,
        inputs = rustdoc_inputs,
        outputs = [output_dir],
        arguments = [args],
        mnemonic = "Rustdoc",
        progress_message = "Generating rustdoc for {} ({} files)".format(crate.name, len(crate.srcs)),
    )

    # This rule does nothing without a single-file output, though the directory should've sufficed.
    _zip_action(ctx, output_dir, ctx.outputs.rust_doc_zip)
    return [crate, doc_info]

def _zip_action(ctx, input_dir, output_zip):
    """Creates an archive of the generated documentation from `rustdoc`

    Args:
        ctx (ctx): The `rust_doc` rule's context object
        input_dir (File): A directory containing the outputs from rustdoc
        output_zip (File): The location of the output archive containing generated documentation
    """
    args = ctx.actions.args()
    args.add("--zipper", ctx.executable._zipper)
    args.add("--output", output_zip)
    args.add("--root-dir", input_dir.path)
    args.add_all([input_dir], expand_directories = True)
    ctx.actions.run(
        executable = ctx.executable._dir_zipper,
        inputs = [input_dir],
        outputs = [output_zip],
        arguments = [args],
        tools = [ctx.executable._zipper],
    )

rust_doc = rule(
    doc = _rust_doc_doc,
    implementation = _rust_doc_impl,
    attrs = {
        "dep": attr.label(
            doc = (
                "The label of the target to generate code documentation for.\n" +
                "\n" +
                "`rust_doc` can generate HTML code documentation for the source files of " +
                "`rust_library` or `rust_binary` targets."
            ),
            mandatory = True,
        ),
        "markdown_css": attr.label_list(
            doc = "CSS files to include via `<link>` in a rendered Markdown file.",
            allow_files = [".css"],
        ),
        "html_in_header": attr.label(
            doc = "File to add to `<head>`.",
            allow_single_file = [".html", ".md"],
        ),
        "html_before_content": attr.label(
            doc = "File to add in `<body>`, before content.",
            allow_single_file = [".html", ".md"],
        ),
        "html_after_content": attr.label(
            doc = "File to add in `<body>`, after content.",
            allow_single_file = [".html", ".md"],
        ),
        "_dir_zipper": attr.label(
            default = Label("//util/dir_zipper"),
            cfg = "exec",
            executable = True,
        ),
        "_zipper": attr.label(
            default = Label("@bazel_tools//tools/zip:zipper"),
            cfg = "exec",
            executable = True,
        ),
    },
    outputs = {
        "rust_doc_zip": "%{name}.zip",
    },
    toolchains = ["@io_bazel_rules_rust//rust:toolchain"],
)

def _rust_doc_server_stub_impl(ctx):
    dep = ctx.attr.rust_doc_dep
    crate_name = dep[CrateInfo].name
    zip_file = dep[_DocInfo].zip_file
    ctx.actions.expand_template(
        template = ctx.file._server_template,
        output = ctx.outputs.main,
        substitutions = {
            "{CRATE_NAME}": crate_name,
            "{ZIP_FILE}": zip_file.basename,
        },
    )

_rust_doc_server_stub = rule(
    implementation = _rust_doc_server_stub_impl,
    attrs = {
        "rust_doc_dep": attr.label(
            mandatory = True,
            providers = [CrateInfo, _DocInfo],
        ),
        "main": attr.output(),
        "zip_file": attr.output(),
        "_server_template": attr.label(
            default = Label("//rust:doc_server.template.py"),
            allow_single_file = True,
        ),
    },
)

def rust_doc_server(name, dep, **kwargs):
    python_stub_name = name + "_python_stub"
    python_stub_output = name + ".py"
    zip_file = dep + ".zip"
    _rust_doc_server_stub(
        name = python_stub_name,
        rust_doc_dep = dep,
        main = python_stub_output,
    )
    native.py_binary(
        name = name,
        srcs = [python_stub_output],
        data = [zip_file],
    )
