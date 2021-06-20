"""Utility functions specific to the rust toolchain."""

load("@bazel_tools//tools/cpp:toolchain_utils.bzl", find_rules_cc_toolchain = "find_cpp_toolchain")

def find_toolchain(ctx):
    """Finds the first rust toolchain that is configured.

    Args:
        ctx (ctx): The ctx object for the current target.

    Returns:
        rust_toolchain: A Rust toolchain context.
    """

    return ctx.toolchains[Label("//rust:toolchain")]

def find_cc_toolchain(ctx):
    """Extracts a CcToolchain from the current target's context

    Args:
        ctx (ctx): The current target's rule context object

    Returns:
        tuple: A tuple of (CcToolchain, FeatureConfiguration)
    """
    cc_toolchain = find_rules_cc_toolchain(ctx)

    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    return cc_toolchain, feature_configuration

def find_sysroot(rust_toolchain, short_path = False):
    """Locate the sysroot for a given toolchain

    Args:
        rust_toolchain (rust_toolchain): A rust toolchain
        short_path (bool): Whether or not to use a short path to the sysroot

    Returns:
        str: The exec path of the toolchain's sysroot
    """
    if short_path:
        anchor_short_path = rust_toolchain.sysroot_anchor.short_path
        directory, _ = anchor_short_path.split(rust_toolchain.sysroot_anchor.basename, 1)
        return directory.rstrip("/")

    return rust_toolchain.sysroot_anchor.dirname

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
        # symlink matching this path can be created within the sysroot
        _, file_path = file.path.split(target.label.workspace_root, 1)
        symlink = ctx.actions.declare_file("{}/{}".format(name, file_path.lstrip("/")))

        ctx.actions.symlink(
            output = symlink,
            target_file = file,
        )

        tree_files.append(symlink)

    return depset(tree_files)

def _symlink_sysroot_bin(ctx, name, dir, target):
    """Crete a symlink to a target file.

    Args:
        ctx (ctx): The rule's context object
        name (str): A common name for the output directory
        dir (str): The directory under `name` to put the file in
        target (File): A File object to symlink to

    Returns:
        File: A newly generated symlink file
    """
    symlink = ctx.actions.declare_file("{}/{}/{}".format(
        name,
        dir.lstrip("/"),
        target.basename,
    ))

    ctx.actions.symlink(
        output = symlink,
        target_file = target,
        is_executable = True,
    )

    return symlink

def generate_sysroot(ctx):
    """Generate a rust sysroot from an exec and target toolchain

    Args:
        ctx (ctx): A context object from a `rust_toolchain` rule

    Returns:
        struct: A struct of generated files representing the new sysroot
    """
    name = ctx.label.name

    # Gather any components from an exec toolchain
    # Symlink rustc
    rustc = _symlink_sysroot_bin(ctx, name, "/bin", ctx.file.rustc)

    # Symlink rustdoc
    rustdoc = _symlink_sysroot_bin(ctx, name, "/bin", ctx.file.rustdoc)

    # Symlink rustc-lib
    rustc_lib = _symlink_sysroot_tree(ctx, name, ctx.attr.rustc_lib)

    exec_deps = [rustc, rustdoc]
    exec_transitive_deps = [depset([ctx.file.rustc, ctx.file.rustdoc]), ctx.attr.rustc_lib.files]

    # Gather any components from a target toolchain if one is available
    # Symlink rust-stdlib
    rust_stdlib = _symlink_sysroot_tree(ctx, name, ctx.attr.rust_stdlib)
    target_deps = []
    target_transitive_deps = [ctx.attr.rust_stdlib.files]

    # Declare a file in the root of the sysroot to make locating the sysroot easy
    sysroot_anchor = ctx.actions.declare_file("{}/rules_rust.sysroot".format(name))
    ctx.actions.write(
        output = sysroot_anchor,
        content = "\n".join([
            "rust_toolchain ctx: {}".format(ctx),
        ]),
    )

    # Create a depset of all sysroot files (symlinks and their real paths)
    sysroot_files = depset(
        exec_deps + target_deps + [sysroot_anchor],
        transitive = exec_transitive_deps + target_transitive_deps,
    )

    return struct(
        rust_stdlib = rust_stdlib,
        rustc = rustc,
        rustc_lib = rustc_lib,
        rustdoc = rustdoc,
        sysroot_anchor = sysroot_anchor,
        files = sysroot_files,
    )

