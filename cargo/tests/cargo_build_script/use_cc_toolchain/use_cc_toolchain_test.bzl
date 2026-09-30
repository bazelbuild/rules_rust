"""Analysis tests for the `use_cc_toolchain` attribute of `cargo_build_script`.

Only the disabled paths are exercised; the enabled paths are already covered by
the pre-existing `cc_args_and_env` suite.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//cargo:defs.bzl", "cargo_build_script")

_USE_CC_TOOLCHAIN_FLAG = str(Label("//cargo/settings:use_cc_toolchain"))

def _find_cargo_action(actions):
    """Return the `CargoBuildScriptRun` action from a target's action list.

    Args:
        actions (list[Action]): The actions registered by the target under test.

    Returns:
        Action: The `CargoBuildScriptRun` action. Fails if none is present.
    """
    for action in actions:
        if action.mnemonic == "CargoBuildScriptRun":
            return action
    fail("Could not find CargoBuildScriptRun action")

def _assert_cc_toolchain_absent_impl(ctx):
    env = analysistest.begin(ctx)
    cargo_action = _find_cargo_action(analysistest.target_under_test(env).actions)
    for var in ("CC", "CXX", "AR"):
        value = cargo_action.env.get(var)
        asserts.true(
            env,
            value != None,
            "expected env var {} to be set, but it was missing".format(var),
        )
        asserts.true(
            env,
            "no_" + var.lower() in value,
            "expected env var {} to point at the fallback tool, got: {}".format(var, value),
        )
    return analysistest.end(env)

_cc_toolchain_absent_with_flag_disabled_test = analysistest.make(
    impl = _assert_cc_toolchain_absent_impl,
    config_settings = {_USE_CC_TOOLCHAIN_FLAG: False},
)

_cc_toolchain_absent_with_flag_enabled_test = analysistest.make(
    impl = _assert_cc_toolchain_absent_impl,
    config_settings = {_USE_CC_TOOLCHAIN_FLAG: True},
)

def use_cc_toolchain_test_suite(name):
    """Instantiates analysis tests covering `cargo_build_script.use_cc_toolchain`.

    Args:
        name (str): The name of the test suite.
    """
    cargo_build_script(
        name = "build_script_default",
        edition = "2018",
        srcs = ["build.rs"],
        tags = ["manual"],
    )

    cargo_build_script(
        name = "build_script_disabled",
        edition = "2018",
        srcs = ["build.rs"],
        use_cc_toolchain = False,
        tags = ["manual"],
    )

    # Attribute unset (`-1`) + flag flipped off => no toolchain.
    _cc_toolchain_absent_with_flag_disabled_test(
        name = "default_attr_follows_disabled_flag_test",
        target_under_test = ":build_script_default",
    )

    # Attribute explicitly disabled (`0`) wins over either flag value.
    _cc_toolchain_absent_with_flag_disabled_test(
        name = "disabled_attr_matches_disabled_flag_test",
        target_under_test = ":build_script_disabled",
    )
    _cc_toolchain_absent_with_flag_enabled_test(
        name = "disabled_attr_overrides_enabled_flag_test",
        target_under_test = ":build_script_disabled",
    )

    native.test_suite(
        name = name,
        tests = [
            ":default_attr_follows_disabled_flag_test",
            ":disabled_attr_matches_disabled_flag_test",
            ":disabled_attr_overrides_enabled_flag_test",
        ],
    )
