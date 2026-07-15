# Copyright 2026 The Bazel Authors. All rights reserved.
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

"""Rules for generating merged `rustdoc` documentation for a workspace of crates"""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("//rust/private:common.bzl", "rust_common")
load("//rust/private:providers.bzl", "LintsInfo")
load("//rust/private:rustdoc.bzl", "rustdoc_compile_action", "zip_action")
load(
    "//rust/private:utils.bzl",
    "dedent",
    "find_toolchain",
)

RustWorkspaceDocInfo = provider(
    doc = "A provider containing rustdoc outputs gathered by `rust_workspace_doc_aspect`.",
    fields = {
        "crate_docs": (
            "depset[struct]: Transitively collected per-crate rustdoc outputs. Each entry " +
            "has the fields `name` (str, the crate name), `crate_root_path` (str, the path " +
            "of the crate root source file, used for deduplication), `label_str` (str, the " +
            "label of the documented target), `is_bin` (bool, whether the crate is a " +
            "binary), `html_dir` (File, the crate's rustdoc output directory) and " +
            "`parts_dir` (File, the crate's `--parts-out-dir` cross-crate information " +
            "directory)."
        ),
        "html_dirs": "depset[File]: The `html_dir`s of `crate_docs`.",
        "parts_dirs": "depset[File]: The `parts_dir`s of `crate_docs`.",
    },
)

ExtraRustdocFlagsInfo = provider(
    doc = "Extra flags to pass to every per-crate rustdoc invocation of `rust_workspace_doc_aspect`.",
    fields = {"flags": "List[string]: Flags to pass to rustdoc"},
)

def _rustdoc_workspace_extra_flag_impl(ctx):
    return ExtraRustdocFlagsInfo(flags = [f for f in ctx.build_setting_value if f != ""])

rustdoc_workspace_extra_flag = rule(
    doc = (
        "Add a flag to every per-crate rustdoc invocation of `rust_workspace_doc_aspect` " +
        "from the command line with " +
        "`--@rules_rust//rust/settings:rustdoc_workspace_extra_flag`. Multiple uses are " +
        "accumulated. Use the `rustdoc_flags` attribute of `rust_workspace_doc` to pass " +
        "flags to the finalizing invocation instead."
    ),
    implementation = _rustdoc_workspace_extra_flag_impl,
    build_setting = config.string_list(flag = True, repeatable = True),
)

_NIGHTLY_ERROR = (
    "{} requires a nightly Rust toolchain: the `rustdoc` cross-crate merge flags " +
    "(`--merge`, `--parts-out-dir`, `--include-parts-dir` from RFC 3662) are unstable " +
    "and gated behind `-Zunstable-options`. Configure a nightly toolchain, e.g. with " +
    "`--@rules_rust//rust/toolchain/channel=nightly`. See " +
    "https://github.com/rust-lang/rust/issues/130676 for the stabilization status."
)

# Targets with any of these tags are not documented.
_IGNORE_TAGS = [
    "no_docs",
    "nodocs",
    "no_rustdoc",
    "norustdoc",
]

def _get_docable_crate_info(target, ctx, include_external):
    """Determine whether a target should be documented and return its `CrateInfo`.

    Args:
        target (Target): The target the aspect is running on.
        ctx (ctx): The aspect's context object.
        include_external (bool): Whether crates from external repositories should
            be documented.

    Returns:
        CrateInfo, optional: The target's `CrateInfo` if it should be documented.
    """
    if not include_external and target.label.workspace_root.startswith("external"):
        return None

    for tag in ctx.rule.attr.tags:
        if tag.replace("-", "_").lower() in _IGNORE_TAGS:
            return None

    # Test crates are intentionally not documented, matching `cargo doc`.
    if rust_common.test_crate_info in target:
        return None

    if rust_common.crate_info not in target:
        return None

    crate_info = target[rust_common.crate_info]
    if crate_info.is_test:
        return None

    return crate_info

def _collect_transitive_crate_docs(ctx):
    """Gather `RustWorkspaceDocInfo` depsets from all dependency attributes.

    Args:
        ctx (ctx): The aspect's context object.

    Returns:
        list[RustWorkspaceDocInfo]: The providers of all dependencies.
    """
    infos = []
    for attr_name in ("deps", "proc_macro_deps", "crate", "actual"):
        dep_or_deps = getattr(ctx.rule.attr, attr_name, None)
        deps = dep_or_deps if type(dep_or_deps) == "list" else [dep_or_deps]
        for dep in deps:
            if dep != None and RustWorkspaceDocInfo in dep:
                infos.append(dep[RustWorkspaceDocInfo])
    return infos

