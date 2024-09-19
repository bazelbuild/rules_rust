"""A small utility module dedicated to detecting whether or not the `--enable_runfiles` and `--windows_enable_symlinks` flag are enabled
"""

load("@bazel_skylib//lib:selects.bzl", "selects")
load("@bazel_skylib//rules:common_settings.bzl", "bool_setting")

RunfilesEnabledInfo = provider(
    doc = "A singleton provider that contains the raw value of a build setting",
    fields = {
        "value": "The value of the build setting in the current configuration. " +
                 "This value may come from the command line or an upstream transition, " +
                 "or else it will be the build setting's default.",
    },
)

def _runfiles_enabled_setting_impl(ctx):
    return RunfilesEnabledInfo(value = ctx.attr.value)

runfiles_enabled_setting = rule(
    implementation = _runfiles_enabled_setting_impl,
    doc = "A bool-typed build setting that cannot be set on the command line",
    attrs = {
        "value": attr.bool(
            doc = "A boolean value",
            mandatory = True,
        ),
    },
)

_RUNFILES_ENABLED_ATTR_NAME = "_runfiles_enabled"

def runfiles_enabled_attr(default):
    return {
        _RUNFILES_ENABLED_ATTR_NAME: attr.label(
            doc = "A flag representing whether or not runfiles are enabled.",
            providers = [RunfilesEnabledInfo],
            default = default,
            cfg = "exec",
        ),
    }

def runfiles_enabled_build_setting(name, **kwargs):
    """Define a build setting identifying if runfiles are enabled.

    Args:
        name (str): The name of the build setting
        **kwargs: Additional keyword arguments for the target.
    """
    native.config_setting(
        name = "{}__enable_runfiles".format(name),
        values = {"enable_runfiles": "true"},
    )

    native.config_setting(
        name = "{}__disable_runfiles".format(name),
        values = {"enable_runfiles": "false"},
    )

    bool_setting(
        name = "{}__always_true".format(name),
        build_setting_default = True,
    )

    native.config_setting(
        name = "{}__always_true_setting".format(name),
        flag_values = {":{}__always_true".format(name): "True"},
    )

    native.config_setting(
        name = "{}__always_false_setting".format(name),
        flag_values = {":{}__always_true".format(name): "False"},
    )

    # There is no way to query a setting that is unset. By utilizing constant
    # settings, we can filter to a fallback setting where no known value is
    # defined.
    native.alias(
        name = "{}__unset_runfiles".format(name),
        actual = select({
            ":{}__disable_runfiles".format(name): ":{}__always_false_setting".format(name),
            ":{}__enable_runfiles".format(name): ":{}__always_false_setting".format(name),
            "//conditions:default": ":{}__always_true_setting".format(name),
        }),
    )

    selects.config_setting_group(
        name = "{}__windows_enable_runfiles".format(name),
        match_all = [
            ":{}__enable_runfiles".format(name),
            "@platforms//os:windows",
        ],
    )

    selects.config_setting_group(
        name = "{}__windows_disable_runfiles".format(name),
        match_all = [
            ":{}__disable_runfiles".format(name),
            "@platforms//os:windows",
        ],
    )

    selects.config_setting_group(
        name = "{}__windows_unset_runfiles".format(name),
        match_all = [
            ":{}__unset_runfiles".format(name),
            "@platforms//os:windows",
        ],
    )

    native.alias(
        name = "{}__unix".format(name),
        actual = select({
            "@platforms//os:windows": ":{}__always_false_setting".format(name),
            "//conditions:default": ":{}__always_true_setting".format(name),
        }),
    )

    selects.config_setting_group(
        name = "{}__unix_enable_runfiles".format(name),
        match_all = [
            ":{}__enable_runfiles".format(name),
            ":{}__unix".format(name),
        ],
    )

    selects.config_setting_group(
        name = "{}__unix_disable_runfiles".format(name),
        match_all = [
            ":{}__disable_runfiles".format(name),
            ":{}__unix".format(name),
        ],
    )

    selects.config_setting_group(
        name = "{}__unix_unset_runfiles".format(name),
        match_all = [
            ":{}__unset_runfiles".format(name),
            ":{}__unix".format(name),
        ],
    )

    runfiles_enabled_setting(
        name = name,
        value = select({
            ":{}__windows_enable_runfiles".format(name): True,
            ":{}__windows_disable_runfiles".format(name): False,
            ":{}__windows_unset_runfiles".format(name): False,
            ":{}__unix_enable_runfiles".format(name): True,
            ":{}__unix_disable_runfiles".format(name): False,
            ":{}__unix_unset_runfiles".format(name): True,
            "//conditions:default": True,
        }),
        **kwargs
    )

def is_runfiles_enabled(attr):
    """Determine whether or not runfiles are enabled.

    Args:
        attr (struct): A rule's struct of attributes (`ctx.attr`)
    Returns:
        bool: The enable_runfiles value.
    """

    runfiles_enabled = getattr(attr, _RUNFILES_ENABLED_ATTR_NAME, None)

    return runfiles_enabled[RunfilesEnabledInfo].value if runfiles_enabled else True
