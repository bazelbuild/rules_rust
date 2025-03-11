"""Utilities for webdriver repositories"""

def _build_file_repository_impl(repository_ctx):
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    repository_ctx.file("BUILD.bazel", repository_ctx.read(repository_ctx.path(repository_ctx.attr.build_file)))

build_file_repository = repository_rule(
    doc = "A repository rule for generating external repositories with a specific build file.",
    implementation = _build_file_repository_impl,
    attrs = {
        "build_file": attr.label(
            doc = "The file to use as the BUILD file for this repository.",
            mandatory = True,
            allow_files = True,
        ),
    },
)

_WEBDRIVER_BUILD_CONTENT = """\
filegroup(
    name = "{name}",
    srcs = ["{tool}"],
    data = glob(
        include = [
            "**",
        ],
        exclude = [
            "*.bazel",
            "BUILD",
            "WORKSPACE",
        ],
    ),
    visibility = ["//visibility:public"],
)
"""

def _webdriver_repository_impl(repository_ctx):
    result = repository_ctx.download_and_extract(
        repository_ctx.attr.urls,
        stripPrefix = repository_ctx.attr.strip_prefix,
        integrity = repository_ctx.attr.integrity,
    )

    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.attr.original_name,
    ))

    repository_ctx.file("BUILD.bazel", _WEBDRIVER_BUILD_CONTENT.format(
        name = repository_ctx.attr.original_name,
        tool = repository_ctx.attr.tool,
    ))

    return {
        "integrity": result.integrity,
        "name": repository_ctx.name,
        "original_name": repository_ctx.attr.original_name,
        "strip_prefix": repository_ctx.attr.strip_prefix,
        "tool": repository_ctx.attr.tool,
        "urls": repository_ctx.attr.urls,
    }

webdriver_repository = repository_rule(
    doc = "A repository rule for downloading webdriver tools.",
    implementation = _webdriver_repository_impl,
    attrs = {
        "integrity": attr.string(
            doc = """Expected checksum in Subresource Integrity format of the file downloaded.""",
        ),
        # TODO: This can be removed in Bazel 8 and it's use moved to `repository_ctx.original_name`.
        "original_name": attr.string(
            doc = "The original name of the repository.",
        ),
        "strip_prefix": attr.string(
            doc = """A directory prefix to strip from the extracted files.""",
        ),
        "tool": attr.string(
            doc = "The name of the webdriver tool being downloaded.",
            mandatory = True,
        ),
        "urls": attr.string_list(
            doc = "A list of URLs to a file that will be made available to Bazel.",
            mandatory = True,
        ),
    },
)
