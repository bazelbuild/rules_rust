"""package_dir_artifact"""

def _package_dir_artifact_impl(ctx):
    outdir = ctx.actions.declare_directory(ctx.attr.name + ".dir")

    args = ctx.actions.args()
    args.add_all([outdir], expand_directories = False)
    args.add_all(ctx.files.srcs)

    ctx.actions.run(
        executable = ctx.executable._packager,
        outputs = [outdir],
        inputs = ctx.files.srcs,
        arguments = [args],
        mnemonic = "PackageDirArtifact",
        progress_message = "Packaging srcs into directory artifact %s" % outdir.short_path,
    )

    return [
        DefaultInfo(files = depset([outdir])),
    ]

package_dir_artifact = rule(
    doc = "Custom rule to package sources into a directory TreeArtifact for testing root_path",
    implementation = _package_dir_artifact_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = True,
            mandatory = True,
        ),
        "_packager": attr.label(
            default = Label("//test/root_path:dir_artifact_packager"),
            executable = True,
            cfg = "exec",
        ),
    },
)
