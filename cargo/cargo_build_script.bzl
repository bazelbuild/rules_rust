# buildifier: disable=module-docstring
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "C_COMPILE_ACTION_NAME")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("@io_bazel_rules_rust//rust:private/rustc.bzl", "BuildInfo", "DepInfo", "get_cc_toolchain", "get_compilation_mode_opts", "get_linker_and_args")
load("@io_bazel_rules_rust//rust:private/utils.bzl", "find_toolchain")
load("@io_bazel_rules_rust//rust:rust.bzl", "rust_binary")

def _expand_location(ctx, env, data):
    """A trivial helper for `_expand_locations`

    Args:
        ctx (ctx): The rule's context object
        env (str): The value possibly containing location macros to expand.
        data (sequence of Targets): see `_expand_locations`

    Returns:
        string: The location-macro expanded version of the string.
    """
    for directive in ("$(execpath ", "$(location "):
        if directive in env:
            # build script runner will expand pwd to execroot for us
            env = env.replace(directive, "${pwd}/" + directive)
    return ctx.expand_location(env, data)

def _expand_locations(ctx, env, data):
    """Performs location-macro expansion on string values.

    Note that exec-root relative locations will be exposed to the build script
    as absolute paths, rather than the ordinary exec-root relative paths,
    because cargo build scripts do not run in the exec root.

    Args:
        ctx (ctx): The rule's context object
        env (dict): A dict whose values we iterate over
        data (sequence of Targets): The targets which may be referenced by
            location macros. This is expected to be the `data` attribute of
            the target, though may have other targets or attributes mixed in.

    Returns:
        dict: A dict of environment variables with expanded location macros
    """
    return dict([(k, _expand_location(ctx, v, data)) for (k, v) in env.items()])

def get_cc_compile_env(cc_toolchain, feature_configuration):
    """Gather cc environment variables from the given `cc_toolchain`

    Args:
        cc_toolchain (cc_toolchain): The current rule's `cc_toolchain`.
        feature_configuration (FeatureConfiguration): Class used to construct command lines from CROSSTOOL features.

    Returns:
        dict: Returns environment variables to be set for given action.
    """
    compile_variables = cc_common.create_compile_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
    )
    return cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = C_COMPILE_ACTION_NAME,
        variables = compile_variables,
    )

def _build_script_impl(ctx):
    """The implementation for the `_build_script_run` rule.

    Args:
        ctx (ctx): The rules context object

    Returns:
        list: A list containing a BuildInfo provider
    """
    script = ctx.executable.script
    toolchain = find_toolchain(ctx)
    out_dir = ctx.actions.declare_directory(ctx.label.name + ".out_dir")
    env_out = ctx.actions.declare_file(ctx.label.name + ".env")
    dep_env_out = ctx.actions.declare_file(ctx.label.name + ".depenv")
    flags_out = ctx.actions.declare_file(ctx.label.name + ".flags")
    link_flags = ctx.actions.declare_file(ctx.label.name + ".linkflags")
    manifest_dir = "%s.runfiles/%s/%s" % (script.path, ctx.label.workspace_name or ctx.workspace_name, ctx.label.package)
    compilation_mode_opt_level = get_compilation_mode_opts(ctx, toolchain).opt_level

    crate_name = ctx.attr.crate_name

    # Derive crate name from the rule label which is <crate_name>_build_script if not provided.
    if not crate_name:
        crate_name = ctx.label.name
        if crate_name.endswith("_build_script"):
            crate_name = crate_name.replace("_build_script", "")
        crate_name = crate_name.replace("_", "-")

    toolchain_tools = [
        # Needed for rustc to function.
        toolchain.rustc_lib.files,
        toolchain.rust_lib.files,
    ]

    cc_toolchain = find_cpp_toolchain(ctx)

    # Start with the default shell env, which contains any --action_env
    # settings passed in on the command line.
    env = dict(ctx.configuration.default_shell_env)

    env.update({
        "CARGO_MANIFEST_DIR": manifest_dir,
        "CARGO_PKG_NAME": crate_name,
        "HOST": toolchain.exec_triple,
        "OPT_LEVEL": compilation_mode_opt_level,
        "RUSTC": toolchain.rustc.path,
        "TARGET": toolchain.target_triple,
        # OUT_DIR is set by the runner itself, rather than on the action.
    })

    if ctx.attr.version:
        version = ctx.attr.version.split("+")[0].split(".")
        patch = version[2].split("-") if len(version) > 2 else [""]
        env["CARGO_PKG_VERSION_MAJOR"] = version[0]
        env["CARGO_PKG_VERSION_MINOR"] = version[1] if len(version) > 1 else ""
        env["CARGO_PKG_VERSION_PATCH"] = patch[0]
        env["CARGO_PKG_VERSION_PRE"] = patch[1] if len(patch) > 1 else ""
        env["CARGO_PKG_VERSION"] = ctx.attr.version

    # Pull in env vars which may be required for the cc_toolchain to work (e.g. on OSX, the SDK version).
    # We hope that the linker env is sufficient for the whole cc_toolchain.
    cc_toolchain, feature_configuration = get_cc_toolchain(ctx)
    _, _, linker_env = get_linker_and_args(ctx, cc_toolchain, feature_configuration, None)
    env.update(**linker_env)

    # MSVC requires INCLUDE to be set
    cc_env = get_cc_compile_env(cc_toolchain, feature_configuration)
    include = cc_env.get("INCLUDE")
    if include:
        env["INCLUDE"] = include

    if cc_toolchain:
        toolchain_tools.append(cc_toolchain.all_files)

        cc_executable = cc_toolchain.compiler_executable
        if cc_executable:
            env["CC"] = cc_executable
        ar_executable = cc_toolchain.ar_executable
        if ar_executable:
            env["AR"] = ar_executable

    for f in ctx.attr.crate_features:
        env["CARGO_FEATURE_" + f.upper().replace("-", "_")] = "1"

    env.update(_expand_locations(
        ctx,
        ctx.attr.build_script_env,
        getattr(ctx.attr, "data", []),
    ))

    tools = depset(
        direct = [
            script,
            ctx.executable._cargo_build_script_runner,
            toolchain.rustc,
        ] + ctx.files.data,
        transitive = toolchain_tools,
    )

    links = ctx.attr.links or ""

    # dep_env_file contains additional environment variables coming from
    # direct dependency sys-crates' build scripts. These need to be made
    # available to the current crate build script.
    # See https://doc.rust-lang.org/cargo/reference/build-scripts.html#-sys-packages
    # for details.
    args = ctx.actions.args()
    args.add_all([script.path, crate_name, links, out_dir.path, env_out.path, flags_out.path, link_flags.path, dep_env_out.path])
    build_script_inputs = []
    for dep in ctx.attr.deps:
        if DepInfo in dep and dep[DepInfo].dep_env:
            dep_env_file = dep[DepInfo].dep_env
            args.add(dep_env_file.path)
            build_script_inputs.append(dep_env_file)
            for dep_build_info in dep[DepInfo].transitive_build_infos.to_list():
                build_script_inputs.append(dep_build_info.out_dir)

    ctx.actions.run(
        executable = ctx.executable._cargo_build_script_runner,
        arguments = [args],
        outputs = [out_dir, env_out, flags_out, link_flags, dep_env_out],
        tools = tools,
        inputs = build_script_inputs,
        mnemonic = "CargoBuildScriptRun",
        env = env,
    )

    return [
        BuildInfo(
            out_dir = out_dir,
            rustc_env = env_out,
            dep_env = dep_env_out,
            flags = flags_out,
            link_flags = link_flags,
        ),
    ]

