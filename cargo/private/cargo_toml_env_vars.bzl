def _cargo_toml_env_vars_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name + ".env")

    inputs = [ctx.file.src]
    args = ctx.actions.args()
    args.add(out)
    args.add(ctx.file.src)

    if ctx.attr.workspace:
        inputs.append(ctx.file.workspace)
        args.add(ctx.file.workspace)

    ctx.actions.run(
        outputs = [out],
        executable = ctx.file._cargo_toml_variable_extractor,
        inputs = inputs,
        arguments = [args],
    )

    return [
        DefaultInfo(files = depset([out]), runfiles = ctx.runfiles([out])),
    ]

cargo_toml_env_vars = rule(
    implementation = _cargo_toml_env_vars_impl,
    attrs = {
        "src": attr.label(allow_single_file = True, mandatory = True),
        "workspace": attr.label(allow_single_file = True),
        "_cargo_toml_variable_extractor": attr.label(allow_single_file = True, executable = True, default = "@rules_rust//cargo/cargo_toml_variable_extractor", cfg = "exec"),
    },
)
