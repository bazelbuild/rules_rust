"""Unittests for rust linkstamp support."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc:defs.bzl", "cc_library")
load("//test/unit:common.bzl", "assert_action_mnemonic")
load("//rust/private:common.bzl", "rust_common")
load("//rust:defs.bzl", "rust_binary", "rust_proc_macro", "rust_shared_library", "rust_static_library", "rust_test")

def _supports_linkstamps_test(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    linkstamp_action = tut.actions[0]
    assert_action_mnemonic(env, linkstamp_action, "CppLinkstampCompile")
    linkstamp_out = linkstamp_action.outputs.to_list()[0]
    asserts.equals(env, linkstamp_out.basename, "linkstamp.o")
    tut_out = tut.files.to_list()[0]
    expected_linkstamp_path = tut_out.dirname + "/_objs/" + tut_out.basename + "/test/unit/linkstamps/linkstamp.o"
    asserts.equals(
        env,
        linkstamp_out.path,
        tut_out.dirname + "/_objs/" + tut_out.basename + "/test/unit/linkstamps/linkstamp.o",
        "Expected linkstamp output '{actual_path}' to match '{expected_path}'".format(
            actual_path = linkstamp_out.path,
            expected_path = expected_linkstamp_path,
        ),
    )

    rustc_action = tut.actions[1]
    assert_action_mnemonic(env, rustc_action, "Rustc")
    rustc_inputs = rustc_action.inputs.to_list()
    asserts.true(
        env,
        linkstamp_out in rustc_inputs,
        "Expected linkstamp output '{output}' to be among the binary inputs '{inputs}'".format(
            output = linkstamp_out,
            inputs = rustc_inputs,
        ),
    )
    return analysistest.end(env)

supports_linkstamps_test = analysistest.make(_supports_linkstamps_test)

def _linkstamps_test():
    cc_library(
        name = "cc_lib_with_linkstamp",
        linkstamp = "linkstamp.cc",
    )

    rust_binary(
        name = "some_rust_binary",
        srcs = ["foo.rs"],
        deps = [":cc_lib_with_linkstamp"],
    )

    rust_test(
        name = "some_rust_test1",
        srcs = ["foo.rs"],
        deps = [":cc_lib_with_linkstamp"],
    )

    rust_test(
        name = "some_rust_test2",
        srcs = ["foo.rs"],
        deps = [":cc_lib_with_linkstamp"],
    )

    supports_linkstamps_test(
        name = "rust_binary_supports_linkstamps_test",
        target_under_test = ":some_rust_binary",
    )

    supports_linkstamps_test(
        name = "rust_test_supports_linkstamps_test1",
        target_under_test = ":some_rust_test1",
    )

    supports_linkstamps_test(
        name = "rust_test_supports_linkstamps_test2",
        target_under_test = ":some_rust_test2",
    )

def linkstamps_test_suite(name):
    # Older versions of Bazel do not support Skylark linkstamps.
    if not hasattr(cc_common, "register_linkstamp_compile_action"):
        print("Skipping linkstamps tests since this Bazel version does not support Skylark linkstamps.")
        return

    _linkstamps_test()

    native.test_suite(
        name = name,
        tests = [
            ":rust_binary_supports_linkstamps_test",
            ":rust_test_supports_linkstamps_test1",
            ":rust_test_supports_linkstamps_test2",
        ],
    )
