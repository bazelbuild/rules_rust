"""A module defining toolchain utilities"""

def find_sysroot(rust_toolchain, short_path = False):
    """Locate the sysroot for a given toolchain

    Args:
        rust_toolchain (rust_toolchain): A rust toolchain
        short_path (bool): Whether or not to use a short path to the sysroot

    Returns:
        str, optional: The path of the toolchain's sysroot
    """

    # Sysroot is determined by using a rust stdlib file, expected to be at
    # `${SYSROOT}/lib/rustlib/${target_triple}/lib`, and strip the known
    # directories from the sysroot path.
    rust_stdlib_files = rust_toolchain.rust_lib.files.to_list()
    if rust_stdlib_files:
        # Determine the sysroot by taking a rust stdlib file, expected to be `${sysroot}/lib`
        if short_path:
            split = rust_stdlib_files[0].short_path.rsplit("/", 5)
        else:
            split = rust_stdlib_files[0].path.rsplit("/", 5)
        sysroot = split[0]
        return sysroot

    return None

def _toolchain_files_impl(ctx):
    toolchain = ctx.toolchains[str(Label("//rust:toolchain"))]

    runfiles = None
    if ctx.attr.tool == "cargo":
        files = depset([toolchain.cargo])
        runfiles = ctx.runfiles(
            files = [
                toolchain.cargo,
                toolchain.rustc,
            ],
            transitive_files = toolchain.rustc_lib.files,
        )
    elif ctx.attr.tool == "clippy":
        files = depset([toolchain.clippy_driver])
        runfiles = ctx.runfiles(
            files = [
                toolchain.clippy_driver,
                toolchain.rustc,
            ],
            transitive_files = toolchain.rustc_lib.files,
        )
    elif ctx.attr.tool == "rustc":
        files = depset([toolchain.rustc])
        runfiles = ctx.runfiles(
            files = [toolchain.rustc],
            transitive_files = toolchain.rustc_lib.files,
        )
    elif ctx.attr.tool == "rustdoc":
        files = depset([toolchain.rust_doc])
        runfiles = ctx.runfiles(
            files = [toolchain.rust_doc],
            transitive_files = toolchain.rustc_lib.files,
        )
    elif ctx.attr.tool == "rustfmt":
        files = depset([toolchain.rustfmt])
        runfiles = ctx.runfiles(
            files = [toolchain.rustfmt],
            transitive_files = toolchain.rustc_lib.files,
        )
    elif ctx.attr.tool == "rustc_lib":
        files = toolchain.rustc_lib.files
    elif ctx.attr.tool == "rustc_srcs":
        files = toolchain.rustc_srcs.files
    elif ctx.attr.tool == "rust_lib" or ctx.attr.tool == "rust_stdlib":
        files = toolchain.rust_lib.files
    else:
        fail("Unsupported tool: ", ctx.attr.tool)

    return [DefaultInfo(
        files = files,
        runfiles = runfiles,
    )]

toolchain_files = rule(
    doc = "A rule for fetching files from a rust toolchain.",
    implementation = _toolchain_files_impl,
    attrs = {
        "tool": attr.string(
            doc = "The desired tool to get form the current rust_toolchain",
            values = [
                "cargo",
                "clippy",
                "rustc",
                "rustdoc",
                "rustfmt",
                "rustc_lib",
                "rustc_srcs",
                "rust_lib",
                "rust_stdlib",
            ],
            mandatory = True,
        ),
    },
    toolchains = [
        str(Label("//rust:toolchain")),
    ],
    incompatible_use_toolchain_transition = True,
)
