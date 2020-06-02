load("@io_bazel_rules_rust//rust:private/rustc.bzl", "BuildInfo", "rustc_compile_action")
load("@io_bazel_rules_rust//rust:private/utils.bzl", "find_toolchain")
load("@io_bazel_rules_rust//rust:rust.bzl", "rust_binary")

def _cargo_build_script_run(ctx, script):
    toolchain = find_toolchain(ctx)
    out_dir = ctx.actions.declare_directory(ctx.label.name + ".out_dir")
    env_out = ctx.actions.declare_file(ctx.label.name + ".env")
    flags_out = ctx.actions.declare_file(ctx.label.name + ".flags")
    manifest_dir = "%s.runfiles/%s" % (script.path, ctx.label.workspace_name)
    env = {
        "CARGO_MANIFEST_DIR": manifest_dir,
        "RUSTC": toolchain.rustc.path,
        "TARGET": toolchain.target_triple,
        "OUT_DIR": out_dir.path,
    }

    for f in ctx.attr.crate_features:
        env["CARGO_FEATURE_" + f.upper().replace("-", "_")] = "1"

    ctx.actions.run(
        executable = ctx.executable._cargo_build_script_runner,
        arguments = [script.path, env_out.path, flags_out.path],
        outputs = [out_dir, env_out, flags_out],
        tools = [script, ctx.executable._cargo_build_script_runner],
        inputs = [script, toolchain.rustc],
        mnemonic = "CargoBuildScriptRun",
        env = env,
    )

    return [
        BuildInfo(
            out_dir = out_dir,
            rustc_env = env_out,
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
        "crate_features": attr.string_list(doc = "The list of rust features that the build script should consider activated."),
        "_cargo_build_script_runner": attr.label(
            executable = True,
            allow_files = True,
            default = Label("//cargo/cargo_build_script_runner:cargo_build_script_runner"),
            cfg = "host",
        ),
    },
    toolchains = [
        "@io_bazel_rules_rust//rust:toolchain",
    ],
)

def cargo_build_script(name, crate_features=[], **kwargs):
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
    rust_binary(name = name + "_script_",
        crate_features = crate_features,
        **kwargs,
    )
    _build_script_run(
        name = name,
        script = ":%s_script_" % name,
        crate_features = crate_features,
    )
