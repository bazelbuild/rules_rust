"""The `cargo_toolchain` rule and helpers for rules which run Cargo."""

# buildifier: disable=bzl-visibility
load("//rust/private:common.bzl", "rust_common")

# buildifier: disable=bzl-visibility
load("//rust/private:lint_test.bzl", "rlocationpath")

def _cargo_toolchain_impl(ctx):
    cargo = ctx.file.cargo

    make_variables = {
        "CARGO": cargo.path,
        "CARGO_RLOCATIONPATH": rlocationpath(cargo, ctx.workspace_name),
    }
    make_variable_info = platform_common.TemplateVariableInfo(make_variables)

    toolchain = platform_common.ToolchainInfo(
        cargo = cargo,
        all_files = depset([cargo]),
        make_variables = make_variable_info,
        version = ctx.attr.version,
        iso_date = ctx.attr.iso_date,
        channel = ctx.attr.channel,
    )

    return [
        toolchain,
        make_variable_info,
    ]

cargo_toolchain = rule(
    doc = """\
A toolchain providing a [Cargo](https://doc.rust-lang.org/cargo/) binary.

Rules which run Cargo on the execution platform, such as `crates_vendor` and
`cargo_build_script`, resolve `@rules_rust//cargo:toolchain_type` and use the
binary it provides. The toolchain carries Cargo alone, so compile actions,
which never run Cargo, do not depend on it.

Cargo is released together with `rustc` and is only tested against the
compiler it shipped with, so the `rust` module extension declares a
`cargo_toolchain` in the same repository as every `rust_toolchain` it
registers and registers the two with the same constraints and channel setting.
The toolchain carries the same `version`, `iso_date` and `channel` identifiers
as `rust_toolchain`; `cargo_build_script` fails when the Cargo and Rust
toolchains it resolves state different ones.

`$(CARGO)` and `$(CARGO_RLOCATIONPATH)` are available as Make variables to
targets which list `@rules_rust//cargo:current_cargo_toolchain`, a
`cargo_toolchain_alias`, in `toolchains`.
""",
    implementation = _cargo_toolchain_impl,
    attrs = {
        "cargo": attr.label(
            doc = "The `cargo` binary. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
            cfg = "exec",
            mandatory = True,
        ),
        "channel": attr.string(
            doc = "The Rust release channel Cargo comes from (`stable`, `nightly`, or `beta`), as in `rust_toolchain.channel`.",
            default = "",
        ),
        "iso_date": attr.string(
            doc = "The ISO date of the nightly or beta release Cargo comes from, as in `rust_toolchain.iso_date`. Empty for stable releases.",
            default = "",
        ),
        "version": attr.string(
            doc = (
                "The version of the Rust release Cargo comes from (e.g. `1.94.1`), as in `rust_toolchain.version`. " +
                "Rules which run Cargo next to `rustc` compare the two; leave empty to opt out."
            ),
            default = "",
        ),
    },
)

def cargo_version_mismatch(cargo_toolchain, rust_toolchain):
    """Describe how a `cargo_toolchain` and a `rust_toolchain` disagree on their release.

    Each of `version`, `iso_date` and `channel` is compared only when both
    toolchains state it, so toolchains which leave them empty are never
    rejected.

    Args:
        cargo_toolchain (ToolchainInfo): The resolved `cargo_toolchain`, or `None`.
        rust_toolchain (ToolchainInfo): The resolved `rust_toolchain`, or `None`.

    Returns:
        str: A description of the mismatch, or `None` when the toolchains agree.
    """
    if not cargo_toolchain or not rust_toolchain:
        return None

    for field in ("version", "iso_date", "channel"):
        cargo_value = getattr(cargo_toolchain, field, "")
        rust_value = getattr(rust_toolchain, field, "")
        if cargo_value and rust_value and cargo_value != rust_value:
            return (
                "the `cargo_toolchain` ({} {}) and the `rust_toolchain` ({} {}) come from different " +
                "Rust releases. Cargo is only tested with the `rustc` it was released with; register " +
                "a `cargo_toolchain` from the same release as the `rust_toolchain`."
            ).format(field, cargo_value, field, rust_value)
    return None

