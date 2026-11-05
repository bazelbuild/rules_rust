"""The `rustdoc_toolchain` rule and helpers for rules which run rustdoc."""

load("//rust/private:common.bzl", "rust_common")
load("//rust/private:lint_test.bzl", "rlocationpath")
load("//rust/private:sysroot.bzl", "companion_rust_toolchain", "companion_rust_toolchain_attrs", "derive_sysroot", "expand_toolchain_flags")

def _rustdoc_toolchain_impl(ctx):
    # `rustdoc` is a rustc driver: it loads `librustc_driver` from `../lib`
    # relative to itself, and to build doctests it runs the `rustc` it finds
    # beside itself, never one named through `--sysroot`. The toolchain
    # therefore derives a sysroot of its own from the one of its
    # `rust_toolchain`, mirroring it and adding `bin/rustdoc`. Actions which
    # run `rustdoc` use this sysroot alone. See `//rust/private:sysroot.bzl`.
    rust_toolchain = companion_rust_toolchain(ctx, "rustdoc")
    sysroot = derive_sysroot(
        ctx = ctx,
        name = ctx.label.name,
        base_path = rust_toolchain.sysroot,
        base_files = rust_toolchain.sysroot_files,
        bins = [ctx.file.rustdoc],
    )
    rustdoc = sysroot.bins[ctx.file.rustdoc.basename]
    rustc = sysroot.mirrored["bin/" + rust_toolchain.rustc.basename]

    make_variables = {
        "RUSTDOC": rustdoc.path,
        "RUSTDOC_RLOCATIONPATH": rlocationpath(rustdoc, ctx.workspace_name),
    }
    make_variable_info = platform_common.TemplateVariableInfo(make_variables)

    toolchain = platform_common.ToolchainInfo(
        rustdoc = rustdoc,
        # The `rustc` of this sysroot, for actions which run both from it.
        rustc = rustc,
        extra_rustdoc_flags = expand_toolchain_flags(ctx = ctx, attr_name = "extra_rustdoc_flags", rust_toolchain = rust_toolchain, make_variables = make_variables),
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

rustdoc_toolchain = rule(
    doc = """\
A toolchain providing [rustdoc](https://doc.rust-lang.org/rustdoc/).

`rust_doc` and `rust_doc_test` resolve `@rules_rust//rust/rustdoc:toolchain_type`
and run the `rustdoc` it provides. Build scripts do not see it by default; a
`cargo_build_script` which needs `rustdoc` lists
`@rules_rust//rust/toolchain:current_rustdoc_toolchain` in `toolchains` and sets
`RUSTDOC` to `$(RUSTDOC)` in `build_script_env`.

The toolchain derives its sysroot from the one of its `rust_toolchain`: the
same `rustc`, libraries and standard library, plus `bin/rustdoc`. `rustdoc` is
a rustc driver which loads `librustc_driver` from beside itself and builds
doctests with the `rustc` beside itself, so actions running `rustdoc` use the
derived sysroot, and that sysroot is complete even where symlinks are
materialized as copies.

`rustdoc` must come from the same Rust release as `rustc`. The `rust` module
extension declares one `rustdoc_toolchain` in the repository of every
`rust_toolchain` it registers, bound to it through `rust_toolchain`, and
registers the two together. A `rustdoc_toolchain` which leaves
`rust_toolchain` unset derives from the `rust_toolchain` resolved for
`@rules_rust//rust:toolchain_type` instead and states its release through
`version`, `iso_date` and `channel`, which the resolved toolchain must agree
with; the two ways exclude each other. Either way the toolchain advertises
the `version`, `iso_date` and `channel` of the `rust_toolchain` it derives
from. A rule which runs `rustdoc` resolves both toolchain types and
`find_rustdoc` checks that the `rustdoc_toolchain` derives from the
`rust_toolchain` the rule resolved. When it does not, as when a
`rust_toolchain` is registered on its own ahead of the generated ones, the
rule falls back to the deprecated `rust_doc` of that `rust_toolchain`, or
fails when it is unset. That attribute is deprecated in favor of this rule and
is consulted only in that case or when no `rustdoc_toolchain` is registered at
all.

`$(RUSTDOC)` and `$(RUSTDOC_RLOCATIONPATH)` are available as Make variables to
targets which list `@rules_rust//rust/toolchain:current_rustdoc_toolchain`, a
`rustdoc_toolchain_alias`, in `toolchains`.
""",
    implementation = _rustdoc_toolchain_impl,
    attrs = dict({
        "extra_rustdoc_flags": attr.string_list(
            doc = (
                "Extra flags to pass to `rustdoc`. They follow the `rust_toolchain`'s `extra_rustc_flags` and " +
                "precede the flags of the target and the command line. Subject to Make variable expansion with " +
                "respect to the `rust_toolchain`'s variables (`RUST_SYSROOT`, `RUSTC`, ...) and `RUSTDOC`."
            ),
        ),
        "rustdoc": attr.label(
            doc = "The `rustdoc` binary. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
            cfg = "exec",
            mandatory = True,
        ),
    }, **companion_rust_toolchain_attrs("rustdoc")),
    toolchains = [
        config_common.toolchain_type(rust_common.toolchain_type, mandatory = False),
    ],
)

def _rustdoc_toolchain_alias_impl(ctx):
    # Resolved as a rule running rustdoc would, so that the alias stands in
    # for the deprecated `rust_toolchain.rust_doc` wherever `find_rustdoc`
    # falls back to it.
    toolchain = find_rustdoc(ctx, ctx.toolchains[rust_common.toolchain_type])
    if not toolchain:
        if ctx.attr.mandatory:
            fail("{}: no `rustdoc_toolchain` is registered for the current platform".format(ctx.label))
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

rustdoc_toolchain_alias = rule(
    doc = """\
A target standing in for the `rustdoc_toolchain` resolved for the current platform.

The alias forwards the toolchain's providers, its Make variables (`$(RUSTDOC)`,
`$(RUSTDOC_RLOCATIONPATH)`) and its files: the sysroot `rustdoc` runs from, so
that it runs from a `genrule`'s `tools` on any executor.
`@rules_rust//rust/toolchain:current_rustdoc_toolchain` is the alias
`rules_rust` declares.

This follows `cc_toolchain_alias` from `rules_cc`.
""",
    implementation = _rustdoc_toolchain_alias_impl,
    attrs = {
        "mandatory": attr.bool(
            doc = "Whether to fail when no toolchain is registered. When `False`, the target provides nothing instead.",
            default = True,
        ),
    },
    toolchains = [
        config_common.toolchain_type(rust_common.rustdoc_toolchain_type, mandatory = False),
        config_common.toolchain_type(rust_common.toolchain_type, mandatory = False),
    ],
)

def find_rustdoc(ctx, rust_toolchain):
    """The `rustdoc_toolchain` a rule should run rustdoc from.

    The registered `rustdoc_toolchain` is preferred when its sysroot derives
    from the `rust_toolchain` the rule resolved. When it derives from another
    one, or none is registered, an equivalent toolchain is made from the
    deprecated `rust_doc` of the `rust_toolchain`, running from that
    toolchain's sysroot, which is how rules found rustdoc before
    `@rules_rust//rust/rustdoc:toolchain_type` existed. A `rustdoc_toolchain`
    of another `rust_toolchain` with nothing to fall back to is an error: its
    `rustdoc` would load that other `rustc`'s libraries.

    Args:
        ctx (ctx): The rule context. The rule must list
            `config_common.toolchain_type(rust_common.rustdoc_toolchain_type, mandatory = False)`
            in `toolchains`.
        rust_toolchain (ToolchainInfo): The resolved `rust_toolchain`, or `None`.

    Returns:
        ToolchainInfo: A `rustdoc_toolchain`, or `None` when neither toolchain provides rustdoc.
    """
    rustdoc_toolchain = ctx.toolchains[rust_common.rustdoc_toolchain_type]
    deprecated_rustdoc = rust_toolchain.rust_doc if rust_toolchain else None

    # Compared by path: a `rust_toolchain` reached through the companion's
    # `rust_toolchain` attribute and through toolchain resolution are two
    # configured targets sharing one sysroot, and `File`s of each differ.
    if rustdoc_toolchain and rust_toolchain and rustdoc_toolchain.rust_sysroot_anchor.path != rust_toolchain.sysroot_anchor.path:
        if not deprecated_rustdoc:
            fail((
                "{}: the registered `rustdoc_toolchain` derives from the `rust_toolchain` sysroot {} but the " +
                "`rust_toolchain` resolved for this target is {}, and that `rust_toolchain` sets no " +
                "`rust_doc` to fall back to. Register a `rustdoc_toolchain` whose `rust_toolchain` is " +
                "the one in use, alongside it and with the same constraints and target settings."
            ).format(ctx.label, rustdoc_toolchain.rust_sysroot_anchor.dirname, rust_toolchain.sysroot))
        rustdoc_toolchain = None
    if rustdoc_toolchain:
        return rustdoc_toolchain

    if not deprecated_rustdoc:
        return None
    return rustdoc_toolchain_from_binary(ctx, rust_toolchain, deprecated_rustdoc)

def rustdoc_toolchain_from_binary(ctx, rust_toolchain, rustdoc):
    """A `rustdoc_toolchain` equivalent for a `rustdoc` which runs from the `rust_toolchain`'s sysroot.

    This is how rules ran rustdoc before `@rules_rust//rust/rustdoc:toolchain_type`
    existed: the binary is the only extra input, and it must find
    `librustc_driver` and `rustc` on its own, as the deprecated `rust_doc` of
    `rust_toolchain` does by living in that toolchain's sysroot.

    Args:
        ctx (ctx): The rule context.
        rust_toolchain (ToolchainInfo): The resolved `rust_toolchain`.
        rustdoc (File): The `rustdoc` to run.

    Returns:
        ToolchainInfo: A `rustdoc_toolchain`.
    """
    return platform_common.ToolchainInfo(
        rustdoc = rustdoc,
        rustc = rust_toolchain.rustc,
        extra_rustdoc_flags = [],
        sysroot = rust_toolchain.sysroot,
        sysroot_anchor = rust_toolchain.sysroot_anchor,
        sysroot_short_path = rust_toolchain.sysroot_short_path,
        rust_sysroot_anchor = rust_toolchain.sysroot_anchor,
        # As for a derived sysroot, `all_files` is the whole tree `rustdoc`
        # runs from, here the `rust_toolchain`'s, plus the tool.
        all_files = depset([rustdoc], transitive = [rust_toolchain.sysroot_files]),
        make_variables = platform_common.TemplateVariableInfo({
            "RUSTDOC": rustdoc.path,
            "RUSTDOC_RLOCATIONPATH": rlocationpath(rustdoc, ctx.workspace_name),
        }),
        version = rust_toolchain.version,
        iso_date = rust_toolchain.iso_date,
        channel = rust_toolchain.channel,
    )