def _rust_workspace_doc_aspect_impl(target, ctx):
    """The implementation of the `rust_workspace_doc_aspect` aspect

    Args:
        target (Target): The target the aspect is running on.
        ctx (ctx): The aspect's context object.

    Returns:
        list: A list of providers.
    """
    dep_infos = _collect_transitive_crate_docs(ctx)
    transitive_docs = [info.crate_docs for info in dep_infos]
    transitive_html = [info.html_dirs for info in dep_infos]
    transitive_parts = [info.parts_dirs for info in dep_infos]

    include_external = ctx.attr._include_external[BuildSettingInfo].value
    crate_info = _get_docable_crate_info(target, ctx, include_external)

    toolchain = find_toolchain(ctx)

    # The `rustdoc` merge flags require a nightly toolchain. Produce no
    # documentation instead of failing so that targets which gracefully
    # handle the missing toolchain (e.g. via `target_compatible_with`)
    # do not break dependency analysis; `rust_workspace_doc` itself
    # fails with a descriptive error.
    if not crate_info or toolchain.channel != "nightly":
        info = RustWorkspaceDocInfo(
            crate_docs = depset(transitive = transitive_docs),
            html_dirs = depset(transitive = transitive_html),
            parts_dirs = depset(transitive = transitive_parts),
        )
        return [
            info,
            OutputGroupInfo(
                rustdoc_crate_dir = info.html_dirs,
                rustdoc_crate_parts = info.parts_dirs,
            ),
        ]

    # Binary crates get a distinct directory suffix: like `cargo doc`, a
    # binary whose crate name collides with another documented crate must
    # yield to it, which the consumers of these outputs resolve when
    # assembling the merged tree.
    dir_name = "{}.rustdoc_workspace{}".format(
        ctx.label.name,
        "_bin" if crate_info.type == "bin" else "",
    )
    html_dir = ctx.actions.declare_directory("{}/html".format(dir_name))
    parts_dir = ctx.actions.declare_directory("{}/parts".format(dir_name))

    rustdoc_flags = ctx.actions.args()
    rustdoc_flags.add_all(
        [crate_info.output],
        format_each = "--extern={}=%s".format(crate_info.name),
        expand_directories = False,
    )
    rustdoc_flags.add("-Zunstable-options")
    rustdoc_flags.add("--merge=none")
    rustdoc_flags.add_all(
        [parts_dir],
        before_each = "--parts-out-dir",
        expand_directories = False,
    )

    # User-provided flags come last so they can override anything above.
    rustdoc_flags.add_all(ctx.attr._extra_rustdoc_flag[ExtraRustdocFlagsInfo].flags)

    lints_info = target[LintsInfo] if LintsInfo in target else None

    action = rustdoc_compile_action(
        ctx = ctx,
        toolchain = toolchain,
        crate_info = crate_info,
        lints_info = lints_info,
        output = html_dir,
        rustdoc_flags = rustdoc_flags,
        attr = ctx.rule.attr,
        file = ctx.rule.file,
        files = ctx.rule.files,
    )

    # rustdoc only generates links into another crate's documentation if that
    # crate's directory already exists in the output directory. Pre-create a
    # directory for every dependency that is part of the merged documentation
    # so cross-crate links resolve within the merged tree.
    mkdir_args = ctx.actions.args()
    dep_names = {doc.name: None for doc in depset(transitive = transitive_docs).to_list()}
    for dep_name in dep_names:
        mkdir_args.add_all(
            [html_dir],
            before_each = "--mkdir",
            format_each = "%s/" + dep_name,
            expand_directories = False,
        )

    ctx.actions.run(
        mnemonic = "RustdocMerge",
        progress_message = "Generating mergeable Rustdoc for {}".format(ctx.label),
        outputs = [html_dir, parts_dir],
        executable = action.executable,
        inputs = action.inputs,
        env = action.env,
        arguments = [mkdir_args] + action.arguments,
        tools = action.tools,
        toolchain = Label("//rust:toolchain_type"),
        execution_requirements = {"supports-path-mapping": ""} if action.supports_path_mapping else None,
    )

    crate_doc = struct(
        name = crate_info.name,
        crate_root_path = crate_info.root.path,
        label_str = str(ctx.label),
        is_bin = crate_info.type == "bin",
        html_dir = html_dir,
        parts_dir = parts_dir,
    )

    # The output groups are transitive so that documentation for the full
    # dependency closure is built no matter which targets a pattern matches.
    info = RustWorkspaceDocInfo(
        crate_docs = depset([crate_doc], transitive = transitive_docs),
        html_dirs = depset([html_dir], transitive = transitive_html),
        parts_dirs = depset([parts_dir], transitive = transitive_parts),
    )
    return [
        info,
        OutputGroupInfo(
            rustdoc_crate_dir = info.html_dirs,
            rustdoc_crate_parts = info.parts_dirs,
        ),
    ]

