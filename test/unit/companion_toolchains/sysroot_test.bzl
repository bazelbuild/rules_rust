"""Tests that generated sysroots are equivalent to a copied distribution.

`materialized_sysroot_test` copies a sysroot with every symlink dereferenced,
as a remote executor would see it, and runs the tools from the copy. It runs
against the toolchains rules_rust generates and against toolchains built from
`@rules_rust_test_symlinked_rust`, a hand-crafted distribution reached entirely through
relative symlinks, with a nested package root and its standard library
under a separate package.
"""

load("@rules_rust_test_symlinked_rust//:host.bzl", "HOST_TRIPLE")
load("//rust:clippy_toolchain.bzl", "clippy_toolchain")
load("//rust:defs.bzl", "rust_common", "rust_test")
load("//rust:rustdoc_toolchain.bzl", "rustdoc_toolchain")
load("//rust:toolchain.bzl", "rust_toolchain")
load("//rust/platform:triple.bzl", "triple")
load(
    "//rust/platform:triple_mappings.bzl",
    "system_to_binary_ext",
    "system_to_dylib_ext",
    "system_to_staticlib_ext",
    "system_to_stdlib_linkflags",
    "triple_to_constraint_set",
)

_SYMLINKED_DISTRIBUTION = "@rules_rust_test_symlinked_rust"

def _with_extra_toolchains_impl(settings, attr):
    return {
        "//command_line_option:extra_toolchains": [str(label) for label in attr.extra_toolchains] + settings["//command_line_option:extra_toolchains"],
    }

_with_extra_toolchains = transition(
    implementation = _with_extra_toolchains_impl,
    inputs = ["//command_line_option:extra_toolchains"],
    outputs = ["//command_line_option:extra_toolchains"],
)

def _sysroot_for_test_impl(ctx):
    """Resolve the toolchains under `extra_toolchains` and expose one sysroot."""
    rust_toolchain = ctx.toolchains[rust_common.toolchain_type]
    if ctx.attr.kind == "rust":
        anchor = rust_toolchain.sysroot_anchor
        files = rust_toolchain.sysroot_files
    elif ctx.attr.kind == "rustdoc":
        toolchain = ctx.toolchains[rust_common.rustdoc_toolchain_type]
        anchor = toolchain.sysroot_anchor
        files = toolchain.all_files
    else:
        toolchain = ctx.toolchains[rust_common.clippy_toolchain_type]
        anchor = toolchain.sysroot_anchor
        files = toolchain.all_files

    # `files` is the anchor alone so that `$(rlocationpath)` names it; the
    # whole sysroot travels as runfiles.
    return [DefaultInfo(
        files = depset([anchor]),
        runfiles = ctx.runfiles(transitive_files = files),
    )]

