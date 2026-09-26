"""Unittest to verify compile_data (attribute) propagation"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//cargo:defs.bzl", "cargo_build_script")
load("//rust:defs.bzl", "rust_clippy", "rust_doc", "rust_library", "rust_lint_config")
load("//test/unit:common.bzl", "assert_argv_contains", "assert_argv_contains_not")

def target_action_contains_not_flag(env, target, flags):
    for action in target.actions:
        if action.mnemonic == "Rustc":
            for flag in flags:
                assert_argv_contains_not(
                    env = env,
                    action = action,
                    flag = flag,
                )

def target_action_contains_flag(env, target, flags):
    for action in target.actions:
        if action.mnemonic == "Rustc":
            for flag in flags:
                assert_argv_contains(
                    env = env,
                    action = action,
                    flag = flag,
                )

def _extra_rustc_flags_present_test(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    target_action_contains_flag(env, target, ctx.attr.rustc_flags)

    target = ctx.attr.lib_exec
    if ctx.attr.apply_in_exec:
        asserts.true(env, any([action.mnemonic == "Rustc" for action in target.actions]), "expected an exec-configuration Rustc action")
        target_action_contains_flag(env, target, ctx.attr.rustc_flags)
    else:
        target_action_contains_not_flag(env, target, ctx.attr.rustc_flags)

    return analysistest.end(env)

extra_rustc_flag_present_test = analysistest.make(
    _extra_rustc_flags_present_test,
    attrs = {
        "apply_in_exec": attr.bool(),
        "lib_exec": attr.label(
            mandatory = True,
            cfg = "exec",
        ),
        "rustc_flags": attr.string_list(
            mandatory = True,
        ),
    },
)

def _define_test_targets():
    rust_lint_config(
        name = "workspace_lints",
        rustc = {"unknown_lints": "allow"},
        rustc_check_cfg = {"bazel": []},
        clippy = {"box_default": "warn"},
        rustdoc = {"unportable_markdown": "deny"},
    )

    rust_library(
        name = "lib",
        srcs = ["lib.rs"],
        lint_config = ":workspace_lints",
        edition = "2018",
    )

    cargo_build_script(
        name = "script",
        srcs = ["build.rs"],
        lint_config = ":workspace_lints",
        edition = "2018",
    )

    rust_clippy(
        name = "clippy",
        deps = [":lib"],
    )

    rust_doc(
        name = "docs",
        crate = ":lib",
    )

def lint_flags_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): Name of the macro.
    """

    _define_test_targets()

    extra_rustc_flag_present_test(
        name = "rustc_lints_apply_flags",
        target_under_test = ":lib",
        lib_exec = ":lib",
        rustc_flags = [
            "--allow=unknown_lints",
            "--check-cfg=cfg(bazel)",
        ],
        apply_in_exec = True,
    )

    extra_rustc_flag_present_test(
        name = "build_script_lints_apply_in_exec",
        target_under_test = ":script_",
        lib_exec = ":script_",
        rustc_flags = [
            "--allow=unknown_lints",
            "--check-cfg=cfg(bazel)",
        ],
        apply_in_exec = True,
    )

    extra_rustc_flag_present_test(
        name = "clippy_lints_apply_flags",
        target_under_test = ":clippy",
        lib_exec = ":clippy",
        rustc_flags = ["--warn=clippy::box_default"],
    )

    extra_rustc_flag_present_test(
        name = "rustdoc_lints_apply_flags",
        target_under_test = ":docs",
        lib_exec = ":docs",
        rustc_flags = ["--deny=rustdoc::unportable_markdown"],
    )

    native.test_suite(
        name = name,
        tests = [
            ":rustc_lints_apply_flags",
            ":build_script_lints_apply_in_exec",
            ":clippy_lints_apply_flags",
            ":rustdoc_lints_apply_flags",
        ],
    )
