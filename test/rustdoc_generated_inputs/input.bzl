"""Expose an environment file built in an execution configuration."""

def _exec_file_impl(ctx):
    return [DefaultInfo(files = ctx.attr.src[DefaultInfo].files)]

exec_file = rule(
    implementation = _exec_file_impl,
    attrs = {
        "src": attr.label(mandatory = True, cfg = "exec"),
    },
)
