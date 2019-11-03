load("@rules_cc//cc:defs.bzl", "cc_library")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:rust.bzl", "rust_binary")

def _linkopts_test_impl(ctx):
    env = analysistest.begin(ctx)

    subject = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)

    asserts.true(env, "-lsystem_lib" in actions[0].argv)

    return analysistest.end(env)

linkopts_test = analysistest.make(_linkopts_test_impl)

def _linkopts_test():
    cc_library(
        name = "native",
        linkopts = ["-lsystem_lib"],
        tags = ["manual"],
    )
    rust_binary(
        name = "main",
        deps = [":native"],
        srcs = ["main.rs"],
        tags = ["manual"],
    )
    linkopts_test(
        name = "linkopts_test",
        target_under_test = ":main",
    )

def native_deps_test_suite(name):
    _linkopts_test()

    native.test_suite(
        name = name,
        tests = [
            ":linkopts_test",
        ],
    )
