"""Utility rules"""

def _transition_platform_impl(_, attr):
    return {"//command_line_option:platforms": str(attr.platform)}

_transition_platform = transition(
    implementation = _transition_platform_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _platform_transition_binary_impl(ctx):
    default_info = ctx.attr.binary[0][DefaultInfo]
    executable = ctx.executable.binary

    output = ctx.actions.declare_file("{}.{}".format(ctx.label.name, executable.extension).rstrip("."))
    ctx.actions.symlink(
        output = output,
        target_file = executable,
        is_executable = True,
    )
    files = depset(direct = [executable], transitive = [default_info.files])
    runfiles = ctx.runfiles([output, executable]).merge(default_info.default_runfiles)

    return [DefaultInfo(
        files = files,
        runfiles = runfiles,
        executable = output,
    )]

platform_transition_binary = rule(
    doc = "Transitions a target to the provided platform.",
    implementation = _platform_transition_binary_impl,
    attrs = {
        "binary": attr.label(
            doc = "The target to transition",
            allow_single_file = True,
            cfg = _transition_platform,
            executable = True,
        ),
        "platform": attr.label(
            doc = "The platform to transition to.",
            mandatory = True,
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    executable = True,
)
