"""Unittests for rust rules."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_analyzer", "rust_library")

def _rust_analyzer_hello_world_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    asserts.true(env, len(tut.actions) == 1, "expected one action, got %s" % len(tut.actions))
    action = tut.actions[0]
    outputs = action.outputs.to_list()
    asserts.true(env, len(outputs) == 1, "expected one output, got %s" % len(outputs))
    output = outputs[0]
    asserts.true(env, output.path.endswith("rust-project.json"))
    return analysistest.end(env)

rust_analyzer_hello_world_test = analysistest.make(_rust_analyzer_hello_world_test_impl)

def _rust_analyzer_test():
    rust_library(
        name = "mylib",
        srcs = ["mylib.rs"],
    )

    rust_analyzer(
        name = "rust_analyzer",
        testonly = True,
        targets = [":mylib"],
    )

    rust_analyzer_hello_world_test(
        name = "rust_analyzer_hello_world_test",
        target_under_test = ":rust_analyzer",
    )

def rust_analyzer_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _rust_analyzer_test()

    native.test_suite(
        name = name,
        tests = [
            ":rust_analyzer_hello_world_test",
        ],
    )
