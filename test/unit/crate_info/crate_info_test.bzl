"""Unittests for rust rules."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load(
    "//rust:defs.bzl",
    "rust_common",
    "rust_library",
    "rust_proc_macro",
    "rust_shared_library",
    "rust_static_library",
)

def _rule_provides_crate_info_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    asserts.true(
        env,
        rust_common.crate_info in tut,
        "{} should provide CrateInfo".format(tut.label.name),
    )
    return analysistest.end(env)

def _rule_does_not_provide_crate_info_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    asserts.false(
        env,
        rust_common.crate_info in tut,
        "{} should not provide CrateInfo".format(tut.label.name),
    )
    asserts.true(
        env,
        rust_common.test_crate_info in tut,
        "{} should provide a TestCrateInfo".format(tut.label.name),
    )
    return analysistest.end(env)

# Sentinel injected via `--action_env` (see config_settings below). It enters
# `ctx.configuration.default_shell_env` of the target under test; if the leak
# regresses, it will surface inside `CrateInfo.rustc_env`.
_LEAK_CANARY_KEY = "RULES_RUST_CRATE_INFO_LEAK_CANARY"
_LEAK_CANARY_VALUE = "leaked"

def _crate_info_does_not_leak_default_shell_env_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    crate_info = tut[rust_common.crate_info]

    # Note: a structural "no key from default_shell_env appears in rustc_env"
    # check would false-positive on Windows, where `env_from_args` legitimately
    # carries cc_toolchain link_env values (PATH, ...) for crates that emit a
    # dylib (e.g. proc_macro). The canary is unambiguous: nothing except an
    # explicit --action_env produces it, so its presence proves a leak.
    asserts.false(
        env,
        _LEAK_CANARY_KEY in crate_info.rustc_env,
        ("CrateInfo.rustc_env leaked default_shell_env: found key '{key}'. " +
         "See bazelbuild/rules_rust#3989.").format(key = _LEAK_CANARY_KEY),
    )

    return analysistest.end(env)

rule_provides_crate_info_test = analysistest.make(_rule_provides_crate_info_test_impl)
rule_does_not_provide_crate_info_test = analysistest.make(_rule_does_not_provide_crate_info_test_impl)
crate_info_does_not_leak_default_shell_env_test = analysistest.make(
    _crate_info_does_not_leak_default_shell_env_test_impl,
    config_settings = {
        "//command_line_option:action_env": [
            "{}={}".format(_LEAK_CANARY_KEY, _LEAK_CANARY_VALUE),
        ],
    },
)

def _crate_info_test():
    rust_library(
        name = "rlib",
        srcs = ["lib.rs"],
        edition = "2018",
    )

    rust_proc_macro(
        name = "proc_macro",
        srcs = ["lib.rs"],
        edition = "2018",
    )

    rust_static_library(
        name = "staticlib",
        srcs = ["lib.rs"],
        edition = "2018",
    )

    rust_shared_library(
        name = "cdylib",
        srcs = ["lib.rs"],
        edition = "2018",
    )

    rule_provides_crate_info_test(
        name = "rlib_provides_crate_info_test",
        target_under_test = ":rlib",
    )

    rule_provides_crate_info_test(
        name = "proc_macro_provides_crate_info_test",
        target_under_test = ":proc_macro",
    )

    rule_does_not_provide_crate_info_test(
        name = "cdylib_does_not_provide_crate_info_test",
        target_under_test = ":cdylib",
    )

    rule_does_not_provide_crate_info_test(
        name = "staticlib_does_not_provide_crate_info_test",
        target_under_test = ":staticlib",
    )

    crate_info_does_not_leak_default_shell_env_test(
        name = "rlib_crate_info_does_not_leak_default_shell_env_test",
        target_under_test = ":rlib",
    )

    crate_info_does_not_leak_default_shell_env_test(
        name = "proc_macro_crate_info_does_not_leak_default_shell_env_test",
        target_under_test = ":proc_macro",
    )

def crate_info_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _crate_info_test()

    native.test_suite(
        name = name,
        tests = [
            ":rlib_provides_crate_info_test",
            ":proc_macro_provides_crate_info_test",
            ":cdylib_does_not_provide_crate_info_test",
            ":staticlib_does_not_provide_crate_info_test",
            ":rlib_crate_info_does_not_leak_default_shell_env_test",
            ":proc_macro_crate_info_does_not_leak_default_shell_env_test",
        ],
    )
