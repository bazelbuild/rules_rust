"""Tests for `cargo::rustc-cdylib-link-arg` and `cargo::rustc-link-arg-bins`."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("//cargo:defs.bzl", "cargo_build_script")
load("//rust:defs.bzl", "rust_binary", "rust_library", "rust_shared_library", "rust_test")
load("//test/unit:common.bzl", "assert_action_mnemonic")

# The build script's `.cdyliblinkflags` / `.binlinkflags` outputs are passed to
# rustc as `--arg-file <path>` (see `_process_build_scripts`). A flag only reaches
# a consumer when its crate type matches, so the presence of a specific build
# script's arg-file in the Rustc command line is what distinguishes a correctly
# gated (and, for cdylibs, transitively propagated) consumer.
def _has_arg_file(argv, suffix):
    for i in range(len(argv) - 1):
        if argv[i] in ["--arg-file", "--bin-arg-file"] and argv[i + 1].endswith(suffix):
            return True
    return False

def _link_args_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    action = None
    for a in tut.actions:
        if a.mnemonic == "Rustc":
            action = a
            break
    asserts.true(env, action != None, "Expected a Rustc action")
    assert_action_mnemonic(env, action, "Rustc")

    for suffix in ctx.attr.expect_arg_files:
        asserts.true(env, _has_arg_file(action.argv, suffix), "expected --arg-file ending with '{}'".format(suffix))
    for suffix in ctx.attr.unexpected_arg_files:
        asserts.false(env, _has_arg_file(action.argv, suffix), "unexpected --arg-file ending with '{}'".format(suffix))

    if ctx.attr.bin_name:
        index = action.argv.index("--cargo-bin-name")
        asserts.equals(env, ctx.attr.bin_name, action.argv[index + 1])
    return analysistest.end(env)

_link_args_test = analysistest.make(
    _link_args_test_impl,
    attrs = {
        "bin_name": attr.string(),
        "expect_arg_files": attr.string_list(),
        "unexpected_arg_files": attr.string_list(),
    },
)

def cdylib_bin_link_args_test_suite(name):
    """Test that build-script cdylib/bin link args reach only the matching crate type.

    Args:
        name: Name of the test suite.
    """

    # A build script reached only transitively, via `dep_lib`.
    cargo_build_script(
        name = "transitive_build_script",
        srcs = ["build.rs"],
        tags = ["manual"],
    )

    rust_library(
        name = "dep_lib",
        srcs = ["lib.rs"],
        deps = [":transitive_build_script"],
        tags = ["manual"],
    )

    # The consumers' own (direct) build script.
    cargo_build_script(
        name = "direct_build_script",
        srcs = ["build.rs"],
        tags = ["manual"],
    )

    rust_shared_library(
        name = "cdylib",
        srcs = ["lib.rs"],
        deps = [":direct_build_script", ":dep_lib"],
        tags = ["manual"],
    )

    rust_binary(
        name = "bin",
        cargo_bin_name = "my-bin",
        srcs = ["bin.rs"],
        deps = [":direct_build_script", ":dep_lib"],
        tags = ["manual"],
    )

    rust_binary(
        name = "my_bin",
        srcs = ["bin.rs"],
        deps = [":direct_build_script", ":dep_lib"],
        tags = ["manual"],
    )

    rust_test(
        name = "binary_unit_test",
        crate = ":bin",
    )

    rust_library(
        name = "lib",
        srcs = ["lib.rs"],
        deps = [":direct_build_script"],
        tags = ["manual"],
    )

    # A cdylib gets its own cdylib link args AND those of a transitive build
    # script, but not the bin link args.
    _link_args_test(
        name = "cdylib_consumer_test",
        target_under_test = ":cdylib",
        expect_arg_files = [
            "direct_build_script.cdyliblinkflags",
            "transitive_build_script.cdyliblinkflags",
        ],
        unexpected_arg_files = ["direct_build_script.binlinkflags"],
    )

    # A binary gets its own bin link args, but no cdylib link args (direct or
    # transitive).
    _link_args_test(
        name = "bin_consumer_test",
        target_under_test = ":bin",
        bin_name = "my-bin",
        expect_arg_files = ["direct_build_script.binlinkflags"],
        unexpected_arg_files = [
            "direct_build_script.cdyliblinkflags",
            "transitive_build_script.cdyliblinkflags",
            "transitive_build_script.binlinkflags",
        ],
    )

    # An rlib gets neither.
    _link_args_test(
        name = "lib_consumer_test",
        target_under_test = ":lib",
        unexpected_arg_files = [
            "direct_build_script.cdyliblinkflags",
            "direct_build_script.binlinkflags",
        ],
    )

    _link_args_test(
        name = "default_binary_name_test",
        target_under_test = ":my_bin",
        bin_name = "my_bin",
        expect_arg_files = ["direct_build_script.binlinkflags"],
        unexpected_arg_files = ["transitive_build_script.binlinkflags"],
    )

    _link_args_test(
        name = "test_harness_consumer_test",
        target_under_test = ":binary_unit_test",
        unexpected_arg_files = [
            "direct_build_script.binlinkflags",
            "direct_build_script.cdyliblinkflags",
        ],
    )

    # Analysis alone does not read the generated response files. Build each
    # consumer so malformed records, path substitution, and leaked invalid
    # flags for an unrelated binary cause a real compiler/linker failure.
    build_test(
        name = "link_args_build_test",
        targets = [":bin", ":my_bin", ":cdylib", ":lib"],
    )

    native.test_suite(
        name = name,
        tests = [
            ":cdylib_consumer_test",
            ":bin_consumer_test",
            ":lib_consumer_test",
            ":default_binary_name_test",
            ":test_harness_consumer_test",
            ":link_args_build_test",
            ":binary_unit_test",
        ],
    )
