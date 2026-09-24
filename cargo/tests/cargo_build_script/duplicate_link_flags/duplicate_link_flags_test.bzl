"""Check when a package build script's native link flags reach a Rustc action."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//cargo:defs.bzl", "cargo_build_script")
load("//rust:defs.bzl", "rust_binary", "rust_library")

def _link_flags_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    rustc_actions = [action for action in target.actions if action.mnemonic == "Rustc"]
    asserts.equals(env, 1, len(rustc_actions))

    if rustc_actions:
        argv = rustc_actions[0].argv
        link_flags = [
            argv[i + 1]
            for i in range(len(argv) - 1)
            if argv[i] == "--arg-file" and argv[i + 1].endswith("shared_script.linkflags")
        ]
        asserts.equals(env, ctx.attr.expected_count, len(link_flags))

    return analysistest.end(env)

_link_flags_test = analysistest.make(
    _link_flags_test_impl,
    attrs = {"expected_count": attr.int(mandatory = True)},
)

def duplicate_link_flags_test_suite(name):
    """Verify a direct library owns its package build script's native flags.

    Args:
        name: Name of the test suite.
    """
    cargo_build_script(
        name = "shared_script",
        srcs = ["build.rs"],
    )

    rust_library(
        name = "lib",
        srcs = ["lib.rs"],
        deps = [":shared_script"],
    )

    rust_binary(
        name = "bin_with_lib",
        srcs = ["main.rs"],
        deps = [":lib", ":shared_script"],
    )

    rust_binary(
        name = "bin_without_lib",
        srcs = ["main.rs"],
        deps = [":shared_script"],
    )

    _link_flags_test(
        name = "lib_link_flags_test",
        target_under_test = ":lib",
        expected_count = 1,
    )

    _link_flags_test(
        name = "bin_with_lib_link_flags_test",
        target_under_test = ":bin_with_lib",
        expected_count = 0,
    )

    _link_flags_test(
        name = "bin_without_lib_link_flags_test",
        target_under_test = ":bin_without_lib",
        expected_count = 1,
    )

    native.test_suite(
        name = name,
        tests = [
            ":lib_link_flags_test",
            ":bin_with_lib_link_flags_test",
            ":bin_without_lib_link_flags_test",
        ],
    )
