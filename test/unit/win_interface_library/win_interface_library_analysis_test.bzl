"""Analysis tests for exporting the Windows interface library."""

load("@rules_cc//cc:defs.bzl", "cc_binary")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load("//rust:defs.bzl", "rust_binary", "rust_shared_library")

def _win_interface_library_test_impl(env, target):
    files = target[DefaultInfo].files.to_list()
    cc_library = target[CcInfo].linking_context.linker_inputs.to_list()[0].libraries[0]

    # Make sure that we have both the `.dll` and the `.dll.lib` file in the default info's files
    env.expect.that_int(len(files)).equals(2)
    env.expect.that_bool(files[0].basename.endswith(".dll")).equals(True)
    env.expect.that_bool(files[1].basename.endswith(".dll.lib")).equals(True)

    # Make sure that the cc_library has both a dynamic and interface library
    env.expect.that_bool(cc_library.dynamic_library != None).equals(True)
    env.expect.that_bool(cc_library.interface_library != None).equals(True)

def _win_interface_library_test(name):
    util.helper_target(
        rust_shared_library,
        name = name + "_mylib",
        srcs = ["lib.rs"],
        edition = "2018",
        target_compatible_with = ["@platforms//os:windows"],
    )

    util.helper_target(
        cc_binary,
        name = name + "_mybin",
        srcs = ["bin.cc"],
        deps = [":" + name + "_mylib"],
        target_compatible_with = ["@platforms//os:windows"],
    )

    util.helper_target(
        rust_binary,
        name = name + "_myrustbin",
        srcs = ["main.rs"],
        edition = "2018",
        target_compatible_with = ["@platforms//os:windows"],
    )

    analysis_test(
        name = name,
        target = ":" + name + "_mylib",
        impl = _win_interface_library_test_impl,
    )

def win_interface_library_analysis_test_suite(name):
    """Analysis tests for exporting the Windows interface library.

    Args:
        name: the test suite name
    """
    test_suite(
        name = name,
        tests = [_win_interface_library_test],
    )