def _cargo_toolchain_alias_impl(ctx):
    toolchain = ctx.toolchains[rust_common.cargo_toolchain_type]
    if not toolchain:
        # Until the deprecated `rust_toolchain.cargo` is removed, stand in for
        # it so that this target resolves wherever `find_cargo` would.
        rust_toolchain = ctx.toolchains[rust_common.toolchain_type]
        if rust_toolchain and rust_toolchain.cargo:
            make_variables = platform_common.TemplateVariableInfo({
                "CARGO": rust_toolchain.cargo.path,
                "CARGO_RLOCATIONPATH": rlocationpath(rust_toolchain.cargo, ctx.workspace_name),
            })
            toolchain = platform_common.ToolchainInfo(
                cargo = rust_toolchain.cargo,
                all_files = depset([rust_toolchain.cargo]),
                make_variables = make_variables,
                version = rust_toolchain.version,
                iso_date = rust_toolchain.iso_date,
                channel = rust_toolchain.channel,
            )
    if not toolchain:
        if ctx.attr.mandatory:
            fail("{}: no `cargo_toolchain` is registered for the current platform".format(ctx.label))
        return []

    return [
        toolchain,
        toolchain.make_variables,
        DefaultInfo(
            files = depset([toolchain.cargo]),
            runfiles = ctx.runfiles(transitive_files = toolchain.all_files),
        ),
    ]

cargo_toolchain_alias = rule(
    doc = """\
A target standing in for the `cargo_toolchain` resolved for the current platform.

The alias forwards the toolchain's providers, its Make variables (`$(CARGO)`,
`$(CARGO_RLOCATIONPATH)`) and the `cargo` binary.
`@rules_rust//cargo:current_cargo_toolchain` is the alias `rules_rust`
declares. While the deprecated `cargo` attribute of `rust_toolchain` exists,
the alias stands in for it when no `cargo_toolchain` is registered.

This follows `cc_toolchain_alias` from `rules_cc`.
""",
    implementation = _cargo_toolchain_alias_impl,
    attrs = {
        "mandatory": attr.bool(
            doc = "Whether to fail when no toolchain is registered. When `False`, the target provides nothing instead.",
            default = True,
        ),
    },
    toolchains = [
        config_common.toolchain_type(rust_common.cargo_toolchain_type, mandatory = False),
        config_common.toolchain_type(rust_common.toolchain_type, mandatory = False),
    ],
)

def find_cargo(ctx, rust_toolchain):
    """The Cargo binary a rule should run, and the files it needs at run time.

    The registered `cargo_toolchain` is preferred. When none is registered the
    `cargo` of the `rust_toolchain` is used, which is how rules found Cargo
    before `@rules_rust//cargo:toolchain_type` existed.

    Args:
        ctx (ctx): The rule context. The rule must list
            `config_common.toolchain_type(rust_common.cargo_toolchain_type, mandatory = False)`
            in `toolchains`.
        rust_toolchain (ToolchainInfo): The resolved `rust_toolchain`, or `None`.

    Returns:
        struct: `cargo`, the binary (a `File`, or `None` when neither toolchain
            provides one), `files`, a `depset` to add to the action's tools, and
            `toolchain`, the `cargo_toolchain` used, or `None` when falling back.
    """
    cargo_toolchain = ctx.toolchains[rust_common.cargo_toolchain_type]
    if cargo_toolchain:
        return struct(cargo = cargo_toolchain.cargo, files = cargo_toolchain.all_files, toolchain = cargo_toolchain)
    cargo = rust_toolchain.cargo if rust_toolchain else None
    return struct(cargo = cargo, files = depset([cargo] if cargo else []), toolchain = None)