_build_script_run = rule(
    doc = (
        "A rule for running a crate's `build.rs` files to generate build information " +
        "which is then used to determine how to compile said crate."
    ),
    implementation = _build_script_impl,
    attrs = {
        # The source of truth will be the `cargo_build_script` macro until stardoc
        # implements documentation inheritence. See https://github.com/bazelbuild/stardoc/issues/27
        "script": attr.label(
            doc = "The binary script to run, generally a rust_binary target.",
            executable = True,
            allow_files = True,
            mandatory = True,
            cfg = "exec",
        ),
        "crate_name": attr.string(
            doc = "Name of the crate associated with this build script target",
        ),
        "links": attr.string(
            doc = "The name of the native library this crate links against.",
        ),
        "deps": attr.label_list(
            doc = "The dependencies of the crate defined by `crate_name`",
        ),
        "version": attr.string(
            doc = "The semantic version (semver) of the crate",
        ),
        "crate_features": attr.string_list(
            doc = "The list of rust features that the build script should consider activated.",
        ),
        "build_script_env": attr.string_dict(
            doc = "Environment variables for build scripts.",
        ),
        "data": attr.label_list(
            doc = "Data or tools required by the build script.",
            allow_files = True,
        ),
        "_cc_toolchain": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
        "_cargo_build_script_runner": attr.label(
            executable = True,
            allow_files = True,
            default = Label("//cargo/cargo_build_script_runner:cargo_build_script_runner"),
            cfg = "exec",
        ),
    },
    fragments = ["cpp"],
    toolchains = [
        "@io_bazel_rules_rust//rust:toolchain",
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
)

def cargo_build_script(
        name,
        crate_name = "",
        crate_features = [],
        version = None,
        deps = [],
        build_script_env = {},
        data = [],
        links = None,
        **kwargs):
    """Compile and execute a rust build script to generate build attributes

    This rules take the same arguments as rust_binary.

    Example:

    Suppose you have a crate with a cargo build script `build.rs`:

    ```output
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
        # Optional environment variables passed during build.rs compilation
        rustc_env = {
           "CARGO_PKG_VERSION": "0.1.2",
        },
        # Optional environment variables passed during build.rs execution.
        # Note that as the build script's working directory is not execroot,
        # execpath/location will return an absolute path, instead of a relative
        # one.
        build_script_env = {
            "SOME_TOOL_OR_FILE": "$(execpath @tool//:binary)"
        }
        # Optional data/tool dependencies
        data = ["@tool//:binary"],
    )

    rust_library(
        name = "hello_lib",
        srcs = [
            "src/lib.rs",
        ],
        deps = [":build_script"],
    )
    ```

    The `hello_lib` target will be build with the flags and the environment variables declared by the \
    build script in addition to the file generated by it.

    Args:
        name (str): The target name for the underlying rule
        crate_name (str, optional): Name of the crate associated with this build script target.
        crate_features (list, optional): A list of features to enable for the build script.
        version (str, optional): The semantic version (semver) of the crate.
        deps (list, optional): The dependencies of the crate defined by `crate_name`.
        build_script_env (dict, optional): Environment variables for build scripts.
        data (list, optional): Files or tools needed by the build script.
        links (str, optional): Name of the native library this crate links against.
        **kwargs: Forwards to the underlying `rust_binary` rule.
    """
    rust_binary(
        name = name + "_script_",
        crate_features = crate_features,
        version = version,
        deps = deps,
        data = data,
        **kwargs
    )
    _build_script_run(
        name = name,
        script = ":%s_script_" % name,
        crate_name = crate_name,
        crate_features = crate_features,
        version = version,
        build_script_env = build_script_env,
        links = links,
        deps = deps,
        data = data,
    )
