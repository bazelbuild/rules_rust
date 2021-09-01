"""Utility functions specific to the rust toolchain."""

load("@bazel_skylib//lib:versions.bzl", "versions")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", find_rules_cc_toolchain = "find_cpp_toolchain")
load("@rules_rust_bazel_version//:version.bzl", "BAZEL_VERSION")

def find_toolchain(ctx):
    """Finds the first rust toolchain that is configured.

    Args:
        ctx (ctx): The ctx object for the current target.

    Returns:
        rust_toolchain: A Rust toolchain context.
    """
    if not versions.is_at_least("4.1.0", BAZEL_VERSION) and hasattr(ctx.attr, "_rust_toolchain"):
        return ctx.attr._rust_toolchain[platform_common.ToolchainInfo]

    return ctx.toolchains[Label("@rules_rust//rust:toolchain")]

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

def generate_sysroot(ctx, exec_toolchain = None, target_toolchain = None):
    """Generate a rust sysroot from an exec and target toolchain

    Args:
        ctx (ctx): A context object from a `rust_toolchain` rule
        exec_toolchain (rust_exec_toolchain, optional): A toolchain for the exec environment
        target_toolchain (rust_target_toolchain, optional): A toolchain for the target environment

    Returns:
        struct: A struct of generated files representing the new sysroot
    """
    name = ctx.label.name

    # Gather any components from an exec toolchain if one is available
    if not exec_toolchain:
        rustc = None
        rustdoc = None
        rustc_lib = depset([])
        exec_deps = []
        exec_transitive_deps = []
    else:
        # Symlink rustc
        rustc = _symlink_sysroot_bin(ctx, name, "/bin", exec_toolchain.rustc)

        # Symlink rustdoc
        rustdoc = _symlink_sysroot_bin(ctx, name, "/bin", exec_toolchain.rustdoc)

        # Symlink rustc-lib
        rustc_lib = _symlink_sysroot_tree(ctx, name, exec_toolchain.rustc_lib)

        exec_deps = [rustc, rustdoc, exec_toolchain.rustc, exec_toolchain.rustdoc]
        exec_transitive_deps = [rustc_lib, exec_toolchain.rustc_lib.files]

    # Gather any components from a target toolchain if one is available
    if not target_toolchain:
        rust_stdlib = depset([])
        target_deps = []
        target_transitive_deps = []
    else:
        # Symlink rust-stdlib
        rust_stdlib = _symlink_sysroot_tree(ctx, name, target_toolchain.rust_stdlib)
        target_deps = []
        target_transitive_deps = [rust_stdlib, target_toolchain.rust_stdlib.files]

    # Declare a file in the root of the sysroot to make locating the sysroot easy
    sysroot_anchor = ctx.actions.declare_file("{}/rules_rust.sysroot".format(name))
    ctx.actions.write(
        output = sysroot_anchor,
        content = "\n".join([
            "exec_toolchain: {}".format(exec_toolchain),
            "target_target: {}".format(target_toolchain),
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
        sysroot_files = sysroot_files,
    )

def _toolchain_exec_files_impl(ctx):
    toolchain = ctx.toolchains[str(Label("@rules_rust//rust:exec_toolchain"))]

    runfiles = None
    if ctx.attr.tool == "rustc":
        sysroot = generate_sysroot(ctx, exec_toolchain = toolchain)
        return [
            DefaultInfo(
                files = depset([sysroot.rustc]),
                runfiles = ctx.runfiles(transitive_files = sysroot.sysroot_files),
            ),
            OutputGroupInfo(
                # Useful for locating the sysroot at runtime
                sysroot_anchor = depset([sysroot.sysroot_anchor]),
            ),
        ]
    elif ctx.attr.tool == "rustdoc":
        sysroot = generate_sysroot(ctx, exec_toolchain = toolchain)
        return [
            DefaultInfo(
                files = depset([sysroot.rustdoc]),
                runfiles = ctx.runfiles(transitive_files = sysroot.sysroot_files),
            ),
            OutputGroupInfo(
                # Useful for locating the sysroot at runtime
                sysroot_anchor = depset([sysroot.sysroot_anchor]),
            ),
        ]
    elif ctx.attr.tool == "rustc_lib":
        return [DefaultInfo(
            files = toolchain.rustc_lib.files,
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
        str(Label("//rust:exec_toolchain")),
    ],
    incompatible_use_toolchain_transition = True,
)

def _toolchain_target_files_impl(ctx):
    toolchain = ctx.toolchains[str(Label("@rules_rust//rust:target_toolchain"))]

    runfiles = None
    if ctx.attr.tool in ["rust_lib", "rust_stdlib"]:
        files = toolchain.rust_stdlib.files
    else:
        fail("Unsupported tool: ", ctx.attr.tool)

    return [DefaultInfo(
        files = files,
        runfiles = runfiles,
    )]

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
        str(Label("//rust:target_toolchain")),
    ],
    incompatible_use_toolchain_transition = True,
)

