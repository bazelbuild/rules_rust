"""BoringSSL Utils"""

def _boringssl_build_script_dir_impl(ctx):
    output = ctx.actions.declare_directory(ctx.attr.out)

    ssl = ctx.file.ssl
    crypto = ctx.file.crypto

    inputs = depset([ssl, crypto])

    ctx.actions.run(
        executable = ctx.executable._maker,
        oututs = [output],
        inputs = inputs,
        env = {
            "ARG_CRYPTO": crypto.path,
            "ARG_OUTPUT": output.path,
            "ARG_SSL": ssl.path,
        },
    )

    return [DefaultInfo(
        files = depset([output]),
        runfiles = ctx.runfiles([output]),
    )]

boringssl_build_script_dir = rule(
    doc = "A utility rule for building directories compatible with its `cargo_build_script` target.",
    implementation = _boringssl_build_script_dir_impl,
    attrs = {
        "crypto": attr.label(
            doc = "The `crypto`/`libcrypto` library.",
            allow_single_file = True,
            mandatory = True,
        ),
        "out": attr.string(
            doc = "The name of the output directory.",
            mandatory = True,
        ),
        "ssl": attr.label(
            doc = "The `ssl`/`libssl` library.",
            allow_single_file = True,
            mandatory = True,
        ),
        "_maker": attr.label(
            cfg = "exec",
            executable = True,
            default = Label("//crate_universe/complicated_dependencies:build_script_dir_maker"),
        ),
    },
)
