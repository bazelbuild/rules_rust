"""Tests for the layout of the registered `rustfmt_toolchain`."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _rustfmt_shares_compiler_test_impl(ctx):
    env = analysistest.begin(ctx)
    toolchain = analysistest.target_under_test(env)[platform_common.ToolchainInfo]
    rustfmt_repo = toolchain.rustfmt.owner.repo_name

    asserts.true(
        env,
        toolchain.rustc.owner.repo_name.endswith("__rustc"),
        "Expected rustc from the compiler repository of the Rust toolchains, got {}".format(toolchain.rustc.owner),
    )

    # rustfmt loads the compiler libraries from beside its own real path, so
    # actions must take the links in rustfmt's repository as inputs.
    rustc_lib = toolchain.rustc_lib.to_list()
    asserts.true(env, len(rustc_lib) > 0, "Expected compiler libraries in rustc_lib")
    for file in rustc_lib:
        asserts.equals(env, rustfmt_repo, file.owner.repo_name, "{} is not in rustfmt's repository".format(file.path))

    return analysistest.end(env)

rustfmt_shares_compiler_test = analysistest.make(_rustfmt_shares_compiler_test_impl)