# Example: Generate mergeable rustdoc outputs for all crates in the workspace.
#   bazel build --aspects=@rules_rust//rust:defs.bzl%rust_workspace_doc_aspect \
#               --output_groups=rustdoc_crate_dir \
#               //...
rust_workspace_doc_aspect = aspect(
    fragments = ["cpp"],
    attr_aspects = ["deps", "proc_macro_deps", "crate", "actual"],
    attrs = {
        "_error_format": attr.label(
            default = Label("//rust/settings:error_format"),
        ),
        "_extra_rustdoc_flag": attr.label(
            doc = "Extra flags to pass to every per-crate rustdoc invocation.",
            default = Label("//rust/settings:rustdoc_workspace_extra_flag"),
        ),
        "_include_external": attr.label(
            doc = "Whether crates from external repositories are documented.",
            default = Label("//rust/settings:rustdoc_workspace_include_external"),
        ),
        "_process_wrapper": attr.label(
            doc = "A process wrapper for running rustdoc on all platforms",
            default = Label("@rules_rust//util/process_wrapper"),
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),
    },
    provides = [RustWorkspaceDocInfo],
    toolchains = [
        str(Label("//rust:toolchain_type")),
        config_common.toolchain_type("@bazel_tools//tools/cpp:toolchain_type", mandatory = False),
    ],
    implementation = _rust_workspace_doc_aspect_impl,
    doc = dedent("""\
        Generates rustdoc documentation for a crate and all its transitive
        dependencies in a form that can be merged into a single documentation
        tree by `rust_workspace_doc`.

        Each documented crate produces two directories: the crate's rendered
        HTML documentation and its cross-crate information "parts"
        (`--parts-out-dir`), which `rust_workspace_doc` merges into a unified
        search index.

        The `rustdoc` merge flags are unstable
        (https://github.com/rust-lang/rust/issues/130676), so this aspect
        requires a nightly Rust toolchain and produces no documentation
        outputs on other toolchain channels.
    """),
)

def _sanitize_crate_name(name):
    """Convert a target name into a valid crate name for the finalize stub.

    Args:
        name (str): The name to sanitize.

    Returns:
        str: A valid crate name.
    """
    sanitized = "".join([c if c.isalnum() else "_" for c in name.elems()])
    if sanitized[0].isdigit():
        sanitized = "_" + sanitized
    return sanitized

