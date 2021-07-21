"""This file contains definitions of all current incompatible flags.

See COMPATIBILITY.md for the backwards compatibility policy.
"""

IncompatibleFlagInfo = provider(
    doc = "Set the --error-format flag for all rustc invocations",
    fields = {
        "enabled": "(bool) whether the flag is enabled",
        "issue": "(string) link to the github issue associated with this flag",
    },
)

def _incompatible_flag_impl(ctx):
    return [IncompatibleFlagInfo(enabled = ctx.build_setting_value, issue = ctx.attr.issue)]

incompatible_flag = rule(
    doc = "A rule defining an incompatible flag.",
    implementation = _incompatible_flag_impl,
    build_setting = config.bool(flag = True),
    attrs = {
        "issue": attr.string(),
    },
)

def _fail_when_enabled_impl(ctx):
    flag = ctx.attr.flag
    flag_info = getattr(ctx.attr, "_" + flag)[IncompatibleFlagInfo]
    if flag_info.enabled:
        fail("Incompatible flag {} has been flipped, see {} for details.".format(flag, flag_info.issue))

fail_when_enabled = rule(
    doc = "A rule that will fail analysis when a flag is enabled.",
    implementation = _fail_when_enabled_impl,
    attrs = {
        "flag": attr.string(),
        "_split_rust_library": attr.label(default = "//rust/settings:split_rust_library"),
    },
)
