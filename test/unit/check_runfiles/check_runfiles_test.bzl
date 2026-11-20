"""Unittests for rust rules."""

load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load(
    "//rust:defs.bzl",
    "rust_binary",
    "rust_library",
    "rust_shared_library",
    "rust_static_library",
)

def _check_runfiles_test_impl(env, target):
    runfile_basenames = [
        file.basename
        for file in target[DefaultInfo].default_runfiles.files.to_list()
    ]

    env.expect.that_collection(runfile_basenames).contains("libbar.so")

    # cc_libraries put shared libs to data runfiles even when linking statically
    # and there is a static library alternative. We must be careful not to put
    # these shared libs to default runfiles.
    env.expect.that_collection(runfile_basenames).not_contains(
        "libtest_Sunit_Scheck_Urunfiles_Slibcc_Ulib.so",
    )

def _check_runfiles_lib_test(name):
    util.helper_target(
        rust_library,
        name = name + "_foo_lib",
        srcs = ["foo.rs"],
        edition = "2018",
        deps = [":libbar.so", ":cc_lib"],
    )

    analysis_test(
        name = name,
        target = ":" + name + "_foo_lib",
        impl = _check_runfiles_test_impl,
    )

def _check_runfiles_bin_test(name):
    util.helper_target(
        rust_binary,
        name = name + "_foo_bin",
        srcs = ["foo_main.rs"],
        edition = "2018",
        deps = [":libbar.so"],
    )

    analysis_test(
        name = name,
        target = ":" + name + "_foo_bin",
        impl = _check_runfiles_test_impl,
    )

def _check_runfiles_dylib_test(name):
    util.helper_target(
        rust_shared_library,
        name = name + "_foo_dylib",
        srcs = ["foo.rs"],
        edition = "2018",
        deps = [":libbar.so"],
    )

    analysis_test(
        name = name,
        target = ":" + name + "_foo_dylib",
        impl = _check_runfiles_test_impl,
    )

def _check_runfiles_static_test(name):
    util.helper_target(
        rust_static_library,
        name = name + "_foo_static",
        srcs = ["foo.rs"],
        edition = "2018",
        deps = [":libbar.so"],
    )

    analysis_test(
        name = name,
        target = ":" + name + "_foo_static",
        impl = _check_runfiles_test_impl,
    )

def check_runfiles_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    util.helper_target(
        cc_library,
        name = "cc_lib",
        srcs = ["bar.cc"],
    )

    # buildifier: disable=native-cc
    util.helper_target(
        cc_binary,
        name = "libbar.so",
        srcs = ["bar.cc"],
        linkshared = True,
    )

    test_suite(
        name = name,
        tests = [
            _check_runfiles_lib_test,
            _check_runfiles_bin_test,
            _check_runfiles_dylib_test,
            _check_runfiles_static_test,
        ],
    )
