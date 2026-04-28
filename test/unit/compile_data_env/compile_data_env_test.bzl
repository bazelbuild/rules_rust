"""Test that $(location) in rustc_env expands compile_data targets in rust_test."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//rust:defs.bzl", "rust_test")
load("//test/unit:common.bzl", "assert_env_value")

def _find_action(tut, mnemonic):
    for action in tut.actions:
        if action.mnemonic == mnemonic:
            return action
    return None

# ---------------------------------------------------------------------------
# Test: standalone rust_test with compile_data referenced in rustc_env
# ---------------------------------------------------------------------------

def _standalone_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    action = _find_action(tut, "Rustc")
    if not action:
        fail("No Rustc action found")
    expected = "${pwd}/" + ctx.bin_dir.path + "/test/unit/compile_data_env/generated.txt"
    assert_env_value(env, action, "GENERATED_PATH", expected)
    return analysistest.end(env)

standalone_compile_data_env_test = analysistest.make(_standalone_test_impl)

# ---------------------------------------------------------------------------
# Subjects and test suite
# ---------------------------------------------------------------------------

def _test_subjects():
    write_file(
        name = "gen_file",
        out = "generated.txt",
        content = ["hello"],
        newline = "unix",
    )

    rust_test(
        name = "standalone_test",
        srcs = ["test.rs"],
        compile_data = [":gen_file"],
        edition = "2021",
        rustc_env = {
            "GENERATED_PATH": "$(execpath :gen_file)",
        },
    )

def compile_data_env_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _test_subjects()

    standalone_compile_data_env_test(
        name = "standalone_compile_data_env_test",
        target_under_test = ":standalone_test",
    )

    native.test_suite(
        name = name,
        tests = [
            ":standalone_compile_data_env_test",
        ],
    )
