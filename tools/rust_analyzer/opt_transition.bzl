"""Force a `rust_binary` (or any executable) to be compiled in `-c opt`
mode regardless of the parent build's compilation mode.

Used so the binaries `setup` copies into the user's launcher dir
(`discover_bazel_rust_project`, `flycheck`) are always the fastest
build available — these run on every save / discovery and pay the
performance gap between `fastbuild` and `opt` repeatedly. `setup`
itself runs once at install time and doesn't need this treatment.
"""

def _opt_transition_impl(_settings, _attr):
    return {"//command_line_option:compilation_mode": "opt"}

_opt_transition = transition(
    implementation = _opt_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:compilation_mode"],
)

def _opt_executable_impl(ctx):
    # `src` is a single-element list because of `cfg = transition`; the
    # transition splits 1->N but we never produce more than one output.
    src = ctx.attr.src[0]
    src_default = src[DefaultInfo]
    src_exe = src_default.files_to_run.executable
    out = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(output = out, target_file = src_exe, is_executable = True)
    return [DefaultInfo(
        executable = out,
        files = depset([out]),
        runfiles = src_default.default_runfiles,
    )]

opt_executable = rule(
    implementation = _opt_executable_impl,
    attrs = {
        "src": attr.label(
            cfg = _opt_transition,
            doc = "The target whose executable should be re-compiled in `-c opt`.",
            executable = True,
            mandatory = True,
        ),
        "_allowlist_function_transition": attr.label(
            default = Label("//tools/allowlists/function_transition_allowlist"),
        ),
    },
    doc = "Re-exposes the given executable target, compiled in `-c opt`.",
    executable = True,
)
