"""Unit tests for rust toolchains."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:toolchain.bzl", "rust_stdlib_filegroup", "rust_toolchain")

def _toolchain_specifies_target_triple_test_impl(ctx):
    env = analysistest.begin(ctx)
    toolchain_info = analysistest.target_under_test(env)[platform_common.ToolchainInfo]

    asserts.equals(env, None, toolchain_info.target_json)
    asserts.equals(env, "toolchain-test-triple", toolchain_info.target_flag_value)
    asserts.equals(env, "toolchain-test-triple", toolchain_info.triple)

    return analysistest.end(env)

def _toolchain_specifies_target_json_test_impl(ctx):
    env = analysistest.begin(ctx)
    toolchain_info = analysistest.target_under_test(env)[platform_common.ToolchainInfo]

    asserts.equals(env, "toolchain-test-triple.json", toolchain_info.target_json.basename)
    asserts.equals(env, "test/unit/toolchain/toolchain-test-triple.json", toolchain_info.target_flag_value)
    asserts.equals(env, "", toolchain_info.triple)

    return analysistest.end(env)

toolchain_specifies_target_triple_test = analysistest.make(_toolchain_specifies_target_triple_test_impl)
toolchain_specifies_target_json_test = analysistest.make(_toolchain_specifies_target_json_test_impl)

def _toolchain_test():
    rust_stdlib_filegroup(
        name = "std_libs",
        srcs = [],
    )

    native.filegroup(
        name = "target_json",
        srcs = ["toolchain-test-triple.json"],
    )

    native.filegroup(
        name = "mock_rustc_lib",
        srcs = [],
    )

    rust_toolchain(
        name = "rust_triple_toolchain",
        binary_ext = "",
        dylib_ext = ".so",
        os = "linux",
        rust_stdlib = ":std_libs",
        staticlib_ext = ".a",
        stdlib_linkflags = [],
        target_triple = "toolchain-test-triple",
        rustc = ":mock_rustc",
        rustdoc = ":mock_rustdoc",
        rustc_lib = ":mock_rustc_lib",
    )

    rust_toolchain(
        name = "rust_json_toolchain",
        binary_ext = "",
        dylib_ext = ".so",
        os = "linux",
        rust_stdlib = ":std_libs",
        staticlib_ext = ".a",
        stdlib_linkflags = [],
        target_json = ":target_json",
        rustc = ":mock_rustc",
        rustdoc = ":mock_rustdoc",
        rustc_lib = ":mock_rustc_lib",
    )

    toolchain_specifies_target_triple_test(
        name = "toolchain_specifies_target_triple_test",
        target_under_test = ":rust_triple_toolchain",
    )
    toolchain_specifies_target_json_test(
        name = "toolchain_specifies_target_json_test",
        target_under_test = ":rust_json_toolchain",
    )

def toolchain_test_suite(name):
    _toolchain_test()

    native.test_suite(
        name = name,
        tests = [
            ":toolchain_specifies_target_triple_test",
            ":toolchain_specifies_target_json_test",
        ],
    )
