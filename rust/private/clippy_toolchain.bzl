"""The `clippy_toolchain` rule and helpers for rules which run Clippy."""

load("//rust/private:common.bzl", "rust_common")
load("//rust/private:lint_test.bzl", "rlocationpath")
load("//rust/private:sysroot.bzl", "companion_rust_toolchain", "companion_rust_toolchain_attrs", "derive_sysroot", "expand_toolchain_flags")

def _clippy_toolchain_impl(ctx):
    # `clippy-driver` is a rustc driver: it loads `librustc_driver` from
    # `../lib` relative to itself. The toolchain derives a sysroot of its own
    # from the one of its `rust_toolchain`, mirroring it and adding its
    # binaries to `bin/`. Actions which run Clippy use this sysroot alone.
    # See `//rust/private:sysroot.bzl`.
    rust_toolchain = companion_rust_toolchain(ctx, "clippy")
    bins = [ctx.file.clippy_driver]
    if ctx.file.cargo_clippy:
        bins.append(ctx.file.cargo_clippy)
    sysroot = derive_sysroot(
        ctx = ctx,
        name = ctx.label.name,
        base_path = rust_toolchain.sysroot,
        base_files = rust_toolchain.sysroot_files,
        bins = bins,
    )
    clippy_driver = sysroot.bins[ctx.file.clippy_driver.basename]
    cargo_clippy = sysroot.bins[ctx.file.cargo_clippy.basename] if ctx.file.cargo_clippy else None
    rustc = sysroot.mirrored["bin/" + rust_toolchain.rustc.basename]

    make_variables = {
        "CLIPPY_DRIVER": clippy_driver.path,
        "CLIPPY_DRIVER_RLOCATIONPATH": rlocationpath(clippy_driver, ctx.workspace_name),
    }
    if cargo_clippy:
        make_variables.update({
            "CARGO_CLIPPY": cargo_clippy.path,
            "CARGO_CLIPPY_RLOCATIONPATH": rlocationpath(cargo_clippy, ctx.workspace_name),
        })
    make_variable_info = platform_common.TemplateVariableInfo(make_variables)

    toolchain = platform_common.ToolchainInfo(
        clippy_driver = clippy_driver,
        cargo_clippy = cargo_clippy,
        # The `rustc` of this sysroot, for actions which run both from it.
        rustc = rustc,
        extra_clippy_flags = expand_toolchain_flags(ctx = ctx, attr_name = "extra_clippy_flags", rust_toolchain = rust_toolchain, make_variables = make_variables),
        sysroot = sysroot.path,
        sysroot_anchor = sysroot.anchor,
        sysroot_short_path = sysroot.short_path,
        # The sysroot this one was derived from, so consumers can check that
        # the `rust_toolchain` they resolved is the same one.
        rust_sysroot_anchor = rust_toolchain.sysroot_anchor,
        all_files = sysroot.files,
        make_variables = make_variable_info,
        version = rust_toolchain.version,
        iso_date = rust_toolchain.iso_date,
        channel = rust_toolchain.channel,
    )

    return [
        toolchain,
        make_variable_info,
    ]

