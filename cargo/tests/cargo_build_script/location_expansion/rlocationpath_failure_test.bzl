"""Analysis test for unsupported cargo_build_script location expansion."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _rlocationpath_failure_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "cargo_build_script build_script_env does not support $(rlocationpath ...) in 'DATA_RLOCATIONPATH'")
    return analysistest.end(env)

rlocationpath_failure_test = analysistest.make(
    _rlocationpath_failure_test_impl,
    expect_failure = True,
)
