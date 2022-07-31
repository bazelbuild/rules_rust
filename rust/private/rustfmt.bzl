"""A module defining rustfmt rules"""

load(":common.bzl", "rust_common")
load(":utils.bzl", "find_toolchain")

def _find_rustfmtable_srcs(target, aspect_ctx = None):
    """Parse a target for rustfmt formattable sources.

    Args:
        target (Target): The target the aspect is running on.
        aspect_ctx (ctx, optional): The aspect's context object.

    Returns:
        list: A list of formattable sources (`File`).
    """
    if rust_common.crate_info not in target:
        return []

    # Ignore external targets
    if target.label.workspace_root.startswith("external"):
        return []

    if aspect_ctx:
        # Targets with specifc tags will not be formatted
        ignore_tags = [
            "no-format",
            "no-rustfmt",
            "norustfmt",
        ]

        for tag in ignore_tags:
            if tag in aspect_ctx.rule.attr.tags:
                return []

    crate_info = target[rust_common.crate_info]

    # Filter out any generated files
    srcs = [src for src in crate_info.srcs.to_list() if src.is_source]

    return srcs

def _generate_manifest(edition, srcs, ctx):
    # Gather the source paths to non-generated files
    src_paths = [src.path for src in srcs]

    # Write the rustfmt manifest
    manifest = ctx.actions.declare_file(ctx.label.name + ".rustfmt")
    ctx.actions.write(
        output = manifest,
        content = "\n".join(src_paths + [
            edition,
        ]),
    )

    return manifest

def _perform_check(edition, srcs, ctx):
    toolchain = find_toolchain(ctx)
    config = ctx.file._config
    marker = ctx.actions.declare_file(ctx.label.name + ".rustfmt.ok")

    args = ctx.actions.args()
    args.add("--touch-file")
    args.add(marker)
    args.add("--")
    args.add(toolchain.rustfmt)
    args.add("--config-path")
    args.add(config)
    args.add("--edition")
    args.add(edition)
    args.add("--check")
    args.add_all(srcs)

    ctx.actions.run(
        executable = ctx.executable._process_wrapper,
        inputs = srcs + [config],
        outputs = [marker],
        tools = [toolchain.rustfmt],
        arguments = [args],
        mnemonic = "Rustfmt",
    )

    return marker

def _rustfmt_aspect_impl(target, ctx):
    srcs = _find_rustfmtable_srcs(target, ctx)

    # If there are no formattable sources, do nothing.
    if not srcs:
        return []

    # Parse the edition to use for formatting from the target
    edition = target[rust_common.crate_info].edition

    manifest = _generate_manifest(edition, srcs, ctx)
    marker = _perform_check(edition, srcs, ctx)

    return [
        OutputGroupInfo(
            rustfmt_manifest = depset([manifest]),
            rustfmt_checks = depset([marker]),
        ),
    ]

rustfmt_aspect = aspect(
    implementation = _rustfmt_aspect_impl,
    doc = """\
This aspect is used to gather information about a crate for use in rustfmt and perform rustfmt checks

Output Groups:

- `rustfmt_manifest`: A manifest used by rustfmt binaries to provide crate specific settings.
- `rustfmt_checks`: Executes `rustfmt --check` on the specified target.

The build setting `@rules_rust//:rustfmt.toml` is used to control the Rustfmt [configuration settings][cs]
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
            default = Label("//:rustfmt.toml"),
        ),
        "_process_wrapper": attr.label(
            doc = "A process wrapper for running rustfmt on all platforms",
            cfg = "exec",
            executable = True,
            default = Label("//util/process_wrapper"),
        ),
    },
    incompatible_use_toolchain_transition = True,
    fragments = ["cpp"],
    host_fragments = ["cpp"],
    toolchains = [
        str(Label("//rust:toolchain_type")),
    ],
)

def _rustfmt_test_impl(ctx):
    # The executable of a test target must be the output of an action in
    # the rule implementation. This file is simply a symlink to the real
    # rustfmt test runner.
    is_windows = ctx.executable._runner.extension == ".exe"
    runner = ctx.actions.declare_file("{}{}".format(
        ctx.label.name,
        ".exe" if is_windows else "",
    ))

    ctx.actions.symlink(
        output = runner,
        target_file = ctx.executable._runner,
        is_executable = True,
    )

    manifests = depset(transitive = [target[OutputGroupInfo].rustfmt_manifest for target in ctx.attr.targets])
    srcs = [depset(_find_rustfmtable_srcs(target)) for target in ctx.attr.targets]

    runfiles = ctx.runfiles(
        transitive_files = depset(transitive = srcs + [manifests]),
    )

    runfiles = runfiles.merge(
        ctx.attr._runner[DefaultInfo].default_runfiles,
    )

    path_env_sep = ";" if is_windows else ":"

    return [
        DefaultInfo(
            files = depset([runner]),
            runfiles = runfiles,
            executable = runner,
        ),
        testing.TestEnvironment({
            "RUSTFMT_MANIFESTS": path_env_sep.join([
                manifest.short_path
                for manifest in sorted(manifests.to_list())
            ]),
            "RUST_BACKTRACE": "1",
        }),
    ]

rustfmt_test = rule(
    implementation = _rustfmt_test_impl,
    doc = "A test rule for performing `rustfmt --check` on a set of targets",
    attrs = {
        "targets": attr.label_list(
            doc = "Rust targets to run `rustfmt --check` on.",
            providers = [rust_common.crate_info],
            aspects = [rustfmt_aspect],
        ),
        "_runner": attr.label(
            doc = "The rustfmt test runner",
            cfg = "exec",
            executable = True,
            default = Label("//tools/rustfmt:rustfmt_test"),
        ),
    },
    test = True,
)

def _rustfmt_workspace_name_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name)

    ctx.actions.write(
        output = output,
        content = "RUSTFMT_WORKSPACE={}".format(
            ctx.workspace_name,
        ),
    )

    return [DefaultInfo(
        files = depset([output]),
    )]

rustfmt_workspace_name = rule(
    implementation = _rustfmt_workspace_name_impl,
    doc = "A rule for detecting the workspace name for Rustfmt runfiles.",
)