clippy_toolchain = rule(
    doc = """\
A toolchain providing [Clippy](https://doc.rust-lang.org/clippy/).

`rust_clippy_aspect`, `rust_clippy` and `rust_clippy_test` resolve
`@rules_rust//rust/clippy:toolchain_type` and run the `clippy-driver` it
provides.

The toolchain derives its sysroot from the one of its `rust_toolchain`: the
same `rustc`, libraries and standard library, plus `bin/clippy-driver` and
`bin/cargo-clippy`. `clippy-driver` is a rustc driver which loads
`librustc_driver` from beside itself, so actions running Clippy use the derived
sysroot, and that sysroot is complete even where symlinks are materialized as
copies.

`clippy-driver` must come from the same Rust release as `rustc`. The `rust`
module extension declares one `clippy_toolchain` in the repository of every
`rust_toolchain` it registers, bound to it through `rust_toolchain`, and
registers the two together. A `clippy_toolchain` which leaves `rust_toolchain`
unset derives from the `rust_toolchain` resolved for
`@rules_rust//rust:toolchain_type` instead and states its release through
`version`, `iso_date` and `channel`, which the resolved toolchain must agree
with; the two ways exclude each other. Either way the toolchain advertises
the `version`, `iso_date` and `channel` of the `rust_toolchain` it derives
from. A rule which runs Clippy resolves both toolchain types and `find_clippy`
checks that the `clippy_toolchain` derives from the `rust_toolchain` the rule
resolved. When it does not, as when a
`rust_toolchain` is registered on its own ahead of the generated ones, the
rule falls back to the deprecated `clippy_driver` and `cargo_clippy` of that
`rust_toolchain`, or fails when they are unset. Those attributes are
deprecated in favor of this rule and are consulted only in that case or when
no `clippy_toolchain` is registered at all.

`$(CLIPPY_DRIVER)`, `$(CLIPPY_DRIVER_RLOCATIONPATH)` and, when `cargo_clippy`
is set, `$(CARGO_CLIPPY)` and `$(CARGO_CLIPPY_RLOCATIONPATH)` are available as
Make variables to targets which list
`@rules_rust//rust/toolchain:current_clippy_toolchain`, a
`clippy_toolchain_alias`, in `toolchains`.
""",
    implementation = _clippy_toolchain_impl,
    attrs = dict({
        "cargo_clippy": attr.label(
            doc = "The `cargo-clippy` binary. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
            cfg = "exec",
        ),
        "clippy_driver": attr.label(
            doc = "The `clippy-driver` binary. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
            cfg = "exec",
            mandatory = True,
        ),
        "extra_clippy_flags": attr.string_list(
            doc = (
                "Extra flags to pass to `clippy-driver`. They follow the `rust_toolchain`'s `extra_rustc_flags` " +
                "and precede the lints of the target and the flags of the command line. Subject to Make variable " +
                "expansion with respect to the `rust_toolchain`'s variables (`RUST_SYSROOT`, `RUSTC`, ...) and " +
                "`CLIPPY_DRIVER`."
            ),
        ),
    }, **companion_rust_toolchain_attrs("clippy")),
    toolchains = [
        config_common.toolchain_type(rust_common.toolchain_type, mandatory = False),
    ],
)

def _clippy_toolchain_alias_impl(ctx):
    # Resolved as a rule running Clippy would, so that the alias stands in
    # for the deprecated `rust_toolchain.clippy_driver` wherever `find_clippy`
    # falls back to it.
    toolchain = find_clippy(ctx, ctx.toolchains[rust_common.toolchain_type])
    if not toolchain:
        if ctx.attr.mandatory:
            fail("{}: no `clippy_toolchain` is registered for the current platform".format(ctx.label))
        return []

    return [
        toolchain,
        toolchain.make_variables,
        # A `genrule` sees only the `files` of its `tools`, and this rule is
        # not executable so its runfiles are never used. The whole sysroot has
        # to be in `files`.
        DefaultInfo(
            files = toolchain.all_files,
            runfiles = ctx.runfiles(transitive_files = toolchain.all_files),
        ),
    ]

clippy_toolchain_alias = rule(
    doc = """\
A target standing in for the `clippy_toolchain` resolved for the current platform.

The alias forwards the toolchain's providers, its Make variables
(`$(CLIPPY_DRIVER)`, `$(CARGO_CLIPPY)`, ...) and its files: the sysroot
`clippy-driver` runs from, so that it runs from a `genrule`'s `tools` on any
executor. `@rules_rust//rust/toolchain:current_clippy_toolchain` is the alias
`rules_rust` declares.

This follows `cc_toolchain_alias` from `rules_cc`.
""",
    implementation = _clippy_toolchain_alias_impl,
    attrs = {
        "mandatory": attr.bool(
            doc = "Whether to fail when no toolchain is registered. When `False`, the target provides nothing instead.",
            default = True,
        ),
    },
    toolchains = [
        config_common.toolchain_type(rust_common.clippy_toolchain_type, mandatory = False),
        config_common.toolchain_type(rust_common.toolchain_type, mandatory = False),
    ],
)

