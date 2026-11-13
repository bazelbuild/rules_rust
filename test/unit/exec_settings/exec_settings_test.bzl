"""Analysis tests for settings that exec tools must keep reading."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:util.bzl", "util")

# buildifier: disable=bzl-visibility
load("//rust/private:rustc.bzl", "ExtraExecRustcEnvInfo")

_SettingValueInfo = provider(
    doc = "The value of a build setting as seen by the probe.",
    fields = {"value": "The build setting value."},
)

def _probe_impl(ctx):
    setting = ctx.attr.setting
    if ExtraExecRustcEnvInfo in setting:
        return [_SettingValueInfo(value = setting[ExtraExecRustcEnvInfo].extra_exec_rustc_env)]
    return [_SettingValueInfo(value = setting[BuildSettingInfo].value)]

_probe = rule(
    implementation = _probe_impl,
    attrs = {"setting": attr.label(mandatory = True)},
)

def _exec_probe_impl(ctx):
    return [ctx.attr.probe[_SettingValueInfo]]

_exec_probe = rule(
    implementation = _exec_probe_impl,
    attrs = {"probe": attr.label(cfg = "exec", mandatory = True)},
)

def _linker_preference_impl(env, target):
    env.expect.that_str(target[_SettingValueInfo].value).equals("rust")

def _use_default_shell_env_impl(env, target):
    env.expect.that_bool(target[_SettingValueInfo].value).equals(False)

def _extra_exec_rustc_env_impl(env, target):
    env.expect.that_dict(target[_SettingValueInfo].value).contains_exactly({"FOO": "bar"})

def _exec_setting_test(name, setting, value, impl):
    util.helper_target(
        _probe,
        name = name + "_probe",
        setting = setting,
    )
    util.helper_target(
        _exec_probe,
        name = name + "_exec_probe",
        probe = ":" + name + "_probe",
    )

    supported = bazel_features.toolchains.has_default_test_toolchain_type
    analysis_test(
        name = name,
        target = ":" + name + "_exec_probe",
        impl = impl,
        config_settings = {
            str(Label(setting)): value,
        } | ({
            "//command_line_option:incompatible_exclude_starlark_flags_from_exec_config": True,
        } if supported else {}),
        attr_values = {
            "target_compatible_with": [] if supported else ["@platforms//:incompatible"],
        },
    )

def _toolchain_linker_preference_test(name):
    _exec_setting_test(name, "//rust/settings:toolchain_linker_preference", "rust", _linker_preference_impl)

def _use_default_shell_env_test(name):
    _exec_setting_test(name, "//cargo/settings:use_default_shell_env", False, _use_default_shell_env_impl)

def _extra_exec_rustc_env_test(name):
    _exec_setting_test(name, "//rust/settings:extra_exec_rustc_env", ["FOO=bar"], _extra_exec_rustc_env_impl)

def exec_settings_test_suite(name):
    """Entry-point macro for the exec settings tests.

    Args:
        name: test suite name
    """
    test_suite(
        name = name,
        tests = [
            _toolchain_linker_preference_test,
            _use_default_shell_env_test,
            _extra_exec_rustc_env_test,
        ],
    )
