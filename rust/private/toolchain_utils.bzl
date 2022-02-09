"""A module defining toolchain utilities"""

def _symlink_sysroot_tree(ctx, name, target):
    """Generate a set of symlinks to files from another target

    Args:
        ctx (ctx): The toolchain's context object
        name (str): The name of the sysroot directory (typically `ctx.label.name`)
        target (Target): A target owning files to symlink

    Returns:
        depset[File]: A depset of the generated symlink files
    """
    tree_files = []
    for file in target.files.to_list():
        # Parse the path to the file relative to the workspace root so a
        # symlink matching this path can be created within the sysroot.

        # The code blow attempts to parse any workspace names out of the
        # path. For local targets, this code is a noop.
        if target.label.workspace_root:
            file_path = file.path.split(target.label.workspace_root, 1)[-1]
        else:
            file_path = file.path

        symlink = ctx.actions.declare_file("{}/{}".format(name, file_path.lstrip("/")))

        ctx.actions.symlink(
            output = symlink,
            target_file = file,
        )

        tree_files.append(symlink)

    return depset(tree_files)

def _symlink_sysroot_bin(ctx, name, directory, target):
    """Crete a symlink to a target file.

    Args:
        ctx (ctx): The rule's context object
        name (str): A common name for the output directory
        directory (str): The directory under `name` to put the file in
        target (File): A File object to symlink to

    Returns:
        File: A newly generated symlink file
    """
    symlink = ctx.actions.declare_file("{}/{}/{}".format(
        name,
        directory,
        target.basename,
    ))

    ctx.actions.symlink(
        output = symlink,
        target_file = target,
        is_executable = True,
    )

    return symlink

def generate_sysroot(
        ctx,
        rustc,
        rustdoc,
        rustc_lib,
        cargo = None,
        clippy = None,
        llvm_tools = None,
        rust_std = None,
        rustfmt = None):
    """Generate a rust sysroot from an exec and target toolchain

    Args:
        ctx (ctx): A context object from a `rust_toolchain` rule.
        rustc (File): The path to a `rustc` executable.
        rustdoc (File): The path to a `rustdoc` executable.
        rustc_lib (Target): A collection of Files containing dependencies of `rustc`.
        cargo (File, optional): The path to a `cargo` executable.
        clippy (File, optional): The path to a `clippy-driver` executable.
        llvm_tools (Target, optional): A collection of llvm tools used by `rustc`.
        rust_std (Target, optional): A collection of Files containing Rust standard library components.
        rustfmt (File, optional): The path to a `rustfmt` executable.

    Returns:
        struct: A struct of generated files representing the new sysroot
    """
    name = ctx.label.name

    # Define runfiles
    direct_files = []
    transitive_file_sets = []

    # Rustc
    sysroot_rustc = _symlink_sysroot_bin(ctx, name, "bin", rustc)
    direct_files.extend([sysroot_rustc, rustc])

    # Rustc dependencies
    sysroot_rustc_lib = _symlink_sysroot_tree(ctx, name, rustc_lib) if rustc_lib else None
    if sysroot_rustc_lib:
        transitive_file_sets.extend([sysroot_rustc_lib, rustc_lib.files])

    # Rustdoc
    sysroot_rustdoc = _symlink_sysroot_bin(ctx, name, "bin", rustdoc)
    direct_files.extend([sysroot_rustdoc, rustdoc])

    # Clippy
    sysroot_clippy = _symlink_sysroot_bin(ctx, name, "bin", clippy) if clippy else None
    if sysroot_clippy:
        direct_files.extend([sysroot_clippy, clippy])

    # Cargo
    sysroot_cargo = _symlink_sysroot_bin(ctx, name, "bin", cargo) if cargo else None
    if sysroot_cargo:
        direct_files.extend([sysroot_cargo, cargo])

    # Rustfmt
    sysroot_rustfmt = _symlink_sysroot_bin(ctx, name, "bin", rustfmt) if rustfmt else None
    if sysroot_rustfmt:
        direct_files.extend([sysroot_rustfmt, rustfmt])

    # Llvm tools
    sysroot_llvm_tools = _symlink_sysroot_tree(ctx, name, llvm_tools) if llvm_tools else None
    if sysroot_llvm_tools:
        transitive_file_sets.extend([sysroot_llvm_tools, llvm_tools.files])

    # Rust standard library
    sysroot_rust_std = _symlink_sysroot_tree(ctx, name, rust_std) if rust_std else None
    if sysroot_rust_std:
        transitive_file_sets.extend([sysroot_rust_std, rust_std.files])

    # Symlink rust-stdlib
    sysroot_rust_std = _symlink_sysroot_tree(ctx, name, rust_std) if rust_std else None
    if sysroot_rust_std:
        transitive_file_sets.extend([sysroot_rust_std, rust_std.files])

    # Declare a file in the root of the sysroot to make locating the sysroot easy
    sysroot_anchor = ctx.actions.declare_file("{}/rust.sysroot".format(name))
    ctx.actions.write(
        output = sysroot_anchor,
        content = "\n".join([
            "cargo: {}".format(cargo),
            "clippy: {}".format(clippy),
            "llvm_tools: {}".format(llvm_tools),
            "rust_std: {}".format(rust_std),
            "rustc_lib: {}".format(rustc_lib),
            "rustc: {}".format(rustc),
            "rustdoc: {}".format(rustdoc),
            "rustfmt: {}".format(rustfmt),
        ]),
    )

    # Create a depset of all sysroot files (symlinks and their real paths)
    all_files = depset(direct_files, transitive = transitive_file_sets)

    return struct(
        all_files = all_files,
        cargo = sysroot_cargo,
        clippy = sysroot_clippy,
        rust_std = sysroot_rust_std,
        rustc = sysroot_rustc,
        rustc_lib = sysroot_rustc_lib,
        rustdoc = sysroot_rustdoc,
        rustfmt = sysroot_rustfmt,
        sysroot_anchor = sysroot_anchor,
    )

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
    elif ctx.attr.tool == "rustc_srcs":
        files = toolchain.rustc_srcs.files
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
                "rustc_srcs",
                "rustc",
                "rustdoc",
                "rustfmt",
            ],
            mandatory = True,
        ),
    },
    toolchains = [
        str(Label("//rust:toolchain")),
    ],
    incompatible_use_toolchain_transition = True,
)
