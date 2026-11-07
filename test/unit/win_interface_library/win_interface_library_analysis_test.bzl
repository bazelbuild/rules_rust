"""Analysis tests for exporting the Windows interface library."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc:defs.bzl", "cc_binary")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("//rust:defs.bzl", "rust_binary", "rust_shared_library")

def _win_interface_library_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    files = target[DefaultInfo].files.to_list()
    cc_library = target[CcInfo].linking_context.linker_inputs.to_list()[0].libraries[0]

    # Make sure that we have both the `.dll` and the `.dll.lib` file in the default info's files
    asserts.equals(env, len(files), 2)
    asserts.true(env, files[0].basename.endswith(".dll"))
    asserts.true(env, files[1].basename.endswith(".dll.lib"))

    # Make sure that the cc_library has both a dynamic and interface library
    asserts.true(env, cc_library.dynamic_library != None)
    asserts.true(env, cc_library.interface_library != None)

    return analysistest.end(env)

win_interface_library_test = analysistest.make(_win_interface_library_test_impl)

def _win_interface_library_cc_common_link_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)

    rustc_actions = [a for a in actions if a.mnemonic == "Rustc"]
    asserts.equals(env, 1, len(rustc_actions))
    rustc_outputs = [o.basename for o in rustc_actions[0].outputs.to_list()]

    # When linking via cc_common.link (--emit=obj), Rustc must emit an object
    # file and must NOT declare a `.dll.lib` output.
    asserts.true(
        env,
        any([o.endswith((".o", ".obj")) for o in rustc_outputs]),
        "Expected Rustc action to emit an object file, got: {}".format(rustc_outputs),
    )
    asserts.false(
        env,
        any([o.endswith(".dll.lib") for o in rustc_outputs]),
        "Rustc action must not declare .dll.lib when cc_common.link is enabled, got: {}".format(rustc_outputs),
    )

    cpp_link_actions = [a for a in actions if a.mnemonic == "CppLink"]
    asserts.equals(env, 1, len(cpp_link_actions))

    files = target[DefaultInfo].files.to_list()
    cc_library = target[CcInfo].linking_context.linker_inputs.to_list()[0].libraries[0]
    asserts.equals(env, 2, len(files))
    asserts.true(env, any([f.basename.endswith(".dll") for f in files]))
    asserts.true(env, any([f.basename.endswith(".lib") for f in files]))
    asserts.true(env, cc_library.dynamic_library != None)
    asserts.true(env, cc_library.interface_library != None)

    return analysistest.end(env)

win_interface_library_cc_common_link_test = analysistest.make(
    _win_interface_library_cc_common_link_test_impl,
)

def win_interface_library_analysis_test_suite(name):
    """Analysis tests for exporting the Windows interface library.

    Args:
        name: the test suite name
    """
    rust_shared_library(
        name = "mylib",
        srcs = ["lib.rs"],
        edition = "2018",
        target_compatible_with = ["@platforms//os:windows"],
    )

    cc_binary(
        name = "mybin",
        srcs = ["bin.cc"],
        deps = [":mylib"],
        target_compatible_with = ["@platforms//os:windows"],
    )

    rust_binary(
        name = "myrustbin",
        srcs = ["main.rs"],
        edition = "2018",
        target_compatible_with = ["@platforms//os:windows"],
    )

    win_interface_library_test(
        name = "win_interface_library_test",
        target_under_test = ":mylib",
        target_compatible_with = ["@platforms//os:windows"],
    )

    rust_shared_library(
        name = "mylib_cc_common_link",
        srcs = ["lib.rs"],
        edition = "2018",
        experimental_use_cc_common_link = 1,
        tags = ["manual"],
        target_compatible_with = ["@platforms//os:windows"],
    )

    win_interface_library_cc_common_link_test(
        name = "win_interface_library_cc_common_link_test",
        target_under_test = ":mylib_cc_common_link",
        target_compatible_with = ["@platforms//os:windows"],
    )

    native.test_suite(
        name = name,
        tests = [
            ":win_interface_library_test",
            ":win_interface_library_cc_common_link_test",
        ],
    )
