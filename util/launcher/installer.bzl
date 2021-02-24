"""A module defining the installer rule for the rules_rust test launcher"""

def _installer_impl(ctx):
    """The `installer` rule's implementation

    Args:
        ctx (ctx): The rule's context object

    Returns:
        list: A list a DefaultInfo provider
    """

    installer = ctx.actions.declare_file(ctx.file.src.basename)

    ctx.actions.expand_template(
        template = ctx.file.src,
        output = installer,
        substitutions = {},
        is_executable = True,
    )

    return [DefaultInfo(
        files = depset([installer]),
        executable = installer,
    )]

installer = rule(
    doc = "A rule which makes a native executable script available to other rules",
    implementation = _installer_impl,
    attrs = {
        "src": attr.label(
            allow_single_file = [".sh", ".bat"],
        ),
    },
    executable = True,
)
