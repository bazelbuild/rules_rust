"""Unittest to verify properties of clippy rules"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_clippy_aspect")
load("//test/unit:common.bzl", "assert_argv_contains", "assert_argv_contains_prefix_suffix", "assert_env_value", "assert_list_contains_adjacent_elements")

def _find_clippy_action(actions):
    for action in actions:
        if action.mnemonic == "Clippy":
            return action
    fail("Failed to find Clippy action")

def _clippy_aspect_action_has_flag_impl(ctx, flags, *, prefix_suffix_flags = []):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    clippy_action = _find_clippy_action(target.actions)

    # Ensure each flag is present in the clippy action
    for flag in flags:
        assert_argv_contains(
            env,
            clippy_action,
            flag,
        )
    for (prefix, suffix) in prefix_suffix_flags:
        assert_argv_contains_prefix_suffix(env, clippy_action, prefix, suffix)

    clippy_checks = target[OutputGroupInfo].clippy_checks.to_list()
    if len(clippy_checks) != 1:
        fail("clippy_checks is only expected to contain 1 file")

    # Ensure the arguments to generate the marker file are present in
    # the clippy action
    assert_list_contains_adjacent_elements(
        env,
        clippy_action.argv,
        [
            "--touch-file",
            clippy_checks[0].path,
        ],
    )

    return analysistest.end(env)

def _binary_clippy_aspect_action_has_warnings_flag_test_impl(ctx):
    return _clippy_aspect_action_has_flag_impl(
        ctx,
        ["-Dwarnings"],
    )

def _library_clippy_aspect_action_has_warnings_flag_test_impl(ctx):
    return _clippy_aspect_action_has_flag_impl(
        ctx,
        ["-Dwarnings"],
    )

def _test_clippy_aspect_action_has_warnings_flag_test_impl(ctx):
    return _clippy_aspect_action_has_flag_impl(
        ctx,
        [
            "-Dwarnings",
            "--test",
        ],
    )

_CLIPPY_EXPLICIT_FLAGS = [
    "-Dwarnings",
    "-A",
    "clippy::needless_return",
]

_CLIPPY_INDIVIDUALLY_ADDED_EXPLICIT_FLAGS = [
    "-A",
    "clippy::new_without_default",
    "-A",
    "clippy::needless_range_loop",
]

def _clippy_aspect_with_explicit_flags_test_impl(ctx):
    return _clippy_aspect_action_has_flag_impl(
        ctx,
        _CLIPPY_EXPLICIT_FLAGS + _CLIPPY_INDIVIDUALLY_ADDED_EXPLICIT_FLAGS,
    )

def _clippy_aspect_conf_dir_test_impl(ctx, expected_dir):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    clippy_action = _find_clippy_action(target.actions)
    assert_env_value(
        env,
        clippy_action,
        "CLIPPY_CONF_DIR",
        "${{pwd}}/{}".format(expected_dir),
    )

    config_inputs = [
        f
        for f in clippy_action.inputs.to_list()
        if f.dirname == expected_dir and f.basename in ("clippy.toml", ".clippy.toml")
    ]
    asserts.true(
        env,
        len(config_inputs) == 1,
        "expected exactly one clippy config from {} in action inputs, got {}".format(expected_dir, config_inputs),
    )

    return analysistest.end(env)

def make_clippy_aspect_unittest(impl, **kwargs):
    return analysistest.make(
        impl,
        extra_target_under_test_aspects = [rust_clippy_aspect],
        **kwargs
    )

binary_clippy_aspect_action_has_warnings_flag_test = make_clippy_aspect_unittest(_binary_clippy_aspect_action_has_warnings_flag_test_impl)
library_clippy_aspect_action_has_warnings_flag_test = make_clippy_aspect_unittest(_library_clippy_aspect_action_has_warnings_flag_test_impl)
test_clippy_aspect_action_has_warnings_flag_test = make_clippy_aspect_unittest(_test_clippy_aspect_action_has_warnings_flag_test_impl)
clippy_aspect_with_explicit_flags_test = make_clippy_aspect_unittest(
    _clippy_aspect_with_explicit_flags_test_impl,
    config_settings = {
        str(Label("//rust/settings:clippy_flag")): _CLIPPY_INDIVIDUALLY_ADDED_EXPLICIT_FLAGS,
        str(Label("//rust/settings:clippy_flags")): _CLIPPY_EXPLICIT_FLAGS,
    },
)

clippy_aspect_without_clippy_error_format_test = make_clippy_aspect_unittest(
    lambda ctx: _clippy_aspect_action_has_flag_impl(
        ctx,
        ["--error-format=short"],
    ),
    config_settings = {
        str(Label("//rust/settings:error_format")): "short",
        str(Label("//rust/settings:clippy_error_format")): "json",
        str(Label("//rust/settings:incompatible_change_clippy_error_format")): False,
    },
)

clippy_aspect_with_clippy_error_format_test = make_clippy_aspect_unittest(
    lambda ctx: _clippy_aspect_action_has_flag_impl(
        ctx,
        ["--error-format=json"],
    ),
    config_settings = {
        str(Label("//rust/settings:error_format")): "short",
        str(Label("//rust/settings:clippy_error_format")): "json",
        str(Label("//rust/settings:incompatible_change_clippy_error_format")): True,
    },
)

clippy_aspect_with_output_diagnostics_test = make_clippy_aspect_unittest(
    lambda ctx: _clippy_aspect_action_has_flag_impl(
        ctx,
        ["--error-format=json", "--output-file"],
        prefix_suffix_flags = [("", "/ok_library.clippy.diagnostics")],
    ),
    config_settings = {
        str(Label("//rust/settings:clippy_output_diagnostics")): True,
    },
)

clippy_aspect_uses_default_conf_dir_test = make_clippy_aspect_unittest(
    lambda ctx: _clippy_aspect_conf_dir_test_impl(ctx, "rust/settings"),
)

clippy_aspect_uses_target_conf_dir_test = make_clippy_aspect_unittest(
    lambda ctx: _clippy_aspect_conf_dir_test_impl(ctx, "test/clippy/target_config"),
)

def clippy_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): Name of the macro.
    """

    binary_clippy_aspect_action_has_warnings_flag_test(
        name = "binary_clippy_aspect_action_has_warnings_flag_test",
        target_under_test = Label("//test/clippy:ok_binary"),
    )
    library_clippy_aspect_action_has_warnings_flag_test(
        name = "library_clippy_aspect_action_has_warnings_flag_test",
        target_under_test = Label("//test/clippy:ok_library"),
    )
    test_clippy_aspect_action_has_warnings_flag_test(
        name = "test_clippy_aspect_action_has_warnings_flag_test",
        target_under_test = Label("//test/clippy:ok_test"),
    )

    clippy_aspect_with_explicit_flags_test(
        name = "binary_clippy_aspect_with_explicit_flags_test",
        target_under_test = Label("//test/clippy:ok_binary"),
    )
    clippy_aspect_with_explicit_flags_test(
        name = "library_clippy_aspect_with_explicit_flags_test",
        target_under_test = Label("//test/clippy:ok_library"),
    )
    clippy_aspect_with_explicit_flags_test(
        name = "test_clippy_aspect_with_explicit_flags_test",
        target_under_test = Label("//test/clippy:ok_test"),
    )

    clippy_aspect_without_clippy_error_format_test(
        name = "clippy_aspect_without_clippy_error_format_test",
        target_under_test = Label("//test/clippy:ok_library"),
    )
    clippy_aspect_with_clippy_error_format_test(
        name = "clippy_aspect_with_clippy_error_format_test",
        target_under_test = Label("//test/clippy:ok_library"),
    )

    clippy_aspect_with_output_diagnostics_test(
        name = "clippy_aspect_with_output_diagnostics_test",
        target_under_test = Label("//test/clippy:ok_library"),
    )

    clippy_aspect_uses_default_conf_dir_test(
        name = "clippy_aspect_uses_default_conf_dir_test",
        target_under_test = Label("//test/clippy:ok_library"),
    )
    clippy_aspect_uses_target_conf_dir_test(
        name = "clippy_aspect_uses_target_conf_dir_test",
        target_under_test = Label("//test/clippy:ok_library_with_clippy_config"),
    )
    clippy_aspect_uses_default_conf_dir_test(
        name = "clippy_aspect_crate_test_ignores_library_conf_dir_test",
        target_under_test = Label("//test/clippy:ok_crate_test_without_clippy_config"),
    )
    clippy_aspect_uses_target_conf_dir_test(
        name = "clippy_aspect_crate_test_uses_own_conf_dir_test",
        target_under_test = Label("//test/clippy:ok_crate_test_with_clippy_config"),
    )

    native.test_suite(
        name = name,
        tests = [
            ":binary_clippy_aspect_action_has_warnings_flag_test",
            ":library_clippy_aspect_action_has_warnings_flag_test",
            ":test_clippy_aspect_action_has_warnings_flag_test",
            ":binary_clippy_aspect_with_explicit_flags_test",
            ":library_clippy_aspect_with_explicit_flags_test",
            ":test_clippy_aspect_with_explicit_flags_test",
            ":clippy_aspect_without_clippy_error_format_test",
            ":clippy_aspect_with_clippy_error_format_test",
            ":clippy_aspect_with_output_diagnostics_test",
            ":clippy_aspect_uses_default_conf_dir_test",
            ":clippy_aspect_uses_target_conf_dir_test",
            ":clippy_aspect_crate_test_ignores_library_conf_dir_test",
            ":clippy_aspect_crate_test_uses_own_conf_dir_test",
        ],
    )