def _rust_workspace_doc_impl(ctx):
    """The implementation of the `rust_workspace_doc` rule

    Args:
        ctx (ctx): The rule's context object

    Returns:
        list: A list of providers.
    """
    toolchain = find_toolchain(ctx)
    if toolchain.channel != "nightly":
        fail(_NIGHTLY_ERROR.format("rust_workspace_doc target '{}'".format(ctx.label)))

    all_docs = depset(transitive = [
        dep[RustWorkspaceDocInfo].crate_docs
        for dep in ctx.attr.deps
        if RustWorkspaceDocInfo in dep
    ]).to_list()

    # The same crate may be reachable in multiple configurations (e.g. both the
    # target and exec configuration via proc-macro dependencies). Deduplicate
    # by the path of the crate root source file.
    docs_by_root = {}
    for doc in all_docs:
        if doc.crate_root_path not in docs_by_root:
            docs_by_root[doc.crate_root_path] = doc
    crate_docs = docs_by_root.values()

    if not crate_docs:
        fail(
            "rust_workspace_doc target '{}' found no crates to document. ".format(ctx.label) +
            "Ensure `deps` contains Rust targets (or targets that transitively depend on " +
            "them) from the current workspace, or enable " +
            "`--@rules_rust//rust/settings:rustdoc_workspace_include_external` to " +
            "document crates from external repositories.",
        )

    # Merged documentation places every crate in a directory named after the
    # crate, so crates sharing a name would silently collide. Resolve them the
    # way `cargo doc` does: library crates win over binaries, and a binary
    # whose name is already taken is skipped. Colliding libraries remain an
    # error.
    lib_docs = [doc for doc in crate_docs if not doc.is_bin]
    bin_docs = [doc for doc in crate_docs if doc.is_bin]
    docs_by_name = {}
    for doc in lib_docs:
        if doc.name in docs_by_name:
            fail(
                "rust_workspace_doc target '{}' found multiple crates named '{}': {} and {}. ".format(
                    ctx.label,
                    doc.name,
                    docs_by_name[doc.name].label_str,
                    doc.label_str,
                ) + "Exclude one of them from documentation by tagging it with 'no_docs'.",
            )
        docs_by_name[doc.name] = doc
    for doc in bin_docs:
        if doc.name not in docs_by_name:
            docs_by_name[doc.name] = doc
    crate_docs = docs_by_name.values()

    # `rustdoc --merge=finalize` writes the merged cross-crate information
    # while documenting a crate, so document a stub crate that doubles as a
    # place-holder for the workspace itself.
    stub_root = ctx.actions.declare_file("{}.finalize.rs".format(ctx.label.name))
    ctx.actions.write(
        output = stub_root,
        content = "//! Merged documentation for all crates in the workspace.\n",
    )
    stub_crate_info = rust_common.create_crate_info(
        name = _sanitize_crate_name(ctx.label.name),
        type = "lib",
        root = stub_root,
        srcs = depset([stub_root]),
        deps = depset([]),
        proc_macro_deps = depset([]),
        aliases = {},
        output = None,
        metadata = None,
        edition = "2024",
        rustc_env = {},
        rustc_env_files = [],
        is_test = False,
        compile_data = depset([]),
        compile_data_targets = depset([]),
        data = depset([]),
    )

    finalize_dir = ctx.actions.declare_directory("{}.rustdoc_finalize".format(ctx.label.name))

    rustdoc_flags = ctx.actions.args()
    rustdoc_flags.add("-Zunstable-options")
    rustdoc_flags.add("--merge=finalize")
    parts_dirs = [doc.parts_dir for doc in crate_docs]
    rustdoc_flags.add_all(
        parts_dirs,
        before_each = "--include-parts-dir",
        expand_directories = False,
    )
    if ctx.attr.generate_index_page:
        # Generate a rustdoc-styled landing page listing all crates.
        rustdoc_flags.add("--enable-index-page")
    rustdoc_flags.add_all(ctx.attr.rustdoc_flags)

    action = rustdoc_compile_action(
        ctx = ctx,
        toolchain = toolchain,
        crate_info = stub_crate_info,
        output = finalize_dir,
        rustdoc_flags = rustdoc_flags,
    )

    ctx.actions.run(
        mnemonic = "RustdocMergeFinalize",
        progress_message = "Merging Rustdoc cross-crate information for {}".format(ctx.label),
        outputs = [finalize_dir],
        executable = action.executable,
        inputs = depset(parts_dirs, transitive = [action.inputs]),
        env = action.env,
        arguments = action.arguments,
        tools = action.tools,
        toolchain = Label("//rust:toolchain_type"),
        execution_requirements = {"supports-path-mapping": ""} if action.supports_path_mapping else None,
    )

    # Combine the per-crate documentation and the merged cross-crate
    # information into a single documentation tree.
    output_dir = ctx.actions.declare_directory("{}.rustdoc".format(ctx.label.name))

    html_dirs = [doc.html_dir for doc in crate_docs]

    merge_args = ctx.actions.args()
    merge_args.add("--output")
    merge_args.add_all([output_dir], expand_directories = False)
    merge_args.add("--inputs")
    merge_args.add_all(html_dirs, expand_directories = False)

    # The finalize directory is passed last so its merged shared files
    # (search index, crate list, static files) win over the per-crate copies.
    merge_args.add_all([finalize_dir], expand_directories = False)

    ctx.actions.run(
        mnemonic = "RustdocMergeCopy",
        progress_message = "Assembling merged Rustdoc tree for {}".format(ctx.label),
        outputs = [output_dir],
        executable = ctx.executable._doc_merger,
        inputs = html_dirs + [finalize_dir],
        arguments = [merge_args],
    )

    zip_action(ctx, output_dir, ctx.outputs.rust_doc_zip, ctx.label)

    return [
        DefaultInfo(
            files = depset([output_dir]),
        ),
        OutputGroupInfo(
            crate_docs = depset(html_dirs),
            rustdoc_dir = depset([output_dir]),
            rustdoc_zip = depset([ctx.outputs.rust_doc_zip]),
        ),
    ]

