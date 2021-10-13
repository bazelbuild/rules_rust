"""Unittest to verify that we can treat all dependencies as direct dependencies"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest")
load("//rust:defs.bzl", "rust_library")
load("//test/unit:common.bzl", "assert_action_mnemonic", "assert_argv_contains_prefix")
load("//test/unit/force_only_direct_deps:generator.bzl", "generator")

def _force_only_direct_deps_rustc_flags_test(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    action = tut.actions[1]
    argv = action.argv
    assert_action_mnemonic(env, action, "Rustc")
    assert_argv_contains_prefix(
        env,
        action,
        "--extern=transitive=bazel-out/k8-fastbuild/bin/test/unit/force_only_direct_deps/libtransitive",
    )
    return analysistest.end(env)

force_only_direct_deps_test = analysistest.make(_force_only_direct_deps_rustc_flags_test)

def _force_only_direct_deps_test():
    rust_library(
        name = "direct",
        srcs = ["direct.rs"],
        edition = "2018",
        deps = [":transitive"],
    )

    rust_library(
        name = "transitive",
        srcs = ["transitive.rs"],
        edition = "2018",
    )

    generator(
        name = "generate",
        deps = [":direct"],
    )

    force_only_direct_deps_test(
        name = "force_only_direct_deps_rustc_flags_test",
        target_under_test = ":generate",
    )

def force_only_direct_deps_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _force_only_direct_deps_test()

    native.test_suite(
        name = name,
        tests = [
            ":force_only_direct_deps_rustc_flags_test",
        ],
    )