def _toolchain_cargo_files_impl(ctx):
    cargo_toolchain = ctx.toolchains[str(Label("@rules_rust//rust:cargo_toolchain"))]
    exec_toolchain = ctx.toolchains[str(Label("@rules_rust//rust:exec_toolchain"))]

    if ctx.attr.tool == "cargo":
        sysroot = generate_sysroot(ctx, exec_toolchain = exec_toolchain)
        cargo = _symlink_sysroot_bin(ctx, ctx.label.name, "/bin", cargo_toolchain.cargo)
        return [
            DefaultInfo(
                files = depset([cargo]),
                runfiles = ctx.runfiles(
                    files = [cargo_toolchain.cargo, cargo],
                    transitive_files = sysroot.sysroot_files,
                ),
            ),
            OutputGroupInfo(
                # Useful for locating the sysroot at runtime
                sysroot_anchor = depset([sysroot.sysroot_anchor]),
            ),
        ]
    else:
        fail("Unsupported tool: ", ctx.attr.tool)

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
        str(Label("//rust:exec_toolchain")),
    ],
    incompatible_use_toolchain_transition = True,
)

def _toolchain_clippy_files_impl(ctx):
    clippy_toolchain = ctx.toolchains[str(Label("@rules_rust//rust:clippy_toolchain"))]
    exec_toolchain = ctx.toolchains[str(Label("@rules_rust//rust:exec_toolchain"))]

    if ctx.attr.tool in ["clippy", "clippy_driver"]:
        sysroot = generate_sysroot(ctx, exec_toolchain = exec_toolchain)
        clippy = _symlink_sysroot_bin(ctx, ctx.label.name, "/bin", clippy_toolchain.clippy_driver)
        return [
            DefaultInfo(
                files = depset([clippy]),
                runfiles = ctx.runfiles(
                    files = [clippy, clippy_toolchain.clippy_driver],
                    transitive_files = sysroot.sysroot_files,
                ),
            ),
            OutputGroupInfo(
                # Useful for locating the sysroot at runtime
                sysroot_anchor = depset([sysroot.sysroot_anchor]),
            ),
        ]
    else:
        fail("Unsupported tool: ", ctx.attr.tool)

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
        str(Label("//rust:exec_toolchain")),
    ],
    incompatible_use_toolchain_transition = True,
)

def _toolchain_rustfmt_files_impl(ctx):
    rustfmt_toolchain = ctx.toolchains[str(Label("@rules_rust//rust:rustfmt_toolchain"))]
    exec_toolchain = ctx.toolchains[str(Label("@rules_rust//rust:exec_toolchain"))]

    if ctx.attr.tool == "rustfmt":
        sysroot = generate_sysroot(ctx, exec_toolchain = exec_toolchain)
        rustfmt = _symlink_sysroot_bin(ctx, ctx.label.name, "/bin", rustfmt_toolchain.rustfmt)
        return [
            DefaultInfo(
                files = depset([rustfmt]),
                runfiles = ctx.runfiles(files = [rustfmt, rustfmt_toolchain.rustfmt], transitive_files = sysroot.sysroot_files),
            ),
            OutputGroupInfo(
                # Useful for locating the sysroot at runtime
                sysroot_anchor = depset([sysroot.sysroot_anchor]),
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
        str(Label("//rust:exec_toolchain")),
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
