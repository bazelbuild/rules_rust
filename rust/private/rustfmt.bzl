"""A module defining rustfmt rules"""

load(":common.bzl", "rust_common")
load(
    ":lint_test.bzl",
    "LINT_TEST_COMMON_ATTRS",
    "lint_test_aspect_impl",
    "lint_test_rule_impl",
    "platform_transition",
    "rlocationpath",
)

def _get_rustfmt_ready_crate_info(target):
    """Check that a target is suitable for rustfmt and extract the `CrateInfo` provider from it.

    Args:
        target (Target): The target the aspect is running on.

    Returns:
        CrateInfo, optional: A `CrateInfo` provider if clippy should be run or `None`.
    """

    # Ignore external targets
    if target.label.workspace_name:
        return None

    # Obviously ignore any targets that don't contain `CrateInfo`
    if rust_common.crate_info in target:
        return target[rust_common.crate_info]
    elif rust_common.test_crate_info in target:
        return target[rust_common.test_crate_info].crate
    else:
        return None

def _find_rustfmtable_srcs(crate_info, aspect_ctx = None):
    """Parse a `CrateInfo` provider for rustfmt formattable sources.

    Args:
        crate_info (CrateInfo): A `CrateInfo` provider.
        aspect_ctx (ctx, optional): The aspect's context object.

    Returns:
        list: A list of formattable sources (`File`).
    """

    crate_srcs = crate_info.srcs

    # Targets with specific tags will not be formatted
    if aspect_ctx:
        ignore_tags = [
            "no_format",
            "no_rustfmt",
            "norustfmt",
        ]

        for tag in aspect_ctx.rule.attr.tags:
            if tag.replace("-", "_").lower() in ignore_tags:
                return []

        crate_srcs = depset(getattr(aspect_ctx.rule.files, "srcs", []), transitive = [crate_info.srcs])

    # Filter out any generated files
    srcs = [src for src in crate_srcs.to_list() if src.is_source]

    return srcs

def _perform_check(edition, srcs, ctx):
    rustfmt_toolchain = ctx.toolchains[Label("//rust/rustfmt:toolchain_type")]

    config = ctx.file._config
    marker = ctx.actions.declare_file(ctx.label.name + ".rustfmt.ok")

    args = ctx.actions.args()
    args.add("--touch-file", marker)
    args.add("--")
    args.add(rustfmt_toolchain.rustfmt)
    args.add("--config-path", config)
    args.add("--edition", edition)
    args.add("--config", "skip_children=true")
    args.add("--check")
    args.add_all(srcs)

    ctx.actions.run(
        executable = ctx.executable._process_wrapper,
        inputs = srcs + [config],
        outputs = [marker],
        tools = [rustfmt_toolchain.all_files],
        arguments = [args],
        mnemonic = "Rustfmt",
        progress_message = "Rustfmt %{label}",
        toolchain = Label("//rust/rustfmt:toolchain_type"),
    )

    return marker

RustfmtTargetInfo = provider(
    doc = "A provider containing rustfmt formattable sources for a target.",
    fields = {
        "edition": "str: The Rust edition of the target.",
        "srcs": "list[File]: The formattable sources.",
    },
)

def _rustfmt_srcs_aspect_impl(target, ctx):
    crate_info = _get_rustfmt_ready_crate_info(target)

    if not crate_info:
        return []

    srcs = _find_rustfmtable_srcs(crate_info, ctx)

    return [
        RustfmtTargetInfo(
            srcs = srcs,
            edition = crate_info.edition,
        ),
    ]

rustfmt_srcs_aspect = aspect(
    implementation = _rustfmt_srcs_aspect_impl,
    doc = "This aspect collects formattable sources from a Rust target.",
    required_providers = [
        [rust_common.crate_info],
        [rust_common.test_crate_info],
    ],
    fragments = ["cpp"],
)

def _rustfmt_aspect_impl(target, ctx):
    # Exit early if a target already has a rustfmt output group. This
    # can be useful for rules which always want to inhibit rustfmt.
    if OutputGroupInfo in target:
        if hasattr(target[OutputGroupInfo], "rustfmt_checks"):
            return []

    if RustfmtTargetInfo not in target:
        return []

    info = target[RustfmtTargetInfo]

    if not info.srcs:
        return []

    marker = _perform_check(info.edition, info.srcs, ctx)

    return [
        OutputGroupInfo(
            rustfmt_checks = depset([marker]),
        ),
    ]

rustfmt_aspect = aspect(
    implementation = _rustfmt_aspect_impl,
    doc = """\
This aspect is used to gather information about a crate for use in rustfmt and perform rustfmt checks

Output Groups:

- `rustfmt_checks`: Executes `rustfmt --check` on the specified target.

The build setting `@rules_rust//rust/settings:rustfmt.toml` is used to control the Rustfmt [configuration settings][cs]
used at runtime.

[cs]: https://rust-lang.github.io/rustfmt/

This aspect is executed on any target which provides the `CrateInfo` provider. However
users may tag a target with `no-rustfmt` or `no-format` to have it skipped. Additionally,
generated source files are also ignored by this aspect.
""",
    attrs = {
        "_config": attr.label(
            doc = "The `rustfmt.toml` file used for formatting",
            allow_single_file = True,
            default = Label("//rust/settings:rustfmt.toml"),
        ),
        "_process_wrapper": attr.label(
            doc = "A process wrapper for running rustfmt on all platforms",
            cfg = "exec",
            executable = True,
            default = Label("//util/process_wrapper"),
        ),
    },
    required_providers = [
        [rust_common.crate_info],
        [rust_common.test_crate_info],
    ],
    requires = [rustfmt_srcs_aspect],
    fragments = ["cpp"],
    toolchains = [
        str(Label("//rust/rustfmt:toolchain_type")),
    ],
)

