"""Analysis tests for the experimental JUnit XML wrapper on `rust_test`.

These verify which executable `rust_test` selects across the tri-state
`experimental_junit` attribute and the
`//rust/settings:experimental_emit_junit_xml` build setting. They run in the
analysis phase only (no test binary is executed): a wrapped target exposes the
`<name>_junit_runner` executable, an unwrapped target exposes the plain test
binary.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_test")

_JUNIT_RUNNER_MARKER = "_junit_runner"

_FLAG = str(Label("//rust/settings:experimental_emit_junit_xml"))

def _executable_basename(env):
    tut = analysistest.target_under_test(env)
    return tut[DefaultInfo].files_to_run.executable.basename

def _wrapped_test_impl(ctx):
    env = analysistest.begin(ctx)
    basename = _executable_basename(env)
    asserts.true(
        env,
        _JUNIT_RUNNER_MARKER in basename,
        "expected the JUnit runner to wrap the test, but the executable was {}".format(basename),
    )
    return analysistest.end(env)

def _unwrapped_test_impl(ctx):
    env = analysistest.begin(ctx)
    basename = _executable_basename(env)
    asserts.false(
        env,
        _JUNIT_RUNNER_MARKER in basename,
        "expected the test to run unwrapped, but the executable was {}".format(basename),
    )
    return analysistest.end(env)

wrapped_test = analysistest.make(_wrapped_test_impl)
unwrapped_test = analysistest.make(_unwrapped_test_impl)
wrapped_with_flag_test = analysistest.make(
    _wrapped_test_impl,
    config_settings = {_FLAG: True},
)
unwrapped_with_flag_test = analysistest.make(
    _unwrapped_test_impl,
    config_settings = {_FLAG: True},
)

def emit_junit_xml_test_suite(name):
    """Defines the JUnit-gating analysis-test suite.

    Args:
        name: name of the resulting `test_suite`.
    """
    rust_test(
        name = "attr_on",
        srcs = ["lib.rs"],
        edition = "2021",
        experimental_junit = 1,
    )
    rust_test(
        name = "attr_off",
        srcs = ["lib.rs"],
        edition = "2021",
        experimental_junit = 0,
    )
    rust_test(
        name = "attr_default",
        srcs = ["lib.rs"],
        edition = "2021",
    )

    # experimental_junit = 1 -> always wrapped, whatever the build setting is.
    wrapped_test(
        name = "attr_on_wraps_test",
        target_under_test = ":attr_on",
    )
    wrapped_with_flag_test(
        name = "attr_on_wraps_with_flag_test",
        target_under_test = ":attr_on",
    )

    # experimental_junit = 0 -> never wrapped, whatever the build setting is.
    unwrapped_test(
        name = "attr_off_unwrapped_test",
        target_under_test = ":attr_off",
    )
    unwrapped_with_flag_test(
        name = "attr_off_unwrapped_with_flag_test",
        target_under_test = ":attr_off",
    )

    # experimental_junit = -1 (default) -> defers to the build setting.
    unwrapped_test(
        name = "default_off_without_flag_test",
        target_under_test = ":attr_default",
    )
    wrapped_with_flag_test(
        name = "default_on_with_flag_test",
        target_under_test = ":attr_default",
    )

    native.test_suite(
        name = name,
        tests = [
            ":attr_on_wraps_test",
            ":attr_on_wraps_with_flag_test",
            ":attr_off_unwrapped_test",
            ":attr_off_unwrapped_with_flag_test",
            ":default_off_without_flag_test",
            ":default_on_with_flag_test",
        ],
    )
