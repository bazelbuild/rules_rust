"""Unittest to verify location expansion in rustc flags"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//rust:defs.bzl", "rust_library")
load("//test/unit:common.bzl", "assert_action_mnemonic", "assert_argv_contains")

def _location_expansion_rustc_flags_test(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    action = tut.actions[1]
    assert_action_mnemonic(env, action, "Rustc")

    # Because target `rustc_flags` use `$(execpath ...)`, the action does
    # not advertise `supports-path-mapping`, so file paths remain at their
    # configuration-specific `ctx.bin_dir` locations.
    assert_argv_contains(env, action, ctx.bin_dir.path + "/test/unit/location_expansion/mylibrary.rs")

    # `$(location ...)` is expanded at analysis time into a literal
    # configuration-dependent string (`bazel-out/<config>/bin/...`).
    # Bazel does not rewrite raw argv strings under path mapping, so this
    # arg keeps the un-mapped configuration prefix even when the rest of
    # the Rustc command uses `bazel-out/cfg/bin/...`. The action will
    # fail at execution time under path mapping because the file is
    # materialized at the mapped path; we accept that as documented in
    # the Rust action implementation.
    assert_argv_contains(env, action, "@${pwd}/" + ctx.bin_dir.path + "/test/unit/location_expansion/generated_flag.data")
    return analysistest.end(env)

location_expansion_rustc_flags_test = analysistest.make(_location_expansion_rustc_flags_test)

def _location_expansion_test():
    write_file(
        name = "flag_generator",
        out = "generated_flag.data",
        content = [
            "--cfg=test_flag",
            "",
        ],
        newline = "unix",
    )

    rust_library(
        name = "mylibrary",
        srcs = ["mylibrary.rs"],
        edition = "2018",
        rustc_flags = [
            "@$(execpath :flag_generator)",
        ],
        compile_data = [":flag_generator"],
    )

    location_expansion_rustc_flags_test(
        name = "location_expansion_rustc_flags_test",
        target_under_test = ":mylibrary",
    )

def location_expansion_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _location_expansion_test()

    native.test_suite(
        name = name,
        tests = [
            ":location_expansion_rustc_flags_test",
        ],
    )
