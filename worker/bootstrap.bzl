"""
A simplified rust_binary implementation based on cargo so we can compile
the worker binary.

If using this on Windows, it's a good idea to place the following in your .bazelrc:

build:windows --worker_quit_after_build

This will ensure workers quit at the end of a build. If they're allowed to continue
running until Bazel shuts down, configuration changes that prompt the worker to be
recompiled will fail, as we can't write to a running .exe file on Windows.
"""

load("@io_bazel_rules_rust//rust:private/rustc.bzl", "get_cc_toolchain", "get_linker_and_args")

def _rewrite_to_unix_path(path):
    if not path:
        return ""
    drive = path[0]
    return "/" + drive + path[2:].replace("\\", "/")

def _rewrite_to_unix_paths(paths):
    """Turn a semicolon-delimited set of Windows paths into their Unix equivalents."""
    return ":".join([_rewrite_to_unix_path(path) for path in paths.split(";")])

def _get_windows_env_vars(ctx):
    """Get required PATH and LIB env vars on Windows.

    Returns (path, lib).

    We must prepend PATH to the standard run_shell() path so that MSVC's link.exe is found
    instead of MSYS's.

    LIB must be defined for linking to succeed on Windows."""

    cc_toolchain, feature_configuration = get_cc_toolchain(ctx)
    _, _, env = get_linker_and_args(ctx, cc_toolchain, feature_configuration, depset())

    lib = env.get("LIB", "")
    if not lib:
        # not MSVC
        return "", ""

    lib = _rewrite_to_unix_path(lib)
    path = _rewrite_to_unix_paths(env["PATH"])

    return path, lib

def _rust_binary_impl(ctx):
    toolchain = ctx.toolchains["@io_bazel_rules_rust//rust:toolchain"]
    output = ctx.actions.declare_file(ctx.label.name + toolchain.binary_ext)
    cache_dir = ctx.actions.declare_directory(ctx.label.name + "_cache")
    target_dir = ctx.actions.declare_directory(ctx.label.name + "_target")
    folder = ctx.files.srcs[0].dirname
    rust_bin = toolchain.cargo.dirname
    msvc_path, msvc_lib = _get_windows_env_vars(ctx)

    ctx.actions.run_shell(
        inputs = ctx.files.srcs,
        outputs = [output, cache_dir, target_dir],
        command = """\
export RUSTC="$(pwd)/{rustc}"; \
export CARGO="$(pwd)/{cargo}"; \
export OUTPUT="$(pwd)/{output}"; \
export CARGO_HOME="$(pwd)/{cache_dir}"; \
export CARGO_TARGET_DIR="$(pwd)/{target_dir}"; \
export PATH="{msvc_path}:$PATH"; \
export LIB="{msvc_lib}"; \
cd {folder} && \
"$CARGO" build -q --release && \
mv $CARGO_TARGET_DIR/release/rustc-worker "$OUTPUT" """.format(
            rust_bin = rust_bin,
            folder = folder,
            cargo = toolchain.cargo.path,
            rustc = toolchain.rustc.path,
            output = output.path,
            cache_dir = cache_dir.path,
            target_dir = target_dir.path,
            msvc_path = msvc_path,
            msvc_lib = msvc_lib,
        ),
        tools = [toolchain.cargo, toolchain.rustc] + toolchain.rust_lib.files.to_list() + toolchain.rustc_lib.files.to_list(),
        use_default_shell_env = True,
        progress_message = "Building rust worker",
    )
    return [
        DefaultInfo(executable = output),
    ]

rust_cargo_binary = rule(
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "_cc_toolchain": attr.label(
            default = "@bazel_tools//tools/cpp:current_cc_toolchain",
        ),
    },
    fragments = ["cpp"],
    host_fragments = ["cpp"],
    executable = True,
    toolchains = [
        "@bazel_tools//tools/cpp:toolchain_type",
        "@io_bazel_rules_rust//rust:toolchain",
    ],
    implementation = _rust_binary_impl,
    doc = "Internal, do not use this.",
)
