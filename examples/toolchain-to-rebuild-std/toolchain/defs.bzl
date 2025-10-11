def _beta_channel_transition_impl(_, __):
    return {
        "//command_line_option:extra_toolchains": [],
        "@rules_rust//rust/toolchain/channel:channel": "beta",
        "//command_line_option:compilation_mode": "opt",
    }

_beta_channel_transition = transition(
    inputs = [],
    outputs = [
        "//command_line_option:extra_toolchains",
        "@rules_rust//rust/toolchain/channel:channel",
        "//command_line_option:compilation_mode",
    ],
    implementation = _beta_channel_transition_impl,
)

def _with_beta_channel_transition_impl(ctx):
    return [DefaultInfo(files = depset(ctx.files.srcs))]

with_beta_channel = rule(
    implementation = _with_beta_channel_transition_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = True,
        ),
        "_allowlist_function_transition": attr.label(
            default = Label("@bazel_tools//tools/allowlists/function_transition_allowlist"),
        ),
    },
    cfg = _beta_channel_transition,
)

def _toolchain_sysroot_impl(ctx):
    sysroot = ctx.attr.dirname
    outputs = []

    rustlibdir = "{}/lib/rustlib/{}/lib".format(sysroot, ctx.attr.target_triple)
    rustbindir = "{}/bin".format(sysroot)

    for inp in ctx.files.srcs:
        if inp.short_path in ctx.attr.tools:
            out = ctx.actions.declare_file(rustbindir + "/" + ctx.attr.tools[inp.short_path])
        else:
            out = ctx.actions.declare_file(rustlibdir + "/" + inp.basename)

        outputs.append(out)
        ctx.actions.symlink(output = out, target_file = inp)

    return [DefaultInfo(
        files = depset(outputs),
        runfiles = ctx.runfiles(files = outputs),
    )]

toolchain_sysroot = rule(
    implementation = _toolchain_sysroot_impl,
    attrs = {
        "dirname": attr.string(
            mandatory = True,
        ),
        "target_triple": attr.string(
            doc = "The target triple for the rlibs.",
            default = "x86_64-unknown-linux-gnu",
        ),
        "srcs": attr.label_list(
            allow_files = True,
        ),
        "tools": attr.string_dict(
            doc = "A map from tool's short_path to its final name under bin/",
        ),
    },
)
