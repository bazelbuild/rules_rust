"""A module defining toolchain utilities"""

def find_sysroot(rust_toolchain):
    """Locate the rustc sysroot from the `rust_toolchain`

    Args:
        rust_toolchain (rust_toolchain): The currently configured `rust_toolchain`.

    Returns:
        str: A path assignable as `SYSROOT` for an action.
    """
    sysroot_anchor = rust_toolchain.rust_lib.files.to_list()[0]
    directory = sysroot_anchor.path.split(sysroot_anchor.short_path, 1)[0]
    return directory.rstrip("/")

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