def _toolchain_exec_files_impl(ctx):
    toolchain = ctx.toolchains[str(Label("//rust:toolchain"))]

    runfiles = None
    if ctx.attr.tool == "rustc":
        return [
            DefaultInfo(
                files = depset([toolchain.rustc]),
                runfiles = ctx.runfiles(transitive_files = toolchain.sysroot_files),
            ),
            OutputGroupInfo(
                # Useful for locating the sysroot at runtime
                sysroot_anchor = depset([toolchain.sysroot_anchor]),
            ),
        ]
    elif ctx.attr.tool == "rustdoc":
        return [
            DefaultInfo(
                files = depset([toolchain.rustdoc]),
                runfiles = ctx.runfiles(transitive_files = toolchain.sysroot_files),
            ),
            OutputGroupInfo(
                # Useful for locating the sysroot at runtime
                sysroot_anchor = depset([toolchain.sysroot_anchor]),
            ),
        ]
    elif ctx.attr.tool == "rustc_lib":
        return [DefaultInfo(
            files = toolchain.rustc_lib,
        )]
    elif ctx.attr.tool == "rustc_srcs":
        # It may be the case that the exec toolchain was created with
        # `include_rustc_srcs = False`. Optionally return files.
        if toolchain.rustc_srcs:
            return [DefaultInfo(
                files = toolchain.rustc_srcs.files,
            )]
        return []
    else:
        fail("Unsupported tool:", ctx.attr.tool)

_toolchain_exec_files_values = [
    "rustc",
    "rustdoc",
    "rustc_lib",
    "rustc_srcs",
]

toolchain_exec_files = rule(
    doc = "A rule for fetching files from a rust toolchain.",
    implementation = _toolchain_exec_files_impl,
    attrs = {
        "tool": attr.string(
            doc = "The desired tool to get form the current rust_toolchain",
            values = _toolchain_exec_files_values,
            mandatory = True,
        ),
    },
    toolchains = [
        str(Label("//rust:toolchain")),
    ],
    incompatible_use_toolchain_transition = True,
)

def _toolchain_target_files_impl(ctx):
    toolchain = ctx.toolchains[str(Label("//rust:toolchain"))]

    if ctx.attr.tool in ["rust_lib", "rust_stdlib"]:
        return [DefaultInfo(
            files = toolchain.rust_stdlib,
        )]

    fail("Unsupported tool:", ctx.attr.tool)

_toolchain_target_files_values = [
    "rust_lib",
    "rust_std",
    "rust_stdlib",
]

toolchain_target_files = rule(
    doc = "A rule for fetching files from a rust toolchain.",
    implementation = _toolchain_target_files_impl,
    attrs = {
        "tool": attr.string(
            doc = "The desired tool to get form the current rust_toolchain",
            values = _toolchain_target_files_values,
            mandatory = True,
        ),
    },
    toolchains = [
        str(Label("//rust:toolchain")),
    ],
    incompatible_use_toolchain_transition = True,
)

def _toolchain_cargo_files_impl(ctx):
    cargo_toolchain = ctx.toolchains[str(Label("//rust:cargo_toolchain"))]
    toolchain = ctx.toolchains[str(Label("//rust:toolchain"))]

    if ctx.attr.tool == "cargo":
        name = ctx.label.name
        cargo = _symlink_sysroot_bin(ctx, name, "/bin", cargo_toolchain.cargo)
        return [
            DefaultInfo(
                files = depset([cargo]),
                runfiles = ctx.runfiles(
                    files = [cargo_toolchain.cargo, cargo, toolchain.sysroot_anchor],
                    transitive_files = toolchain.sysroot_files,
                ),
            ),
            OutputGroupInfo(
                # Useful for locating the sysroot at runtime
                sysroot_anchor = depset([toolchain.sysroot_anchor]),
            ),
        ]
    else:
        fail("Unsupported tool:", ctx.attr.tool)

_toolchain_cargo_files_values = [
    "cargo",
]

toolchain_cargo_files = rule(
    doc = "A rule for fetching files from a rust toolchain.",
    implementation = _toolchain_cargo_files_impl,
    attrs = {
        "tool": attr.string(
            doc = "The desired tool to get form the current rust_toolchain",
            values = _toolchain_cargo_files_values,
            mandatory = True,
        ),
    },
    toolchains = [
        str(Label("//rust:cargo_toolchain")),
        str(Label("//rust:toolchain")),
    ],
    incompatible_use_toolchain_transition = True,
)

