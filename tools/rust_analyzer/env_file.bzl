"""A `rustc_env_files`-format rule whose file paths follow the consuming action."""

def _env_file_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name + ".rustc_env")

    # ':' reserves this namespace; escape '%' first to keep keys injective.
    substitution = "rustc_env_file:" + out.short_path.replace("%", "%25").replace("=", "%3D")
    source_root = ctx.file.src.root.path
    root_components = source_root.split("/")

    # Generated inputs share this rule's configuration; defer that component to
    # the consuming action while preserving their repository and output root.
    source_path = (
        ctx.file.src.path if ctx.file.src.is_source else "{}/${{{}}}/{}/{}".format(
            "/".join(root_components[:-2]),
            substitution,
            root_components[-1],
            ctx.file.src.path[len(source_root) + 1:],
        )
    )
    ctx.actions.write(
        output = out,
        content = "{}=${{pwd}}/{}\n".format(ctx.attr.key, source_path),
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
Emit a `KEY=${pwd}/<source-path>\\n` file suitable for `rustc_env_files`.
Generated inputs share this rule's configuration. A File-backed substitution
selects the consuming action's mapped or unmapped configuration while preserving
the input's repository and output root.

Pair with a matching `compile_data = [src]` on the consumer crate and use
`include_str!(env!("KEY"))` in Rust to embed the file's content at compile
time. Going through `rustc_env_files` + path-mapping-aware Args sidesteps
the `rustc_env = {"K": "$(execpath …)"}` trap, where the path is baked at
analysis time and never gets rewritten — the compile-time read then fails
to find the file under path mapping.
""",
)
