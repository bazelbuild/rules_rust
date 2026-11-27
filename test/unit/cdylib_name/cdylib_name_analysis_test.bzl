"""Analysis tests for the name we assign to cdylib libraries."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
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

def _cdylib_lib_name_test_impl(env, target):
    files = target[DefaultInfo].files.to_list()
    if len(files) == 1:
        env.expect.that_collection(["so", "dylib"]).contains(files[0].extension)
        if files[0].extension == "so":
            env.expect.that_str(files[0].basename).equals("libcustom-name.so")
        elif files[0].extension == "dylib":
            env.expect.that_str(files[0].basename).equals("libcustom-name.dylib")
    elif len(files) == 2:
        env.expect.that_collection([f.basename for f in files]).contains_exactly([
            "custom-name.dll",
            "custom-name.dll.lib",
        ])

    rustc_action = [action for action in target.actions if action.mnemonic == "Rustc"][0]
    library = [f for f in files if f.extension in ("so", "dylib", "dll")][0]
    env.expect.that_action(rustc_action).argv().contains_predicate(
        matching.custom(
            "--emit=link=.../" + library.basename,
            lambda arg: arg.startswith("--emit=link=") and arg.endswith("/" + library.basename),
        ),
    )

def _cdylib_lib_name_test(name):
    util.helper_target(
        rust_shared_library,
        name = name + "_something",
        srcs = ["lib.rs"],
        edition = "2018",
        lib_name = "custom-name",
    )

    analysis_test(
        name = name,
        target = name + "_something",
        impl = _cdylib_lib_name_test_impl,
    )

def cdylib_name_analysis_test_suite(name):
    """Analysis tests for the name we assign to cdylib libraries.

    Args:
        name: the test suite name
    """
    test_suite(
        name = name,
        tests = [
            _cdylib_name_test,
            _cdylib_lib_name_test,
        ],
    )
