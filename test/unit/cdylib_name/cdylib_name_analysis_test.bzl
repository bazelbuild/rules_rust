"""Analysis tests for the name we assign to cdylib libraries."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load("//rust:defs.bzl", "rust_shared_library")

def _cdylib_name_test_impl(env, target):
    # We're expecting the `.dylib`/`.so` to be the only file on Unix and Windows to
    # contain a pair of `.dll` and `.lib` files.
    files = target[DefaultInfo].files.to_list()
    if len(files) == 1:
        env.expect.that_collection(["so", "dylib"]).contains(files[0].extension)
        if files[0].extension == "so":
            env.expect.that_str(files[0].basename).equals("libcdylib_name_test_something.so")
        elif files[0].extension == "dylib":
            env.expect.that_str(files[0].basename).equals("libcdylib_name_test_something.dylib")
    elif len(files) == 2:
        env.expect.that_collection([f.basename for f in files]).contains_exactly([
            "cdylib_name_test_something.dll",
            "cdylib_name_test_something.dll.lib",
        ])

def _cdylib_name_test(name):
    util.helper_target(
        rust_shared_library,
        name = name + "_something",
        srcs = ["lib.rs"],
        edition = "2018",
    )

    analysis_test(
        name = name,
        target = name + "_something",
        impl = _cdylib_name_test_impl,
    )

def cdylib_name_analysis_test_suite(name):
    """Analysis tests for the name we assign to cdylib libraries.

    Args:
        name: the test suite name
    """
    test_suite(
        name = name,
        tests = [_cdylib_name_test],
    )
