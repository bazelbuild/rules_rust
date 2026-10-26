"""Unit tests for transitive OUT_DIR interactions."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@bazel_skylib//rules:common_settings.bzl", "string_flag")
load("//cargo:defs.bzl", "cargo_build_script")
load("//rust:defs.bzl", "rust_binary", "rust_library")
load("//rust:rust_common.bzl", "BuildInfo")
load(
    "//test/unit:common.bzl",
    "assert_action_mnemonic",
)

def _assert_has_out_dir_binding(env, argv, flag_name, out_dir_name):
    """Assert a flag file is paired with its producer's output directory."""
    for i in range(len(argv) - 2):
        if argv[i] == "--arg-file-out-dir" and argv[i + 1].endswith(flag_name) and argv[i + 2].endswith(out_dir_name):
            return
    asserts.true(env, False, "Expected '{}' bound to '{}'".format(flag_name, out_dir_name))

def _transitive_out_dir_subst_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    action = tut.actions[0]
    assert_action_mnemonic(env, action, "Rustc")

    _assert_has_out_dir_binding(env, action.argv, "lib_build_script.linksearchpaths", "lib_build_script.out_dir")
    _assert_has_out_dir_binding(env, action.argv, "bin_link_build_script.linkflags", "bin_link_build_script.out_dir")

    # OUT_DIR paths must not occur in substitution keys: keys are strings and
    # cannot be normalized by Bazel's File-based path mapping.
    for i in range(len(action.argv) - 1):
        if action.argv[i] == "--subst":
            asserts.false(env, "bazel-out/" in action.argv[i + 1].split("=", 1)[0])
    return analysistest.end(env)

_transitive_out_dir_subst_test = analysistest.make(_transitive_out_dir_subst_test_impl)

def _archive_configuration_impl(_settings, attr):
    return {str(Label(":archive")): attr.archive}

_archive_configuration = transition(
    implementation = _archive_configuration_impl,
    inputs = [],
    outputs = [str(Label(":archive"))],
)

def _configured_script_impl(ctx):
    return [ctx.attr.script[BuildInfo], ctx.attr.script[OutputGroupInfo]]

_configured_script = rule(
    implementation = _configured_script_impl,
    cfg = _archive_configuration,
    attrs = {
        "archive": attr.string(mandatory = True),
        "script": attr.label(providers = [BuildInfo], mandatory = True),
        "_allowlist_function_transition": attr.label(default = Label("//tools/allowlists/function_transition_allowlist")),
    },
)

def cross_crate_out_dir_files_test_suite(name):
    """Test suite for cross-crate build script output directory resolution.

    Args:
        name: Name of the test suite.
    """
    cargo_build_script(
        name = "lib_build_script",
        srcs = ["lib_build.rs"],
        tags = ["manual"],
    )

    rust_library(
        name = "lib",
        srcs = ["lib.rs"],
        deps = [":lib_build_script"],
        tags = ["manual"],
    )

    cargo_build_script(
        name = "bin_link_build_script",
        srcs = ["bin_link_build.rs"],
        tags = ["manual"],
    )

    rust_binary(
        name = "bin_link",
        srcs = ["bin.rs"],
        deps = [
            ":bin_link_build_script",
            ":lib",
        ],
        tags = ["manual"],
    )

    _transitive_out_dir_subst_test(
        name = "transitive_out_dir_subst_test",
        target_under_test = ":bin_link",
    )

    build_test(
        name = "transitive_out_dir_build_test",
        targets = [":bin_link"],
    )

    # One build script is configured twice in the final dependency graph. Each
    # generated search path must retain the directory of its own configuration.
    string_flag(name = "archive", build_setting_default = "first")
    native.config_setting(name = "first_archive", flag_values = {":archive": "first"})
    cargo_build_script(
        name = "multi_configuration_script",
        srcs = ["lib_build.rs"],
        build_script_env = select({
            ":first_archive": {"OUT_DIR_TEST_ARCHIVE": "first"},
            "//conditions:default": {"OUT_DIR_TEST_ARCHIVE": "second"},
        }),
        tags = ["manual"],
    )
    for archive in ["first", "second"]:
        _configured_script(
            name = archive + "_script",
            script = ":multi_configuration_script",
            archive = archive,
            tags = ["manual"],
        )
        rust_library(
            name = archive + "_lib",
            srcs = ["lib.rs"],
            deps = [":" + archive + "_script"],
            tags = ["manual"],
        )
    cargo_build_script(
        name = "multi_link_script",
        srcs = ["multi_link_build.rs"],
        tags = ["manual"],
    )
    rust_binary(
        name = "multi_configuration_link",
        srcs = ["bin.rs"],
        deps = [":multi_link_script", ":first_lib", ":second_lib"],
        tags = ["manual"],
    )
    build_test(
        name = "multi_configuration_out_dir_build_test",
        targets = [":multi_configuration_link"],
    )

    native.test_suite(
        name = name,
        tests = [
            ":transitive_out_dir_subst_test",
            ":transitive_out_dir_build_test",
            ":multi_configuration_out_dir_build_test",
        ],
    )