RustfmtTestInfo = provider(
    doc = "Rustfmt check outputs surfaced by `rustfmt_test_aspect`.",
    fields = {
        "checks": "depset[File]: Rustfmt markers for the visited target plus every crate reached via `deps`, `proc_macro_deps`, and `crate`.",
        "direct_markers": "list[File]: Rustfmt markers for the visited target only.",
    },
)

_RUSTFMT_OUTPUT_GROUPS = ["rustfmt_checks"]

def _rustfmt_test_aspect_impl(target, ctx):
    return lint_test_aspect_impl(target, ctx, RustfmtTestInfo, _RUSTFMT_OUTPUT_GROUPS)

rustfmt_test_aspect = aspect(
    implementation = _rustfmt_test_aspect_impl,
    attr_aspects = ["deps", "proc_macro_deps", "crate"],
    requires = [rustfmt_aspect],
    provides = [RustfmtTestInfo],
    doc = "Walks `deps`/`proc_macro_deps`/`crate` and rolls up the markers produced by `rustfmt_aspect` into a transitive `RustfmtTestInfo`.",
)

def _rustfmt_test_impl(ctx):
    return lint_test_rule_impl(ctx, RustfmtTestInfo)

rustfmt_test = rule(
    implementation = _rustfmt_test_impl,
    attrs = dict(LINT_TEST_COMMON_ATTRS, **{
        "targets": attr.label_list(
            doc = "Rust targets to run `rustfmt --check` on.",
            providers = [
                [rust_common.crate_info],
                [rust_common.test_crate_info],
            ],
            aspects = [rustfmt_test_aspect],
            cfg = platform_transition,
        ),
    }),
    test = True,
    doc = """\
A test rule that runs `rustfmt --check` over a set of Rust targets.

By default (`transitive = True`), the aspect walks `deps`, `proc_macro_deps`, and `crate`
transitively so that listing a top-level target checks its whole crate graph. Set
`transitive = False` to format only the exact targets listed. The `rustfmt` actions run
during the build phase, so a formatting failure fails `bazel test` before the test
executable is invoked.

An optional `platform` attribute transitions `targets` to the given platform before running
`rustfmt`.

Example:

```python
load("@rules_rust//rust:defs.bzl", "rust_binary", "rust_library", "rustfmt_test")

rust_library(name = "lib", srcs = ["src/lib.rs"], edition = "2021")
rust_binary(name = "app", srcs = ["src/main.rs"], edition = "2021", deps = [":lib"])

rustfmt_test(name = "fmt_tree_test", targets = [":app"])
rustfmt_test(name = "fmt_app_only_test", targets = [":app"], transitive = False)
```

Targets tagged `no_format`, `no_rustfmt`, or `norustfmt` are skipped.
""",
)

def _rustfmt_toolchain_impl(ctx):
    make_variables = {
        "RUSTFMT": ctx.file.rustfmt.path,
        "RUSTFMT_RLOCATIONPATH": rlocationpath(ctx.file.rustfmt, ctx.workspace_name),
    }

    if ctx.attr.rustc:
        make_variables.update({
            "RUSTC": ctx.file.rustc.path,
        })

    make_variable_info = platform_common.TemplateVariableInfo(make_variables)

    all_files = [ctx.file.rustfmt] + ctx.files.rustc_lib
    if ctx.file.rustc:
        all_files.append(ctx.file.rustc)

    toolchain = platform_common.ToolchainInfo(
        rustfmt = ctx.file.rustfmt,
        rustc = ctx.file.rustc,
        rustc_lib = depset(ctx.files.rustc_lib),
        all_files = depset(all_files),
        make_variables = make_variable_info,
    )

    return [
        toolchain,
        make_variable_info,
    ]

rustfmt_toolchain = rule(
    doc = "A toolchain for [rustfmt](https://rust-lang.github.io/rustfmt/)",
    implementation = _rustfmt_toolchain_impl,
    attrs = {
        "rustc": attr.label(
            doc = "The location of the `rustc` binary. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
            cfg = "exec",
        ),
        "rustc_lib": attr.label(
            doc = "The libraries used by rustc during compilation.",
            cfg = "exec",
        ),
        "rustfmt": attr.label(
            doc = "The location of the `rustfmt` binary. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
            cfg = "exec",
            mandatory = True,
        ),
    },
    toolchains = [
        str(Label("@rules_rust//rust:toolchain_type")),
    ],
)

def _current_rustfmt_toolchain_impl(ctx):
    toolchain = ctx.toolchains[str(Label("@rules_rust//rust/rustfmt:toolchain_type"))]

    return [
        toolchain,
        toolchain.make_variables,
        DefaultInfo(
            files = depset([
                toolchain.rustfmt,
            ]),
            runfiles = ctx.runfiles(transitive_files = toolchain.all_files),
        ),
    ]

current_rustfmt_toolchain = rule(
    doc = "A rule for exposing the current registered `rustfmt_toolchain`.",
    implementation = _current_rustfmt_toolchain_impl,
    toolchains = [
        str(Label("@rules_rust//rust/rustfmt:toolchain_type")),
    ],
)
