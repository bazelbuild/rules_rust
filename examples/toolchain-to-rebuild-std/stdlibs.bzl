def _stdlibs_impl(repository_ctx):
    repository_ctx.download_and_extract(
        url = "https://static.rust-lang.org/dist/" + repository_ctx.attr.beta_date + "/rustc-beta-src.tar.gz",
        type = "tar.gz",
        stripPrefix = "rustc-beta-src",
    )

    repository_ctx.file(
        "BUILD.bazel",
        content = repository_ctx.read(repository_ctx.attr.build_file),
    )

stdlibs = repository_rule(
    implementation = _stdlibs_impl,
    attrs = {
        "beta_date": attr.string(mandatory = True),
        "build_file": attr.label(mandatory = True),
    },
)
