load("@io_bazel_rules_rust//rust:private/rustc.bzl", "BuildInfo", "DepInfo", "get_compilation_mode_opts")
load("@io_bazel_rules_rust//rust:private/utils.bzl", "find_toolchain")
load("@io_bazel_rules_rust//rust:rust.bzl", "rust_binary")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")

def _cargo_build_script_run(ctx, script):
    toolchain = find_toolchain(ctx)
    out_dir = ctx.actions.declare_directory(ctx.label.name + ".out_dir")
    env_out = ctx.actions.declare_file(ctx.label.name + ".env")
    dep_env_out = ctx.actions.declare_file(ctx.label.name + ".depenv")
    flags_out = ctx.actions.declare_file(ctx.label.name + ".flags")
    manifest_dir = "%s.runfiles/%s" % (script.path, ctx.label.workspace_name or ctx.workspace_name)
    compilation_mode_opt_level = get_compilation_mode_opts(ctx, toolchain).opt_level

    crate_name = ctx.attr.crate_name
    # Derive crate name from the rule label which is <crate_name>_build_script if not provided.
    if not crate_name:
        crate_name = ctx.label.name
        if crate_name.endswith("_build_script"):
            crate_name = crate_name.replace("_build_script", "")
        crate_name = crate_name.replace("_", "-")

    env = {
        "CARGO_CFG_TARGET_ARCH": toolchain.target_arch,
        "CARGO_MANIFEST_DIR": manifest_dir,
        "HOST": toolchain.exec_triple,
        "OPT_LEVEL": compilation_mode_opt_level,
        "OUT_DIR": out_dir.path,
        "RUSTC": toolchain.rustc.path,
        "RUST_BACKTRACE": "full",
        "TARGET": toolchain.target_triple,
    }

    cc_toolchain = find_cpp_toolchain(ctx)
    cc_executable = cc_toolchain and cc_toolchain.compiler_executable
    if cc_executable:
        env["CC"] = cc_executable

    for f in ctx.attr.crate_features:
        env["CARGO_FEATURE_" + f.upper().replace("-", "_")] = "1"

    tools = depset(
        direct = [
            script,
            ctx.executable._cargo_build_script_runner,
            toolchain.rustc,
        ],
        transitive = [
            # Needed for rustc to function.
            toolchain.rustc_lib.files,
            toolchain.rust_lib.files,
        ],
    )

    # dep_env_file contains additional environment variables coming from
    # direct dependency sys-crates' build scripts. These need to be made
    # available to the current crate build script.
    # See https://doc.rust-lang.org/cargo/reference/build-scripts.html#-sys-packages
    # for details.
    cmd = ""
    dep_env_files = []
    for dep in ctx.attr.deps:
        if DepInfo in dep and dep[DepInfo].dep_env:
            dep_env_file = dep[DepInfo].dep_env
            cmd += "export $(cat %s); " % dep_env_file.path
            dep_env_files.append(dep_env_file)
    cmd += "$@"

    ctx.actions.run_shell(
        command = cmd,
        arguments = [ctx.executable._cargo_build_script_runner.path, script.path, crate_name, env_out.path, flags_out.path, dep_env_out.path],
        outputs = [out_dir, env_out, flags_out, dep_env_out],
        tools = tools,
        inputs = dep_env_files,
        mnemonic = "CargoBuildScriptRun",
        env = env,
    )

    return [
        BuildInfo(
            out_dir = out_dir,
            rustc_env = env_out,
            dep_env = dep_env_out,
            flags = flags_out,
        ),
    ]

def _build_script_impl(ctx):
    return _cargo_build_script_run(ctx, ctx.executable.script)

_build_script_run = rule(
    _build_script_impl,
    attrs = {
        "script": attr.label(
            executable = True,
            allow_files = True,
            mandatory = True,
            cfg = "host",
            doc = "The binary script to run, generally a rust_binary target. ",
        ),
        "crate_name": attr.string(),
        "crate_features": attr.string_list(doc = "The list of rust features that the build script should consider activated."),
        "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
        "_cargo_build_script_runner": attr.label(
            executable = True,
            allow_files = True,
            default = Label("//cargo/cargo_build_script_runner:cargo_build_script_runner"),
            cfg = "host",
        ),
        "deps": attr.label_list(),
    },
    toolchains = [
        "@io_bazel_rules_rust//rust:toolchain",
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
)

def cargo_build_script(name, crate_name="", crate_features=[], deps=[], **kwargs):
    """
    Compile and execute a rust build script to generate build attributes

    This rules take the same arguments as rust_binary.

    Example:

    Suppose you have a crate with a cargo build script `build.rs`:

    ```
    [workspace]/
        hello_lib/
            BUILD
            build.rs
            src/
                lib.rs
    ```

    Then you want to use the build script in the following:

    `hello_lib/BUILD`:
    ```python
    package(default_visibility = ["//visibility:public"])

    load("@io_bazel_rules_rust//rust:rust.bzl", "rust_binary", "rust_library")
    load("@io_bazel_rules_rust//cargo:cargo_build_script.bzl", "cargo_build_script")

    # This will run the build script from the root of the workspace, and
    # collect the outputs.
    cargo_build_script(
        name = "build_script",
        srcs = ["build.rs"],
        # Data are shipped during execution.
        data = ["src/lib.rs"],
    )

    rust_library(
        name = "hello_lib",
        srcs = [
            "src/lib.rs",
        ],
        deps = [":build_script"],
    )
    ```

    The `hello_lib` target will be build with the flags and the environment variables declared by the
    build script in addition to the file generated by it.
    """
    rust_binary(
        name = name + "_script_",
        crate_features = crate_features,
        deps = deps,
        **kwargs,
    )
    _build_script_run(
        name = name,
        script = ":%s_script_" % name,
        crate_name = crate_name,
        crate_features = crate_features,
        deps = deps,
    )
