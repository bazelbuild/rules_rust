"""The `clippy_toolchain` rule and helpers for rules which run Clippy."""

load("//rust/private:common.bzl", "rust_common")
load("//rust/private:lint_test.bzl", "rlocationpath")
load("//rust/private:sysroot.bzl", "derive_sysroot", "expand_toolchain_flags")

def _clippy_toolchain_impl(ctx):
    # `clippy-driver` is a rustc driver: it loads `librustc_driver` from
    # `../lib` relative to itself. The toolchain derives a sysroot of its own
    # from the one of the resolved `rust_toolchain`, mirroring it and adding
    # its binaries to `bin/`. Actions which run Clippy use this sysroot alone.
    # See `//rust/private:sysroot.bzl`.
    rust_toolchain = ctx.toolchains[rust_common.toolchain_type]
    bins = [ctx.file.clippy_driver]
    if ctx.file.cargo_clippy:
        bins.append(ctx.file.cargo_clippy)
    sysroot = derive_sysroot(
        ctx,
        ctx.label.name,
        rust_toolchain.sysroot,
        rust_toolchain.sysroot_files,
        bins,
    )
    clippy_driver = sysroot.bins[ctx.file.clippy_driver.basename]
    cargo_clippy = sysroot.bins[ctx.file.cargo_clippy.basename] if ctx.file.cargo_clippy else None

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
        extra_clippy_flags = expand_toolchain_flags(ctx, "extra_clippy_flags", rust_toolchain, make_variables),
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

The toolchain resolves `@rules_rust//rust:toolchain_type` itself and derives
its sysroot from that `rust_toolchain`'s: the same `rustc`, libraries and
standard library, plus `bin/clippy-driver` and `bin/cargo-clippy`.
`clippy-driver` is a rustc driver which loads `librustc_driver` from beside
itself, so the derived sysroot is what actions running Clippy use, and it is
complete on executors which materialize symlinks as copies. Bazel resolves the
`rust_toolchain` for the toolchain's consumer, so the pair always matches;
consumers verify it.

`clippy-driver` must come from the same Rust release as `rustc`. The `rust`
module extension declares one `clippy_toolchain` in the repository of every
`rust_toolchain` it registers and registers the two together. The
`clippy_driver` and `cargo_clippy` attributes of `rust_toolchain` are
deprecated in favor of this rule and are consulted only when no
`clippy_toolchain` is registered.

`$(CLIPPY_DRIVER)`, `$(CLIPPY_DRIVER_RLOCATIONPATH)` and, when `cargo_clippy`
is set, `$(CARGO_CLIPPY)` and `$(CARGO_CLIPPY_RLOCATIONPATH)` are available as
Make variables to targets which list
`@rules_rust//rust/toolchain:current_clippy_toolchain`, a
`clippy_toolchain_alias`, in `toolchains`.
""",
    implementation = _clippy_toolchain_impl,
    attrs = {
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
    },
    toolchains = [
        config_common.toolchain_type(rust_common.toolchain_type),
    ],
)

def _clippy_toolchain_alias_impl(ctx):
    toolchain = ctx.toolchains[rust_common.clippy_toolchain_type]
    if not toolchain:
        if ctx.attr.mandatory:
            fail("{}: no `clippy_toolchain` is registered for the current platform".format(ctx.label))
        return []

    return [
        toolchain,
        toolchain.make_variables,
        # The whole sysroot is in `files`, not only in runfiles: a `genrule`
        # takes the `files` of its `tools` and, this rule not being
        # executable, none of its runfiles.
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
    ],
)

def find_clippy(ctx, rust_toolchain):
    """The `clippy_toolchain` a rule should run Clippy from.

    The registered `clippy_toolchain` is preferred, and its sysroot must derive
    from the `rust_toolchain` the rule resolved; otherwise toolchain resolution
    paired the two inconsistently and the rule fails. When none is registered
    an equivalent toolchain is made from the deprecated `clippy_driver` and
    `cargo_clippy` of the `rust_toolchain`, running from that toolchain's
    sysroot, which is how rules found Clippy before
    `@rules_rust//rust/clippy:toolchain_type` existed.

    Args:
        ctx (ctx): The rule context. The rule must list
            `config_common.toolchain_type(rust_common.clippy_toolchain_type, mandatory = False)`
            in `toolchains`.
        rust_toolchain (ToolchainInfo): The resolved `rust_toolchain`, or `None`.

    Returns:
        ToolchainInfo: A `clippy_toolchain`, or `None` when neither toolchain provides Clippy.
    """
    clippy_toolchain = ctx.toolchains[rust_common.clippy_toolchain_type]
    if clippy_toolchain:
        if rust_toolchain and clippy_toolchain.rust_sysroot_anchor != rust_toolchain.sysroot_anchor:
            fail((
                "{}: the `clippy_toolchain` derives from the `rust_toolchain` sysroot {} but the " +
                "`rust_toolchain` resolved for this target is {}. The two toolchains must resolve " +
                "together; register the `clippy_toolchain` with the same constraints and target " +
                "settings as its `rust_toolchain`."
            ).format(ctx.label, clippy_toolchain.rust_sysroot_anchor.dirname, rust_toolchain.sysroot))
        return clippy_toolchain

    if not rust_toolchain or not rust_toolchain.clippy_driver:
        return None
    clippy_driver = rust_toolchain.clippy_driver
    cargo_clippy = rust_toolchain.cargo_clippy
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
        extra_clippy_flags = [],
        sysroot = rust_toolchain.sysroot,
        sysroot_anchor = rust_toolchain.sysroot_anchor,
        sysroot_short_path = rust_toolchain.sysroot_short_path,
        rust_sysroot_anchor = rust_toolchain.sysroot_anchor,
        # The binaries live in the `rust_toolchain` sysroot, which their
        # consumers already depend on.
        all_files = depset([f for f in [clippy_driver, cargo_clippy] if f]),
        make_variables = platform_common.TemplateVariableInfo(make_variables),
        version = rust_toolchain.version,
        iso_date = rust_toolchain.iso_date,
        channel = rust_toolchain.channel,
    )
