"""Test transitions to test panic_style."""

def _panic_style_transition_impl(_settings, attr):
    return {
        "//:panic_style": attr.panic_style,
    }

_panic_style_transition = transition(
    implementation = _panic_style_transition_impl,
    inputs = [],
    outputs = ["//:panic_style"],
)

def _with_panic_style_cfg_impl(ctx):
    return [DefaultInfo(files = depset(ctx.files.srcs))]

with_panic_style_cfg = rule(
    implementation = _with_panic_style_cfg_impl,
    attrs = {
        "panic_style": attr.string(mandatory = True),
        "srcs": attr.label_list(
            allow_files = True,
            cfg = _panic_style_transition,
        ),
        "_allowlist_function_transition": attr.label(
            default = Label("//tools/allowlists/function_transition_allowlist"),
        ),
    },
)
