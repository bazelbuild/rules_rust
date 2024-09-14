"""A small utility module dedicated to detecting whether or not the `--enable_runfiles` and `--windows_enable_symlinks` flag are enabled
"""

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

def runfiles_enabled_attr(default = Label("//cargo/private:runfiles_enabled")):
    return {
        _RUNFILES_ENABLED_ATTR_NAME: attr.label(
            doc = "A flag representing whether or not runfiles are enabled.",
            providers = [RunfilesEnabledInfo],
            default = default,
            cfg = "exec",
        ),
    }

def runfiles_enabled_build_setting(name, **kwargs):
    native.config_setting(
        name = "{}_enable_runfiles".format(name),
        values = {"enable_runfiles": "true"},
    )

    native.config_setting(
        name = "{}_disable_runfiles".format(name),
        values = {"enable_runfiles": "false"},
    )

    runfiles_enabled_setting(
        name = name,
        value = select({
            # If either of the runfiles are set, use the flag
            ":{}_enable_runfiles".format(name): True,
            ":{}_disable_runfiles".format(name): False,
            # Otherwise fall back to the system default.
            "@platforms//os:windows": False,
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
