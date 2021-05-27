"""Unittest to verify ordering of rust stdlib in rust_library() CcInfo"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_test")

def _test_harness_rustc_flags_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    action = tut.actions[0]
    argv = action.argv
    asserts.true(env, action.mnemonic == "Rustc", "expected the action to be the rustc invocation, got %s" % action.mnemonic)
    asserts.true(env, "test/unit/test_harness/mytest.rs" in argv, "expected the action to build mytest.rs")
    asserts.true(env, "--test" in argv, "expected rustc invocation to contain --test, got %s" % len(argv))
    asserts.false(env, "--cfg" in argv, "expected rustc invocation not to contain --cfg, got %s" % len(argv))
    asserts.false(env, "test" in argv, "expected rustc invocation not to contain test, got %s" % len(argv))
    return analysistest.end(env)

def _test_harness_rustc_noharness_flags_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    action = tut.actions[0]
    argv = action.argv
    asserts.true(env, action.mnemonic == "Rustc", "expected the action to be the rustc invocation, got %s" % action.mnemonic)
    asserts.true(env, "test/unit/test_harness/mytest_noharness.rs" in argv, "expected the action to build mytest.rs")
    asserts.false(env, "--test" in argv, "expected rustc invocation not to contain --test, got %s" % len(argv))
    asserts.true(env, "--cfg" in argv, "expected rustc invocation to contain --cfg, got %s" % len(argv))
    asserts.true(env, "test" in argv, "expected rustc invocation to contain test, got %s" % len(argv))
    return analysistest.end(env)

test_harness_rustc_flags_test = analysistest.make(_test_harness_rustc_flags_test_impl)
test_harness_rustc_noharness_flags_test = analysistest.make(_test_harness_rustc_noharness_flags_test_impl)

def _test_harness_test():
    rust_test(
        name = "mytest",
        srcs = ["mytest.rs"],
    )

    rust_test(
        name = "mytest_noharness",
        srcs = ["mytest_noharness.rs"],
        harness = False,
    )

    test_harness_rustc_flags_test(
        name = "test_harness_rustc_flags_test",
        target_under_test = ":mytest",
    )

    test_harness_rustc_noharness_flags_test(
        name = "test_harness_rustc_noharness_flags_test",
        target_under_test = ":mytest_noharness",
    )

def test_harness_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _test_harness_test()

    native.test_suite(
        name = name,
        tests = [
            ":test_harness_rustc_flags_test",
        ],
    )
