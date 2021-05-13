"""A module defining rustfmt rules"""

load(":common.bzl", "rust_common")
load(":rust.bzl", "rust_binary")
load(":utils.bzl", "find_toolchain")

def _find_rustfmtable_srcs(target, ctx):
    """Parse a target for rustfmt formattable sources.

    Args:
        target (Target): The target the aspect is running on.
        ctx (ctx): The aspect's context object.

    Returns:
        list: A list of formattable sources (`File`).
    """
    if rust_common.crate_info not in target:
        return []

    # Targets annotated with `norustfmt` will not be formatted
    if "norustfmt" in ctx.rule.attr.tags:
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
        content = "\n".join([
            edition,
        ] + src_paths),
    )

    return manifest

def _perform_check(edition, srcs, ctx):
    toolchain = find_toolchain(ctx)

    marker = ctx.actions.declare_file(ctx.label.name + ".rustfmt.ok")

    args = ctx.actions.args()
    args.add("--touch-file")
    args.add(marker)
    args.add("--")
    args.add(toolchain.rustfmt)
    args.add("--edition")
    args.add(edition)
    args.add("--check")
    args.add_all(srcs)

    ctx.actions.run(
        executable = ctx.executable._process_wrapper,
        inputs = srcs,
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

- `rustfmt_manifest`: The `rustfmt_manifest` output is used directly by [rustfmt](#rustfmt) targets
to determine the appropriate flags to use when formatting Rust sources. For more details on how to
format source code, see the [rustfmt](#rustfmt) rule.

- `rustfmt_checks`: Executes rustfmt in `--check` mode on the specified target. To enable this check
for your workspace, simply add the following to the `.bazelrc` file in the root of any workspace
which loads `rules_rust`:
```
build --aspects=@rules_rust//rust:defs.bzl%rustfmt_aspect
build --output_groups=+rustfmt_checks
```

This aspect is executed on any target which provides the `CrateInfo` provider. However
users may tag a target with `norustfmt` to have it skipped. Additionally, generated
source files are also ignored by this aspect.
""",
    fragments = ["cpp"],
    host_fragments = ["cpp"],
    toolchains = [
        str(Label("//rust:toolchain")),
    ],
    attrs = {
        "_process_wrapper": attr.label(
            doc = "A process wrapper for running rustfmt on all platforms",
            cfg = "exec",
            executable = True,
            default = Label("//util/process_wrapper"),
        ),
    },
    incompatible_use_toolchain_transition = True,
)

def _rustfmt_check_impl(ctx):
    files = depset([], transitive = [target[OutputGroupInfo].rustfmt_checks for target in ctx.attr.targets])
    return [DefaultInfo(files = files)]

rustfmt_check = rule(
    implementation = _rustfmt_check_impl,
    attrs = {
        "targets": attr.label_list(
            doc = "Rust targets to run rustfmt on.",
            providers = [rust_common.crate_info],
            aspects = [rustfmt_aspect],
        ),
    },
    doc = """\
A rule for defining a target which runs `rustfmt` in `--check` mode on an explicit list of targets

For more information on the use of `rustfmt` directly, see [rustfmt_aspect](#rustfmt_aspect).
""",
)

def rustfmt(name, config = Label("//tools/rustfmt:rustfmt.toml")):
    """A macro defining a [rustfmt](https://github.com/rust-lang/rustfmt#readme) runner.

    This macro is used to generate a rustfmt binary which can be run to format the Rust source
    files of `rules_rust` targets in the workspace. To define this target, simply load and call
    it in a BUILD file.

    eg: `//:BUILD.bazel`

    ```python
    load("@rules_rust//rust:defs.bzl", "rustfmt")

    rustfmt(
        name = "rustfmt",
    )
    ```

    This now allows users to run `bazel run //:rustfmt` to format any target which provides `CrateInfo`.

    This binary also supports accepts a [label](https://docs.bazel.build/versions/master/build-ref.html#labels) or
    pattern (`//my/package/...`) to allow for more granular control over what targets get formatted. This
    can be useful when dealing with larger projects as `rustfmt` can only be run on a target which successfully
    builds. Given the following workspace layout:

    ```
    WORKSPACE.bazel
    BUILD.bazel
    package_a/
        BUILD.bazel
        src/
            lib.rs
            mod_a.rs
            mod_b.rs
    package_b/
        BUILD.bazel
        subpackage_1/
            BUILD.bazel
            main.rs
        subpackage_2/
            BUILD.bazel
            main.rs
    ```

    Users can choose to only format the `rust_lib` target in `package_a` using `bazel run //:rustfmt -- //package_a:rust_lib`.
    Additionally, users can format all of `package_b` using `bazel run //:rustfmt -- //package_b/...`.

    Users not looking to add a custom `rustfmt` config can simply run the `@rules_rust//tools/rustfmt` to avoid defining their
    own target.

    Note that generated sources will be ignored and targets tagged as `norustfmt` will be skipped.

    Args:
        name (str): The name of the rustfmt runner
        config (Label, optional): The [rustfmt config](https://rust-lang.github.io/rustfmt/) to use.
    """
    rust_binary(
        name = name,
        data = [
            config,
            Label("//tools/rustfmt:rustfmt_bin"),
        ],
        deps = [
            Label("//util/label"),
        ],
        rustc_env = {
            "RUSTFMT": "$(rootpath {})".format(Label("//tools/rustfmt:rustfmt_bin")),
            "RUSTFMT_CONFIG": "$(rootpath {})".format(config),
        },
        srcs = [
            Label("//tools/rustfmt:srcs"),
        ],
        edition = "2018",
    )
