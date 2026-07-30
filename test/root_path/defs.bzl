"""Custom rule to package sources into a directory TreeArtifact for testing root_path."""

def _package_dir_artifact_impl(ctx):
    outdir = ctx.actions.declare_directory(ctx.attr.name + ".dir")

    args = ctx.actions.args()
    args.add(outdir.path)
    for src in ctx.files.srcs:
        args.add(src.path)

    ctx.actions.run_shell(
        outputs = [outdir],
        inputs = ctx.files.srcs,
        command = 'out="$1"; shift; mkdir -p "$out/src"; cp "$@" "$out/src/"',
        arguments = [args],
        progress_message = "Packaging srcs into directory artifact %s" % outdir.short_path,
    )

    return [
        DefaultInfo(files = depset([outdir])),
    ]

package_dir_artifact = rule(
    implementation = _package_dir_artifact_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = True,
            mandatory = True,
        ),
    },
)
