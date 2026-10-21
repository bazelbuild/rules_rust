"""The SPDX license kinds the `package_metadata` module declares, as a Starlark list."""

_KINDS_BZL = """\
\"\"\"The SPDX license kinds the `package_metadata` module declares.

Generated from `@package_metadata//licenses/spdx`; run
`bazel run //crate_universe/private/spdx:kinds.install` to update.
\"\"\"

SPDX_LICENSE_KINDS = [
{kinds}
]
"""

def _spdx_license_kinds_repository_impl(repository_ctx):
    # The module does not export the BUILD file, so no build action can read
    # it; a repository rule can, and the result is diffed against the recorded
    # list `//crate_universe/private/spdx` aliases and `cargo-bazel` renders
    # license kinds from.
    kinds = []
    in_kind = False
    for line in repository_ctx.read(repository_ctx.attr.build_file).splitlines():
        line = line.strip()
        if line.startswith("license_kind("):
            in_kind = True
        elif in_kind and line.startswith("name = \""):
            kinds.append(line[len("name = \""):].split("\"")[0])
            in_kind = False
    repository_ctx.file("kinds.bzl", _KINDS_BZL.format(
        kinds = "\n".join(["    \"{}\",".format(kind) for kind in sorted(kinds)]),
    ))
    repository_ctx.file("BUILD.bazel", "exports_files([\"kinds.bzl\"])\n")
    if hasattr(repository_ctx, "repo_metadata"):
        return repository_ctx.repo_metadata(reproducible = True)
    return None

spdx_license_kinds_repository = repository_rule(
    doc = (
        "Records the names of the `license_kind` targets of `@package_metadata//licenses/spdx` " +
        "in `kinds.bzl`, for `//crate_universe/private/spdx:kinds_diff_test`."
    ),
    attrs = {
        "build_file": attr.label(
            doc = "The `BUILD` file declaring the `license_kind` targets.",
            default = Label("@package_metadata//licenses/spdx:BUILD"),
            allow_single_file = True,
        ),
    },
    implementation = _spdx_license_kinds_repository_impl,
)
