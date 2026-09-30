"""Unittests for rust rules."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc:cc_import.bzl", "cc_import")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load(
    "//rust:defs.bzl",
    "rust_binary",
    "rust_library",
    "rust_shared_library",
    "rust_static_library",
    "rust_test",
)

# A `cc_import` with only a `shared_library` has no import library for MSVC to
# link against, so the `crate`-only case cannot be built on Windows.
NOT_WINDOWS = select({
    "@platforms//os:windows": ["@platforms//:incompatible"],
    "//conditions:default": [],
})

def _check_runfiles_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    runfiles = tut[DefaultInfo].default_runfiles.files.to_list()

    asserts.true(env, _is_in_runfiles("libbar.so", runfiles))

    # cc_libraries put shared libs to data runfiles even when linking statically
    # and there is a static library alternative. We must be careful not to put
    # these shared libs to default runfiles.
    asserts.false(env, _is_in_runfiles("libtest_Sunit_Scheck_Urunfiles_Slibcc_Ulib.so", runfiles))

    return analysistest.end(env)

def _is_in_runfiles(name, runfiles):
    for file in runfiles:
        if file.basename == name:
            return True
    return False

check_runfiles_test = analysistest.make(_check_runfiles_test_impl)

def _check_runfiles_test():
    cc_library(
        name = "cc_lib",
        srcs = ["bar.cc"],
    )
    rust_library(
        name = "foo_lib",
        srcs = ["foo.rs"],
        edition = "2018",
        deps = [":libbar.so", ":cc_lib"],
    )

    rust_binary(
        name = "foo_bin",
        srcs = ["foo_main.rs"],
        edition = "2018",
        deps = [":libbar.so"],
    )

    rust_shared_library(
        name = "foo_dylib",
        srcs = ["foo.rs"],
        edition = "2018",
        deps = [":libbar.so"],
    )

    rust_static_library(
        name = "foo_static",
        srcs = ["foo.rs"],
        edition = "2018",
        deps = [":libbar.so"],
    )

    # buildifier: disable=native-cc
    cc_binary(
        name = "libbar.so",
        srcs = ["bar.cc"],
        linkshared = True,
    )

    # A cc_import puts nothing in its own runfiles, so the only way libbar.so
    # reaches a consumer's runfiles is through the dylib staging in
    # rustc_compile_action.
    cc_import(
        name = "bar_import",
        shared_library = ":libbar.so",
        target_compatible_with = NOT_WINDOWS,
    )

    rust_library(
        name = "foo_lib_via_import",
        srcs = ["foo.rs"],
        edition = "2018",
        target_compatible_with = NOT_WINDOWS,
        deps = [":bar_import"],
    )

    # Reaches libbar.so only through `crate`; nothing in `deps` links it.
    rust_test(
        name = "foo_crate_test",
        crate = ":foo_lib_via_import",
        target_compatible_with = NOT_WINDOWS,
    )

    check_runfiles_test(
        name = "check_runfiles_lib_test",
        target_under_test = ":foo_lib",
    )

    check_runfiles_test(
        name = "check_runfiles_crate_test",
        target_compatible_with = NOT_WINDOWS,
        target_under_test = ":foo_crate_test",
    )

    check_runfiles_test(
        name = "check_runfiles_bin_test",
        target_under_test = ":foo_bin",
    )

    check_runfiles_test(
        name = "check_runfiles_dylib_test",
        target_under_test = ":foo_dylib",
    )

    check_runfiles_test(
        name = "check_runfiles_static_test",
        target_under_test = ":foo_static",
    )

def check_runfiles_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _check_runfiles_test()

    native.test_suite(
        name = name,
        tests = [
            ":check_runfiles_lib_test",
            ":check_runfiles_crate_test",
            ":check_runfiles_bin_test",
            ":check_runfiles_dylib_test",
            ":check_runfiles_static_test",
        ],
    )