toolchain_sysroot = rule(
    implementation = _sysroot_for_test_impl,
    doc = "The sysroot of a toolchain resolved with `extra_toolchains` registered first.",
    attrs = {
        "extra_toolchains": attr.label_list(
            doc = "`toolchain` targets to register ahead of the configured ones.",
        ),
        "kind": attr.string(
            doc = "Which toolchain's sysroot to expose.",
            values = ["rust", "rustdoc", "clippy"],
            mandatory = True,
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    cfg = _with_extra_toolchains,
    toolchains = [
        config_common.toolchain_type(rust_common.toolchain_type),
        config_common.toolchain_type(rust_common.rustdoc_toolchain_type),
        config_common.toolchain_type(rust_common.clippy_toolchain_type),
    ],
)

def symlinked_distribution_toolchains(name):
    """Declare a `rust_toolchain` and its companions over the symlinked distribution.

    Args:
        name (str): A prefix for the targets.

    Returns:
        list[str]: The labels of the `toolchain` targets, for `extra_toolchains`.
    """
    host = triple(HOST_TRIPLE)
    constraints = triple_to_constraint_set(HOST_TRIPLE)
    dist = _SYMLINKED_DISTRIBUTION + "//nested/dist"

    rust_toolchain(
        name = name + "_rust_toolchain",
        binary_ext = system_to_binary_ext(host.system),
        dylib_ext = system_to_dylib_ext(host.system),
        exec_triple = HOST_TRIPLE,
        rust_std = "{}//stdlib/{}:rust_std".format(_SYMLINKED_DISTRIBUTION, HOST_TRIPLE),
        rustc = dist + ":rustc",
        rustc_lib = dist + ":rustc_lib",
        staticlib_ext = system_to_staticlib_ext(host.system, host.abi),
        stdlib_linkflags = system_to_stdlib_linkflags(host.system, host.abi),
        target_triple = HOST_TRIPLE,
        tags = ["manual"],
    )
    rustdoc_toolchain(
        name = name + "_rustdoc_toolchain",
        rustdoc = dist + ":rustdoc",
        tags = ["manual"],
    )
    clippy_toolchain(
        name = name + "_clippy_toolchain",
        cargo_clippy = dist + ":cargo_clippy",
        clippy_driver = dist + ":clippy_driver",
        tags = ["manual"],
    )

    labels = []
    for kind, toolchain_type in (
        ("rust", "@rules_rust//rust:toolchain_type"),
        ("rustdoc", "@rules_rust//rust/rustdoc:toolchain_type"),
        ("clippy", "@rules_rust//rust/clippy:toolchain_type"),
    ):
        native.toolchain(
            name = "{}_{}".format(name, kind),
            exec_compatible_with = constraints,
            target_compatible_with = constraints,
            toolchain = ":{}_{}_toolchain".format(name, kind),
            toolchain_type = toolchain_type,
        )
        labels.append(":{}_{}".format(name, kind))
    return labels

def materialized_sysroot_test(name, kind, extra_toolchains = []):
    """Run the tools of a sysroot from a copy with every symlink dereferenced.

    Args:
        name (str): The name of the test.
        kind (str): `rust`, `rustdoc` or `clippy`: whose sysroot to test.
        extra_toolchains (list[str]): `toolchain` targets to register first.
    """
    toolchain_sysroot(
        name = name + "_sysroot",
        extra_toolchains = extra_toolchains,
        kind = kind,
        tags = ["manual"],
    )
    rust_test(
        name = name,
        srcs = ["materialized_sysroot_test.rs"],
        crate_name = "materialized_sysroot_test",
        data = [
            ":" + name + "_sysroot",
            "@rust_host_tools//:clippy_driver_bin",
            "@rust_host_tools//:rust_std-" + HOST_TRIPLE,
            "@rust_host_tools//:rustc",
            "@rust_host_tools//:rustc_lib",
            "@rust_host_tools//:rustdoc",
        ],
        edition = "2021",
        env = {
            "KIND": kind,
            "REAL_RUSTC": "$(rlocationpath @rust_host_tools//:rustc)",
            "SYSROOT_ANCHOR": "$(rlocationpath :{}_sysroot)".format(name),
        },
        deps = ["//rust/runfiles"],
    )

def sysroot_test_suite(name):
    """Materialized-sysroot tests for the generated toolchains and those built from the symlinked distribution.

    Args:
        name (str): The name of the test suite.
    """
    symlinked = symlinked_distribution_toolchains("symlinked_distribution")

    tests = []
    for kind in ("rust", "rustdoc", "clippy"):
        generated = "generated_{}_materialized_sysroot_test".format(kind)
        materialized_sysroot_test(name = generated, kind = kind)
        tests.append(":" + generated)

        symlinked_test = "symlinked_distribution_{}_materialized_sysroot_test".format(kind)
        materialized_sysroot_test(name = symlinked_test, kind = kind, extra_toolchains = symlinked)
        tests.append(":" + symlinked_test)

    native.test_suite(
        name = name,
        tests = tests,
    )
