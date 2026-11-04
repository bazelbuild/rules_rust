"""Analysis tests for DebugPackageInfo and dwo_files on rust_binary."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc/common:debug_package_info.bzl", "DebugPackageInfo")
load("//rust:defs.bzl", "rust_binary", "rust_library")

def _test_n_dwo_files(ctx, n):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    debug_package_info = target_under_test[DebugPackageInfo]
    asserts.equals(env, target_under_test.label.name + ".stripped", debug_package_info.stripped_file.basename)
    if hasattr(debug_package_info, "dwo_files") and debug_package_info.dwo_files != None:
        asserts.equals(env, n, len(debug_package_info.dwo_files.to_list()))

    if n > 0:
        asserts.equals(env, target_under_test.label.name + ".dwp", debug_package_info.dwp_file.basename)
    else:
        asserts.equals(env, None, debug_package_info.dwp_file)

    return analysistest.end(env)

def _dwo_files_contents(ctx):
    # Expect one dwo entry per crate in the dependency chain (dwo_impl_lib, dwo_lib, dwo_main).
    return _test_n_dwo_files(ctx, 3)

def _dwo_files_no_contents(ctx):
    # Without fission, dwo_files should be empty and dwp_file should be None.
    return _test_n_dwo_files(ctx, 0)

dwo_files_contents_test = analysistest.make(
    _dwo_files_contents,
    config_settings = {
        "//command_line_option:features": ["per_object_debug_info"],
        "//command_line_option:fission": ["yes"],
    },
)

dwo_files_no_contents_test = analysistest.make(
    _dwo_files_no_contents,
    config_settings = {
        "//command_line_option:fission": ["no"],
    },
)

# Fission requires `-Zsplit-dwarf-out-dir` which is a nightly-only flag.
# Even though these are analysis tests (which normally don't execute actions),
# `bazel coverage` forces compilation of the `target_under_test`. To prevent
# compilation failures on the stable channel during coverage runs, we restrict
# Fission tests to the nightly channel.
_FISSION_COMPATIBILITY = ["@platforms//os:linux"] + select({
    "//rust/toolchain/channel:nightly": [],
    "//conditions:default": ["@platforms//:incompatible"],
})

def dwo_files_test_suite(name):
    """Analysis tests for DebugPackageInfo and dwo_files on rust_binary.

    Args:
        name: the test suite name
    """
    rust_library(
        name = "dwo_impl_lib",
        srcs = ["lib.rs"],
        edition = "2018",
        target_compatible_with = ["@platforms//os:linux"],
    )

    rust_library(
        name = "dwo_lib",
        srcs = ["lib.rs"],
        edition = "2018",
        deps = [":dwo_impl_lib"],
        target_compatible_with = ["@platforms//os:linux"],
    )

    rust_binary(
        name = "dwo_main",
        srcs = ["main.rs"],
        edition = "2018",
        deps = [":dwo_lib"],
        target_compatible_with = ["@platforms//os:linux"],
    )

    dwo_files_contents_test(
        name = "dwo_files_content_test",
        target_under_test = ":dwo_main",
        target_compatible_with = _FISSION_COMPATIBILITY,
    )

    dwo_files_no_contents_test(
        name = "dwo_files_no_content_test",
        target_under_test = ":dwo_main",
        target_compatible_with = ["@platforms//os:linux"],
    )

    native.test_suite(
        name = name,
        tests = [
            ":dwo_files_content_test",
            ":dwo_files_no_content_test",
        ],
    )
