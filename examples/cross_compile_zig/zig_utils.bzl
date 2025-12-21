"""Utility rules"""

def _transition_platform_impl(_, attr):
    return {"//command_line_option:platforms": str(attr.platform)}

_transition_platform = transition(
    implementation = _transition_platform_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _platform_transition_filegroup_impl(ctx):
    files = depset(transitive = [src[DefaultInfo].files for src in ctx.attr.srcs])
    runfiles = ctx.runfiles().merge_all([src[DefaultInfo].default_runfiles for src in ctx.attr.srcs])

    return [DefaultInfo(
        files = files,
        runfiles = runfiles,
    )]

platform_transition_filegroup = rule(
    doc = "Transitions a target to the provided platform.",
    implementation = _platform_transition_filegroup_impl,
    attrs = {
        "platform": attr.label(
            doc = "The platform to transition to.",
            mandatory = True,
        ),
        "srcs": attr.label_list(
            doc = "The targets to transition",
            allow_files = True,
            cfg = _transition_platform,
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)