def _toolchain_clippy_files_impl(ctx):
    clippy_toolchain = ctx.toolchains[str(Label("//rust:clippy_toolchain"))]
    toolchain = ctx.toolchains[str(Label("//rust:toolchain"))]

    if ctx.attr.tool in ["clippy", "clippy_driver"]:
        name = ctx.label.name
        clippy = _symlink_sysroot_bin(ctx, name, "/bin", clippy_toolchain.clippy_driver)
        return [
            DefaultInfo(
                files = depset([clippy]),
                runfiles = ctx.runfiles(
                    files = [clippy_toolchain.clippy_driver, clippy, toolchain.sysroot_anchor],
                    transitive_files = toolchain.sysroot_files,
                ),
            ),
            OutputGroupInfo(
                # Useful for locating the sysroot at runtime
                sysroot_anchor = depset([toolchain.sysroot_anchor]),
            ),
        ]
    else:
        fail("Unsupported tool:", ctx.attr.tool)

_toolchain_clippy_files_values = [
    "clippy",
    "clippy_driver",
]

toolchain_clippy_files = rule(
    doc = "A rule for fetching files from a rust toolchain.",
    implementation = _toolchain_clippy_files_impl,
    attrs = {
        "tool": attr.string(
            doc = "The desired tool to get form the current rust_toolchain",
            values = _toolchain_clippy_files_values,
            mandatory = True,
        ),
    },
    toolchains = [
        str(Label("//rust:clippy_toolchain")),
        str(Label("//rust:toolchain")),
    ],
    incompatible_use_toolchain_transition = True,
)

def _toolchain_rustfmt_files_impl(ctx):
    rustfmt_toolchain = ctx.toolchains[str(Label("//rust:rustfmt_toolchain"))]
    toolchain = ctx.toolchains[str(Label("//rust:toolchain"))]

    if ctx.attr.tool == "rustfmt":
        name = ctx.label.name
        rustfmt = _symlink_sysroot_bin(ctx, name, "/bin", rustfmt_toolchain.rustfmt)
        return [
            DefaultInfo(
                files = depset([rustfmt]),
                runfiles = ctx.runfiles(
                    files = [rustfmt_toolchain.rustfmt, rustfmt, toolchain.sysroot_anchor],
                    transitive_files = toolchain.sysroot_files,
                ),
            ),
            OutputGroupInfo(
                # Useful for locating the sysroot at runtime
                sysroot_anchor = depset([toolchain.sysroot_anchor]),
            ),
        ]
    else:
        fail("Unsupported tool: ", ctx.attr.tool)

_toolchain_rustfmt_files_values = [
    "rustfmt",
]

toolchain_rustfmt_files = rule(
    doc = "A rule for fetching files from a rust toolchain.",
    implementation = _toolchain_rustfmt_files_impl,
    attrs = {
        "tool": attr.string(
            doc = "The desired tool to get form the current rust_toolchain",
            values = _toolchain_rustfmt_files_values,
            mandatory = True,
        ),
    },
    toolchains = [
        str(Label("//rust:rustfmt_toolchain")),
        str(Label("//rust:toolchain")),
    ],
    incompatible_use_toolchain_transition = True,
)

def toolchain_files(name, tool, **kwargs):
    """A rule for fetching files from a registered rust toolchain.

    Args:
        name (str): The name of the new target.
        tool (str): The tool to gather files for.
        **kwargs: Additional keyword args for the underlying toolchain_files rule.
    """
    if tool in _toolchain_exec_files_values:
        toolchain_exec_files(
            name = name,
            tool = tool,
            **kwargs
        )
    elif tool in _toolchain_target_files_values:
        toolchain_target_files(
            name = name,
            tool = tool,
            **kwargs
        )
    elif tool in _toolchain_cargo_files_values:
        toolchain_cargo_files(
            name = name,
            tool = tool,
            **kwargs
        )
    elif tool in _toolchain_clippy_files_values:
        toolchain_clippy_files(
            name = name,
            tool = tool,
            **kwargs
        )
    elif tool in _toolchain_rustfmt_files_values:
        toolchain_rustfmt_files(
            name = name,
            tool = tool,
            **kwargs
        )
    else:
        fail("Unexpected tool: {}".format(tool))
