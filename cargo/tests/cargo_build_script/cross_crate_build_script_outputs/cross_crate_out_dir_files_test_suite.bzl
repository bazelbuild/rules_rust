"""Unit tests for transitive OUT_DIR interactions."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//cargo:defs.bzl", "cargo_build_script")
load("//rust:defs.bzl", "rust_binary", "rust_library")
load(
    "//test/unit:common.bzl",
    "assert_action_mnemonic",
)

def _assert_has_out_dir_subst(env, argv, out_dir_name):
    """Assert argv has a --subst key=value pair where both sides end with out_dir_name."""
    for i in range(len(argv) - 1):
        if argv[i] != "--subst":
            continue
        parts = argv[i + 1].split("=", 1)
        if len(parts) == 2 and parts[0].endswith(out_dir_name) and parts[1].endswith(out_dir_name):
            return
    asserts.true(
        env,
        False,
        "Expected --subst key=value where both sides end with '{}'".format(out_dir_name),
    )

def _transitive_out_dir_subst_test_impl(ctx):
    """Verify --subst entries exist for each transitive build script out_dir."""
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    action = tut.actions[0]
    assert_action_mnemonic(env, action, "Rustc")

    _assert_has_out_dir_subst(env, action.argv, "lib_build_script.out_dir")
    _assert_has_out_dir_subst(env, action.argv, "bin_link_build_script.out_dir")

    return analysistest.end(env)

_transitive_out_dir_subst_test = analysistest.make(
    _transitive_out_dir_subst_test_impl,
    doc = """\
Test that `--subst` values were passed as they are used to dereference command line
files that point to the OUT_DIR of a transitive cargo_build_script dependencies. `--subst`
is an implementation detail but as build script flags are written to a file, a starlark
unit test cannot test this. Instead the combination of a successfully built target and the
tests here provide sufficient regression testing.
""",
)

def cross_crate_out_dir_files_test_suite(name):
    """Test suite for cross-crate build script output directory resolution.

    Args:
        name: Name of the test suite.
    """
    cargo_build_script(
        name = "lib_build_script",
        srcs = ["lib_build.rs"],
        tags = ["manual"],
    )

    rust_library(
        name = "lib",
        srcs = ["lib.rs"],
        deps = [":lib_build_script"],
        tags = ["manual"],
    )

    cargo_build_script(
        name = "bin_link_build_script",
        srcs = ["bin_link_build.rs"],
        tags = ["manual"],
    )

    rust_binary(
        name = "bin_link",
        srcs = ["bin.rs"],
        deps = [
            ":bin_link_build_script",
            ":lib",
        ],
        tags = ["manual"],
    )

    _transitive_out_dir_subst_test(
        name = "transitive_out_dir_subst_test",
        target_under_test = ":bin_link",
    )

    native.test_suite(
        name = name,
        tests = [
            ":transitive_out_dir_subst_test",
        ],
    )
