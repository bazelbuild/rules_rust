"""A `rustc_env_files`-format rule whose VALUE is a path-mapping-aware file path."""

load("@bazel_features//:features.bzl", "bazel_features")

def _arg_map_pair(value):
    key, file = value
    return "{}=${{pwd}}/{}".format(key, file.path)

def _env_file_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name + ".rustc_env")
    content = ctx.actions.args()
    content.set_param_file_format("multiline")
    content.add_all(
        [(ctx.attr.key, ctx.file.src)],
        map_each = _arg_map_pair,
        expand_directories = False,
    )

    if bazel_features.rules.write_action_has_execution_requirements:
        ctx.actions.write(
            output = out,
            content = content,
            execution_requirements = {"supports-path-mapping": ""},
        )
    else:
        ctx.actions.write(
            output = out,
            content = content,
        )
    return [DefaultInfo(files = depset([out]))]

env_file = rule(
    implementation = _env_file_impl,
    attrs = {
        "key": attr.string(
            doc = "Env-var name written as the LHS of the `KEY=<path>` line.",
            mandatory = True,
        ),
        "src": attr.label(
            doc = "Single file whose path-mapping-aware path becomes the value.",
            allow_single_file = True,
            mandatory = True,
        ),
    },
    doc = """\
Emit a one-line `KEY=${pwd}/<src.path>\\n` file suitable for `rust_library`'s
`rustc_env_files` attribute. The path is generated through `Args.add_all`'s
`format_each` so Bazel's path mapping (`--experimental_output_paths=strip`)
rewrites it before the action runs, and the `${pwd}` prefix is later resolved
to the exec_root by `process_wrapper`'s env-block substitution.

Pair with a matching `compile_data = [src]` on the consumer crate and use
`include_str!(env!("KEY"))` in Rust to embed the file's content at compile
time. Going through `rustc_env_files` + path-mapping-aware Args sidesteps
the `rustc_env = {"K": "$(execpath …)"}` trap, where the path is baked at
analysis time and never gets rewritten — the compile-time read then fails
to find the file under path mapping.
""",
)
