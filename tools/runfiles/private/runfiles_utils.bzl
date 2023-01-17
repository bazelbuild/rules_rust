"""Utilities for the `@rules_rust//tools/runfiles` library"""

_RULES_RUST_RUNFILES_WORKSPACE_NAME = "RULES_RUST_RUNFILES_WORKSPACE_NAME"

def _workspace_name_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name)

    ctx.actions.write(
        output = output,
        content = "{}={}\n".format(
            _RULES_RUST_RUNFILES_WORKSPACE_NAME,
            ctx.workspace_name,
        ),
    )

    return [DefaultInfo(
        files = depset([output]),
    )]

workspace_name = rule(
    implementation = _workspace_name_impl,
    doc = """\
A rule for detecting the current workspace name and writing it to a file for
for use with `rustc_env_files` attributes on `rust_*` rules. The workspace
name is exposed by the variable `{}`.""".format(_RULES_RUST_RUNFILES_WORKSPACE_NAME),
)
