"""crates_vendor repository rules"""

_ALIAS_TEMPLATE = """\
alias(
    name = "{alias_name}",
    actual = "{actual_label}",
    tags = ["manual"],
    visibility = ["//visibility:public"],
)
"""

def _crates_vendor_remote_repository_impl(repository_ctx):
    # If aliases is provided, build_file must not be provided
    if repository_ctx.attr.aliases and repository_ctx.attr.build_file:
        fail("Cannot provide both 'aliases' and 'build_file' attributes. Use 'aliases' for subpackage aliases or 'build_file' for root package BUILD file.")

    defs_module = repository_ctx.path(repository_ctx.attr.defs_module)
    repository_ctx.file("defs.bzl", repository_ctx.read(defs_module))
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    if repository_ctx.attr.aliases:
        # Render multiple BUILD files for aliases in subpackages
        # Each alias gets its own BUILD file in a subpackage named after the alias name
        # aliases maps String (actual label) -> String (alias name)
        root_aliases = []
        for alias_name, actual_label_str in repository_ctx.attr.aliases.items():
            # Create the subpackage directory and BUILD file
            # The alias_name is the subpackage name (e.g., "my_crate-0.1.0" -> "my_crate-0.1.0/BUILD.bazel")
            alias_build_content = _ALIAS_TEMPLATE.format(
                alias_name = alias_name,
                actual_label = actual_label_str,
            )
            repository_ctx.file("{}/BUILD.bazel".format(alias_name), alias_build_content)

            # If legacy_root_pkg_aliases is True, also create aliases in the root BUILD file
            if repository_ctx.attr.legacy_root_pkg_aliases:
                root_aliases.append(_ALIAS_TEMPLATE.format(
                    alias_name = alias_name,
                    actual_label = "//{}".format(alias_name),
                ))

        # Render root BUILD file with aliases if legacy mode is enabled
        if repository_ctx.attr.legacy_root_pkg_aliases:
            root_build_content = "\n".join(root_aliases) + "\n"
            repository_ctx.file("BUILD.bazel", root_build_content)
    elif repository_ctx.attr.build_file:
        # Render the root BUILD file
        build_file = repository_ctx.path(repository_ctx.attr.build_file)
        repository_ctx.file("BUILD.bazel", repository_ctx.read(build_file))
    else:
        fail("Must provide either 'aliases' or 'build_file' attribute. Please update {}".format(
            repository_ctx.name,
        ))

crates_vendor_remote_repository = repository_rule(
    doc = "Creates a repository paired with `crates_vendor` targets using the `remote` vendor mode.",
    implementation = _crates_vendor_remote_repository_impl,
    attrs = {
        "aliases": attr.string_dict(
            doc = "A dictionary mapping alias actual values (label strings) to alias names. Each alias gets its own BUILD file in a subpackage named after the alias name. Cannot be provided if 'build_file' is set.",
            default = {},
        ),
        "build_file": attr.label(
            doc = "The BUILD file to use for the root package. Cannot be provided if 'aliases' is set.",
            mandatory = False,
        ),
        "defs_module": attr.label(
            doc = "The `defs.bzl` file to use in the repository",
            mandatory = True,
        ),
        "legacy_root_pkg_aliases": attr.bool(
            doc = "If True and `aliases` is provided, also creates aliases in the root BUILD file with `name=\"{alias_name}\"` and `actual=\"//{alias_name}\"`. This provides backward compatibility for accessing aliases from the root package.",
            default = True,
        ),
    },
)
