"""A module defining toolchain utilities"""

def _toolchain_files_impl(ctx):
    toolchain = ctx.toolchains[str(Label("//rust:toolchain_type"))]

    runfiles = None
    if ctx.attr.tool == "cargo":
        files = depset([toolchain.cargo])
        runfiles = ctx.runfiles(
            files = [
                toolchain.cargo,
                toolchain.rustc,
            ],
            transitive_files = toolchain.rustc_lib,
        )
    elif ctx.attr.tool == "clippy":
        files = depset([toolchain.clippy_driver])
        runfiles = ctx.runfiles(
            files = [
                toolchain.clippy_driver,
                toolchain.rustc,
            ],
            transitive_files = toolchain.rustc_lib,
        )
    elif ctx.attr.tool == "rustc":
        files = depset([toolchain.rustc])
        runfiles = ctx.runfiles(
            files = [toolchain.rustc],
            transitive_files = toolchain.rustc_lib,
        )
    elif ctx.attr.tool == "rustdoc":
        files = depset([toolchain.rust_doc])
        runfiles = ctx.runfiles(
            files = [toolchain.rust_doc],
            transitive_files = toolchain.rustc_lib,
        )
    elif ctx.attr.tool == "rustfmt":
        files = depset([toolchain.rustfmt])
        runfiles = ctx.runfiles(
            files = [toolchain.rustfmt],
            transitive_files = toolchain.rustc_lib,
        )
    elif ctx.attr.tool == "rustc_lib":
        files = toolchain.rustc_lib
    elif ctx.attr.tool == "rust_std" or ctx.attr.tool == "rust_stdlib" or ctx.attr.tool == "rust_lib":
        files = toolchain.rust_std
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
                "rust_lib",
                "rust_std",
                "rust_stdlib",
                "rustc_lib",
                "rustc",
                "rustdoc",
                "rustfmt",
            ],
            mandatory = True,
        ),
    },
    toolchains = [
        str(Label("//rust:toolchain_type")),
    ],
    incompatible_use_toolchain_transition = True,
)

def _current_rust_toolchain_impl(ctx):
    toolchain = ctx.toolchains[str(Label("@rules_rust//rust:toolchain_type"))]

    files = [
        toolchain.rustc,
        toolchain.rust_doc,
        toolchain.cargo,
    ]

    if toolchain.rustfmt:
        files.append(toolchain.rustfmt)

    return [
        toolchain,
        toolchain.make_variables,
        DefaultInfo(
            files = depset(files),
        ),
    ]

current_rust_toolchain = rule(
    doc = "A rule for exposing the current registered `rust_toolchain`.",
    implementation = _current_rust_toolchain_impl,
    toolchains = [
        str(Label("@rules_rust//rust:toolchain_type")),
    ],
    incompatible_use_toolchain_transition = True,
)