rust_workspace_doc = rule(
    doc = dedent("""\
        Generates merged documentation for all Rust crates reachable from a set
        of targets, similar to running `cargo doc` in a Cargo workspace.

        Unlike `rust_doc`, which documents a single crate, this rule walks the
        transitive dependencies of the targets listed in `deps`, documents every
        crate from the current workspace it finds, and merges the results into
        a single documentation tree with a unified search index and cross-crate
        links. Individual crates do not need to be listed: adding a few
        top-level targets is enough to document the whole workspace.

        Binary crates are documented like `cargo doc --bins`: a binary whose
        crate name collides with another documented crate yields to it and is
        skipped. Test crates are not documented, matching `cargo doc`.

        Each crate is documented by its own action, so unchanged crates are
        served from Bazel's cache. Crates from external repositories are
        skipped unless the
        `--@rules_rust//rust/settings:rustdoc_workspace_include_external`
        flag is enabled.

        The merged documentation is produced both as a directory (the default
        output) and as a zip archive suitable for archiving or publishing,
        available as the `<name>.zip` output.

        NOTE: This rule requires a nightly Rust toolchain as the `rustdoc`
        merge flags are unstable
        (https://github.com/rust-lang/rust/issues/130676). Configure one with
        `--@rules_rust//rust/toolchain/channel=nightly`.

        Example:

        ```python
        load("@rules_rust//rust:defs.bzl", "rust_workspace_doc")

        rust_workspace_doc(
            name = "workspace_docs",
            deps = [
                "//app:server",
                "//tools/cli",
            ],
        )
        ```

        Running `bazel build --@rules_rust//rust/toolchain/channel=nightly \\
        //:workspace_docs` documents `//app:server`, `//tools/cli` and every
        workspace crate they transitively depend on.
    """),
    implementation = _rust_workspace_doc_impl,
    attrs = {
        "deps": attr.label_list(
            doc = (
                "Targets to generate merged documentation for. All Rust crates " +
                "transitively reachable from these targets are documented, so " +
                "listing a workspace's top-level targets is sufficient."
            ),
            aspects = [rust_workspace_doc_aspect],
        ),
        "generate_index_page": attr.bool(
            doc = (
                "Whether to generate a root `index.html` listing all documented " +
                "crates (rustdoc's `--enable-index-page`)."
            ),
            default = True,
        ),
        "rustdoc_flags": attr.string_list(
            doc = dedent("""\
                List of flags passed to the `rustdoc` invocation that merges the
                cross-crate information (`--merge=finalize`).
            """),
        ),
        "_dir_zipper": attr.label(
            doc = "A tool that orchestrates the creation of zip archives for rustdoc outputs.",
            default = Label("//rust/private/rustdoc/dir_zipper"),
            cfg = "exec",
            executable = True,
        ),
        "_doc_merger": attr.label(
            doc = "A tool that merges rustdoc output directories into a single tree.",
            default = Label("//rust/private/rustdoc/doc_merger"),
            cfg = "exec",
            executable = True,
        ),
        "_error_format": attr.label(
            default = Label("//rust/settings:error_format"),
        ),
        "_process_wrapper": attr.label(
            doc = "A process wrapper for running rustdoc on all platforms",
            default = Label("@rules_rust//util/process_wrapper"),
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),
        "_zipper": attr.label(
            doc = "A Bazel provided tool for creating archives",
            default = Label("@bazel_tools//tools/zip:zipper"),
            cfg = "exec",
            executable = True,
        ),
    },
    fragments = ["cpp"],
    outputs = {
        "rust_doc_zip": "%{name}.zip",
    },
    toolchains = [
        str(Label("//rust:toolchain_type")),
        config_common.toolchain_type("@bazel_tools//tools/cpp:toolchain_type", mandatory = False),
    ],
)
