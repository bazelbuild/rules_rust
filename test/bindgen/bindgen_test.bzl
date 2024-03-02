"""Analysis test for for rust_bindgen_library rule."""

load("@rules_cc//cc:defs.bzl", "cc_library")
load("@rules_rust//bindgen:defs.bzl", "rust_bindgen_library")
load("@rules_rust//rust:defs.bzl", "rust_binary")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")

def _test_cc_linkopt_impl(env, target):
    # Assert
    env.expect.that_action(target.actions[0]) \
        .contains_at_least_args(["--codegen=link-arg=-shared"])

def _test_cc_linkopt(name):
    # Arrange
    cc_library(
        name = name + "_cc",
        srcs = ["simple.cc"],
        hdrs = ["simple.h"],
        linkopts = ["-shared"],
        tags = ["manual"],
    )
    rust_bindgen_library(
        name = name + "_rust_bindgen",
        cc_lib = name + "_cc",
        header = "simple.h",
        tags = ["manual"],
        edition = "2021",
    )
    rust_binary(
        name = name + "_rust_binary",
        srcs = ["main.rs"],
        deps = [name + "_rust_bindgen"],
        tags = ["manual"],
        edition = "2021",
    )

    # Act
    # TODO: Use targets attr to also verify `rust_bindgen_library` not having
    # the linkopt after https://github.com/bazelbuild/rules_testing/issues/67
    # is released
    analysis_test(
        name = name,
        target = name + "_rust_binary",
        impl = _test_cc_linkopt_impl,
    )

def bindgen_test_suite(name):
    test_suite(
        name = name,
        tests = [
            _test_cc_linkopt,
        ],
    )