def find_clippy(ctx, rust_toolchain):
    """The `clippy_toolchain` a rule should run Clippy from.

    The registered `clippy_toolchain` is preferred when its sysroot derives
    from the `rust_toolchain` the rule resolved. When it derives from another
    one, or none is registered, an equivalent toolchain is made from the
    deprecated `clippy_driver` and `cargo_clippy` of the `rust_toolchain`,
    running from that toolchain's sysroot, which is how rules found Clippy
    before `@rules_rust//rust/clippy:toolchain_type` existed. A
    `clippy_toolchain` of another `rust_toolchain` with nothing to fall back
    to is an error: its `clippy-driver` would load that other `rustc`'s
    libraries.

    Args:
        ctx (ctx): The rule context. The rule must list
            `config_common.toolchain_type(rust_common.clippy_toolchain_type, mandatory = False)`
            in `toolchains`.
        rust_toolchain (ToolchainInfo): The resolved `rust_toolchain`, or `None`.

    Returns:
        ToolchainInfo: A `clippy_toolchain`, or `None` when neither toolchain provides Clippy.
    """
    clippy_toolchain = ctx.toolchains[rust_common.clippy_toolchain_type]
    deprecated_driver = rust_toolchain.clippy_driver if rust_toolchain else None

    # Compared by path: a `rust_toolchain` reached through the companion's
    # `rust_toolchain` attribute and through toolchain resolution are two
    # configured targets sharing one sysroot, and `File`s of each differ.
    if clippy_toolchain and rust_toolchain and clippy_toolchain.rust_sysroot_anchor.path != rust_toolchain.sysroot_anchor.path:
        if not deprecated_driver:
            fail((
                "{}: the registered `clippy_toolchain` derives from the `rust_toolchain` sysroot {} but the " +
                "`rust_toolchain` resolved for this target is {}, and that `rust_toolchain` sets no " +
                "`clippy_driver` to fall back to. Register a `clippy_toolchain` whose `rust_toolchain` is " +
                "the one in use, alongside it and with the same constraints and target settings."
            ).format(ctx.label, clippy_toolchain.rust_sysroot_anchor.dirname, rust_toolchain.sysroot))
        clippy_toolchain = None
    if clippy_toolchain:
        return clippy_toolchain

    if not deprecated_driver:
        return None
    return clippy_toolchain_from_driver(ctx, rust_toolchain, deprecated_driver, rust_toolchain.cargo_clippy)

def clippy_toolchain_from_driver(ctx, rust_toolchain, clippy_driver, cargo_clippy = None):
    """A `clippy_toolchain` equivalent for a `clippy-driver` which runs from the `rust_toolchain`'s sysroot.

    This is how rules ran Clippy before `@rules_rust//rust/clippy:toolchain_type`
    existed: the driver is the only extra input, and it must find
    `librustc_driver` on its own, as the deprecated `clippy_driver` of
    `rust_toolchain` does by living in that toolchain's sysroot.

    Args:
        ctx (ctx): The rule context.
        rust_toolchain (ToolchainInfo): The resolved `rust_toolchain`.
        clippy_driver (File): The `clippy-driver` to run.
        cargo_clippy (File, optional): A `cargo-clippy` to go with it.

    Returns:
        ToolchainInfo: A `clippy_toolchain`.
    """
    make_variables = {
        "CLIPPY_DRIVER": clippy_driver.path,
        "CLIPPY_DRIVER_RLOCATIONPATH": rlocationpath(clippy_driver, ctx.workspace_name),
    }
    if cargo_clippy:
        make_variables.update({
            "CARGO_CLIPPY": cargo_clippy.path,
            "CARGO_CLIPPY_RLOCATIONPATH": rlocationpath(cargo_clippy, ctx.workspace_name),
        })
    return platform_common.ToolchainInfo(
        clippy_driver = clippy_driver,
        cargo_clippy = cargo_clippy,
        rustc = rust_toolchain.rustc,
        extra_clippy_flags = [],
        sysroot = rust_toolchain.sysroot,
        sysroot_anchor = rust_toolchain.sysroot_anchor,
        sysroot_short_path = rust_toolchain.sysroot_short_path,
        rust_sysroot_anchor = rust_toolchain.sysroot_anchor,
        # As for a derived sysroot, `all_files` is the whole tree the driver
        # runs from, here the `rust_toolchain`'s, plus the tools.
        all_files = depset([f for f in [clippy_driver, cargo_clippy] if f], transitive = [rust_toolchain.sysroot_files]),
        make_variables = platform_common.TemplateVariableInfo(make_variables),
        version = rust_toolchain.version,
        iso_date = rust_toolchain.iso_date,
        channel = rust_toolchain.channel,
    )
