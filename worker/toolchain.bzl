"""
Define a worker toolchain.
"""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

def _worker_toolchain_impl(ctx):
    if ctx.attr.enabled[BuildSettingInfo].value:
        binary = ctx.executable.worker_binary
    else:
        binary = None

    toolchain_info = platform_common.ToolchainInfo(
        worker_binary = binary,
    )
    return [toolchain_info]

worker_toolchain = rule(
    implementation = _worker_toolchain_impl,
    attrs = {
        "worker_binary": attr.label(allow_single_file = True, executable = True, cfg = "exec"),
        "enabled": attr.label(),
    },
)
