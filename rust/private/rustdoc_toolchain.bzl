"""The `rustdoc_toolchain` rule and helpers for rules which run rustdoc."""

load("//rust/private:common.bzl", "rust_common")
load("//rust/private:lint_test.bzl", "rlocationpath")
load("//rust/private:sysroot.bzl", "derive_sysroot", "expand_toolchain_flags")

def _rustdoc_toolchain_impl(ctx):
    # `rustdoc` is a rustc driver: it loads `librustc_driver` from `../lib`
    # relative to itself, and to build doctests it runs the `rustc` it finds
    # beside itself, never one named through `--sysroot`. The toolchain
    # therefore derives a sysroot of its own from the one of the resolved
    # `rust_toolchain`, mirroring it and adding `bin/rustdoc`. Actions which
    # run `rustdoc` use this sysroot alone. See `//rust/private:sysroot.bzl`.
    rust_toolchain = ctx.toolchains[rust_common.toolchain_type]
    sysroot = derive_sysroot(
        ctx,
        ctx.label.name,
        rust_toolchain.sysroot,
        rust_toolchain.sysroot_files,
        [ctx.file.rustdoc],
    )
    rustdoc = sysroot.bins[ctx.file.rustdoc.basename]

    make_variables = {
        "RUSTDOC": rustdoc.path,
        "RUSTDOC_RLOCATIONPATH": rlocationpath(rustdoc, ctx.workspace_name),
    }
    make_variable_info = platform_common.TemplateVariableInfo(make_variables)

    toolchain = platform_common.ToolchainInfo(
        rustdoc = rustdoc,
        extra_rustdoc_flags = expand_toolchain_flags(ctx, "extra_rustdoc_flags", rust_toolchain, make_variables),
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
and run the `rustdoc` it provides; `cargo_build_script` hands it to build scripts
as `$RUSTDOC`.

The toolchain resolves `@rules_rust//rust:toolchain_type` itself and derives
its sysroot from that `rust_toolchain`'s: the same `rustc`, libraries and
standard library, plus `bin/rustdoc`. `rustdoc` is a rustc driver which loads
`librustc_driver` from beside itself and builds doctests with the `rustc`
beside itself, so the derived sysroot is what actions running `rustdoc` use,
and it is complete on executors which materialize symlinks as copies. Bazel
resolves the `rust_toolchain` for the toolchain's consumer, so the pair always
matches; consumers verify it.

`rustdoc` must come from the same Rust release as `rustc`. The `rust` module
extension declares one `rustdoc_toolchain` in the repository of every
`rust_toolchain` it registers and registers the two together. The `rust_doc`
attribute of `rust_toolchain` is deprecated in favor of this rule and is
consulted only when no `rustdoc_toolchain` is registered.

`$(RUSTDOC)` and `$(RUSTDOC_RLOCATIONPATH)` are available as Make variables to
targets which list `@rules_rust//rust/toolchain:current_rustdoc_toolchain`, a
`rustdoc_toolchain_alias`, in `toolchains`.
""",
    implementation = _rustdoc_toolchain_impl,
    attrs = {
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
    },
    toolchains = [
        config_common.toolchain_type(rust_common.toolchain_type),
    ],
)

def _rustdoc_toolchain_alias_impl(ctx):
    toolchain = ctx.toolchains[rust_common.rustdoc_toolchain_type]
    if not toolchain:
        if ctx.attr.mandatory:
            fail("{}: no `rustdoc_toolchain` is registered for the current platform".format(ctx.label))
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
    ],
)

def find_rustdoc(ctx, rust_toolchain):
    """The `rustdoc_toolchain` a rule should run rustdoc from.

    The registered `rustdoc_toolchain` is preferred, and its sysroot must derive
    from the `rust_toolchain` the rule resolved; otherwise toolchain resolution
    paired the two inconsistently and the rule fails. When none is registered
    an equivalent toolchain is made from the deprecated `rust_doc` of the
    `rust_toolchain`, running from that toolchain's sysroot, which is how rules
    found rustdoc before `@rules_rust//rust/rustdoc:toolchain_type` existed.

    Args:
        ctx (ctx): The rule context. The rule must list
            `config_common.toolchain_type(rust_common.rustdoc_toolchain_type, mandatory = False)`
            in `toolchains`.
        rust_toolchain (ToolchainInfo): The resolved `rust_toolchain`, or `None`.

    Returns:
        ToolchainInfo: A `rustdoc_toolchain`, or `None` when neither toolchain provides rustdoc.
    """
    rustdoc_toolchain = ctx.toolchains[rust_common.rustdoc_toolchain_type]
    if rustdoc_toolchain:
        if rust_toolchain and rustdoc_toolchain.rust_sysroot_anchor != rust_toolchain.sysroot_anchor:
            fail((
                "{}: the `rustdoc_toolchain` derives from the `rust_toolchain` sysroot {} but the " +
                "`rust_toolchain` resolved for this target is {}. The two toolchains must resolve " +
                "together; register the `rustdoc_toolchain` with the same constraints and target " +
                "settings as its `rust_toolchain`."
            ).format(ctx.label, rustdoc_toolchain.rust_sysroot_anchor.dirname, rust_toolchain.sysroot))
        return rustdoc_toolchain

    if not rust_toolchain or not rust_toolchain.rust_doc:
        return None
    rustdoc = rust_toolchain.rust_doc
    return platform_common.ToolchainInfo(
        rustdoc = rustdoc,
        extra_rustdoc_flags = [],
        sysroot = rust_toolchain.sysroot,
        sysroot_anchor = rust_toolchain.sysroot_anchor,
        sysroot_short_path = rust_toolchain.sysroot_short_path,
        rust_sysroot_anchor = rust_toolchain.sysroot_anchor,
        # `rustdoc` lives in the `rust_toolchain` sysroot, which its consumers
        # already depend on.
        all_files = depset([rustdoc]),
        make_variables = platform_common.TemplateVariableInfo({
            "RUSTDOC": rustdoc.path,
            "RUSTDOC_RLOCATIONPATH": rlocationpath(rustdoc, ctx.workspace_name),
        }),
        version = rust_toolchain.version,
        iso_date = rust_toolchain.iso_date,
        channel = rust_toolchain.channel,
    )
