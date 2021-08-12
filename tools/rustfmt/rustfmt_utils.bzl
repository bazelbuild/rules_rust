"""A helper module for the `@rules_rust//tools/rustfmt` package"""

def aspect_repository():
    """Determines the repository name to use for the `rustfmt_manifest` aspect in `rustfmt` binaries.

    The `//tools/rustfmt` target has a hard coded `--aspects` command built into it.
    This function is designed to allow for this aspect to be updated to work within
    the `rules_rust` repository itself since aspects do not work if the repository name
    is explicitly set.

    https://github.com/bazelbuild/rules_rust/issues/749

    Returns:
        str: The string to use for the `rustfmt_aspect` repository
    """
    if native.repository_name() == "@":
        return ""
    return native.repository_name()
