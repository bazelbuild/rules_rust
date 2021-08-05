"""A module dedicated to building Cargo's `build.rs` scripts in Bazel"""

load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "C_COMPILE_ACTION_NAME")
load("//rust:defs.bzl", "rust_common")

# buildifier: disable=bzl-visibility
load("//rust/private:rust.bzl", "COMMON_ATTRS", "crate_root_src", "get_edition")

# buildifier: disable=bzl-visibility
load("//rust/private:rustc.bzl", "BuildInfo", "collect_deps", "collect_inputs", "construct_arguments", "is_dylib")

# buildifier: disable=bzl-visibility
load("//rust/private:utils.bzl", "crate_name_from_attr", "dedent", "expand_dict_value_locations", "find_cc_toolchain", "find_toolchain", "get_preferred_artifact")

_CARGO_BUILD_SCRIPT_PROVIDERS = [
    BuildInfo,
    OutputGroupInfo,
    rust_common.crate_info,
    rust_common.dep_info,
]

def _get_cc_compile_env(cc_toolchain, feature_configuration):
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

def _declare_build_script_outputs(ctx):
    """Declare all files output by the cargo_build_script_runner

    Args:
        ctx (ctx): The rule's context object

    Returns:
        struct: A struct of File objects
    """
    out_dir = ctx.actions.declare_directory(ctx.label.name + ".out_dir")
    env_out = ctx.actions.declare_file(ctx.label.name + ".env")
    dep_env_out = ctx.actions.declare_file(ctx.label.name + ".depenv")
    flags_out = ctx.actions.declare_file(ctx.label.name + ".flags")
    link_flags = ctx.actions.declare_file(ctx.label.name + ".linkflags")
    streams = struct(
        stdout = ctx.actions.declare_file(ctx.label.name + ".stdout.log"),
        stderr = ctx.actions.declare_file(ctx.label.name + ".stderr.log"),
    )

    return struct(
        out_dir = out_dir,
        env_out = env_out,
        dep_env_out = dep_env_out,
        flags_out = flags_out,
        link_flags = link_flags,
        streams = streams,
        all = [
            out_dir,
            env_out,
            dep_env_out,
            flags_out,
            link_flags,
            streams.stdout,
            streams.stderr,
        ],
    )

def _construct_build_script_args(ctx, crate_info, outputs):
    """Generate arguments and inputs for the `cargo_build_script_runner`.

    Args:
        ctx (ctx): The rule's context object
        crate_info (CrateInfo): The CrateInfo provider of the current build script.
        outputs (struct): The outputs of of the `cargo_build_script_runner`. See `_declare_build_script_outputs`.

    Returns:
        tuple: A set of inputs for the build script action
            - Args: Arguments specifically for the `cargo_build_script_runner`
            - dict: Environment variables to apply to the action
            - depset(File): Additional files required by the build script action.
    """

    # dep_env_file contains additional environment variables coming from
    # direct dependency sys-crates' build scripts. These need to be made
    # available to the current crate build script.
    # See https://doc.rust-lang.org/cargo/reference/build-scripts.html#-sys-packages
    # for details.
    args = ctx.actions.args()
    args.add_all([
        "--",
        ctx.executable._cargo_build_script_runner.path,
        crate_info.output.path,
        ctx.attr.links or "",
        outputs.out_dir.path,
        outputs.env_out.path,
        outputs.flags_out.path,
        outputs.link_flags.path,
        outputs.dep_env_out.path,
        outputs.streams.stdout.path,
        outputs.streams.stderr.path,
    ])

    extra_inputs = []
    for dep in ctx.attr.deps:
        if rust_common.dep_info in dep and dep[rust_common.dep_info].dep_env:
            dep_env_file = dep[rust_common.dep_info].dep_env
            extra_inputs.append(dep_env_file)
            args.add(dep_env_file.path)
            for dep_build_info in dep[rust_common.dep_info].transitive_build_infos.to_list():
                extra_inputs.append(dep_build_info.out_dir)

    env = {
        "CARGO_PKG_NAME": _name_to_pkg_name(ctx.attr.name),
    }

    cc_toolchain, feature_configuration = find_cc_toolchain(ctx)

    # MSVC requires INCLUDE to be set
    cc_env = _get_cc_compile_env(cc_toolchain, feature_configuration)
    include = cc_env.get("INCLUDE")
    if include:
        env["CARGO_BUILD_SCRIPT__INCLUDE"] = include

    cc_executable = cc_toolchain.compiler_executable
    if cc_executable:
        env["CARGO_BUILD_SCRIPT__CC"] = cc_executable
    ar_executable = cc_toolchain.ar_executable
    if ar_executable:
        env["CARGO_BUILD_SCRIPT__AR"] = ar_executable
    if cc_toolchain.sysroot:
        env["CARGO_BUILD_SCRIPT__SYSROOT"] = cc_toolchain.sysroot

    return args, env, depset(extra_inputs)

def _cargo_build_script_impl(ctx):
    """The implementation for the `_build_script_run` rule.

    Args:
        ctx (ctx): The rules context object

    Returns:
        list: A list containing a BuildInfo provider
    """
    toolchain = find_toolchain(ctx)
    crate_name = crate_name_from_attr(ctx.attr)
    crate_type = "bin"
    output = ctx.actions.declare_file(ctx.label.name + toolchain.binary_ext)

    crate_info = rust_common.create_crate_info(
        name = crate_name,
        type = crate_type,
        root = crate_root_src(ctx.attr, ctx.files.srcs, crate_type = "bin"),
        srcs = depset(ctx.files.srcs),
        deps = depset(ctx.attr.deps),
        proc_macro_deps = depset(ctx.attr.proc_macro_deps),
        aliases = ctx.attr.aliases,
        output = output,
        edition = get_edition(ctx.attr, toolchain),
        rustc_env = ctx.attr.rustc_env,
        is_test = False,
        compile_data = depset(ctx.files.compile_data),
    )

    build_script_outputs = _declare_build_script_outputs(ctx)

    cc_toolchain, feature_configuration = find_cc_toolchain(ctx)

    dep_info, build_info = collect_deps(
        label = ctx.label,
        deps = crate_info.deps,
        proc_macro_deps = crate_info.proc_macro_deps,
        aliases = crate_info.aliases,
    )

    compile_inputs, out_dir, build_env_files, build_flags_files = collect_inputs(
        ctx = ctx,
        file = ctx.file,
        files = ctx.files,
        toolchain = toolchain,
        cc_toolchain = cc_toolchain,
        crate_info = crate_info,
        dep_info = dep_info,
        build_info = build_info,
    )

    # Start with the default shell env, which contains any --action_env
    # settings passed in on the command line.
    env = dict(ctx.configuration.default_shell_env)

    args, rustc_env = construct_arguments(
        ctx = ctx,
        attr = ctx.attr,
        file = ctx.file,
        toolchain = toolchain,
        tool_path = toolchain.rustc.path,
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        crate_info = crate_info,
        dep_info = dep_info,
        output_hash = None,
        rust_flags = [],
        out_dir = out_dir,
        build_env_files = build_env_files,
        build_flags_files = build_flags_files,
    )
    env.update(rustc_env)

    build_script_args, build_script_env, build_script_inputs = _construct_build_script_args(ctx, crate_info, build_script_outputs)
    env.update(build_script_env)

    data = ctx.attr.data + ctx.attr.compile_data
    env.update(expand_dict_value_locations(
        ctx,
        ctx.attr.env,
        data,
    ))

    if hasattr(ctx.attr, "version") and ctx.attr.version != "0.0.0":
        formatted_version = " v{}".format(ctx.attr.version)
    else:
        formatted_version = ""

    ctx.actions.run(
        executable = ctx.executable._process_wrapper,
        inputs = depset(transitive = [
            compile_inputs,
            build_script_inputs,
        ]),
        outputs = [crate_info.output] + build_script_outputs.all,
        env = env,
        arguments = [
            args.process_wrapper_flags,
            build_script_args,
            args.rustc_path,
            args.rustc_flags,
        ],
        tools = [
            ctx.executable._cargo_build_script_runner,
        ],
        mnemonic = "CargoBuildScriptRun",
    )

    dylibs = [get_preferred_artifact(lib) for linker_input in dep_info.transitive_noncrates.to_list() for lib in linker_input.libraries if is_dylib(lib)]

    runfiles = ctx.runfiles(
        transitive_files = depset(dylibs + getattr(ctx.files, "data", [])),
    )

    return [
        DefaultInfo(
            files = depset([crate_info.output]),
            runfiles = runfiles,
            executable = crate_info.output,
        ),
        BuildInfo(
            out_dir = build_script_outputs.out_dir,
            rustc_env = build_script_outputs.env_out,
            dep_env = build_script_outputs.dep_env_out,
            flags = build_script_outputs.flags_out,
            link_flags = build_script_outputs.link_flags,
            data = runfiles.files,
        ),
        OutputGroupInfo(streams = depset([
            build_script_outputs.streams.stdout,
            build_script_outputs.streams.stderr,
        ])),
        crate_info,
        dep_info,
    ]

_cargo_build_script = rule(
    doc = (
        "A rule for running a crate's `build.rs` files to generate build information " +
        "which is then used to determine how to compile said crate."
    ),
    implementation = _cargo_build_script_impl,
    attrs = dict(
        COMMON_ATTRS.items() + {
            "env": attr.string_dict(
                mandatory = False,
                doc = dedent("""\
                    Specifies additional environment variables to set when the test is executed by bazel test.
                    Values are subject to `$(execpath)` and
                    ["Make variable"](https://docs.bazel.build/versions/master/be/make-variables.html) substitution.
                """),
            ),
            "links": attr.string(
                doc = "The name of the native library this crate links against.",
            ),
            "_cargo_build_script_runner": attr.label(
                executable = True,
                allow_files = True,
                default = Label("//cargo/cargo_build_script_runner:cargo_build_script_runner"),
                cfg = "exec",
            ),
            "_cc_toolchain": attr.label(
                default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
            ),
        }.items(),
    ),
    provides = _CARGO_BUILD_SCRIPT_PROVIDERS,
    fragments = ["cpp"],
    toolchains = [
        str(Label("//rust:toolchain")),
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    incompatible_use_toolchain_transition = True,
    executable = True,
)

def _exec_cargo_build_script_wrapper_impl(ctx):
    script = ctx.attr.script
    return [
        script[rust_common.crate_info],
        script[rust_common.dep_info],
        script[BuildInfo],
        script[OutputGroupInfo],
    ]

_exec_cargo_build_script_wrapper = rule(
    doc = "A rule which ensures the cargo build script is always run in the `exec` configuration",
    implementation = _exec_cargo_build_script_wrapper_impl,
    attrs = {
        "script": attr.label(
            doc = "The binary script to run, generally a `rust_binary` target.",
            providers = [BuildInfo],
            executable = True,
            allow_files = True,
            mandatory = True,
            cfg = "exec",
        ),
    },
    provides = _CARGO_BUILD_SCRIPT_PROVIDERS,
)

def cargo_build_script(
        name,
        build_script_env = {},
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

    load("@rules_rust//rust:rust.bzl", "rust_binary", "rust_library")
    load("@rules_rust//cargo:cargo_build_script.bzl", "cargo_build_script")

    # This will run the build script from the root of the workspace, and
    # collect the outputs.
    cargo_build_script(
        name = "build_script",
        srcs = ["build.rs"],
        # Optional environment variables passed during build.rs execution.
        # Note that as the build script's working directory is not execroot,
        # the `execpath`/`location` make variables will return an absolute path,
        # instead of a relative one. For details on make variables see:
        # https://docs.bazel.build/versions/main/be/make-variables.html#predefined_label_variables
        env = {
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
        name (str): The name for the underlying rule. This should be the name of the package being compiled, optionally with a suffix of _build_script.
        build_script_env (dict, optional): __deprecated__: The `env` attribute should be used instead
        links (str, optional): Name of the native library this crate links against.
        **kwargs: Forwards to the underlying `rust_binary` rule. See the attributes of this rule for more details
    """

    env = kwargs.pop("env", {})
    if build_script_env:
        env.update(build_script_env)

    build_script_name = _name_to_pkg_name(name) + "_build_script"
    if build_script_name == name:
        build_script_name += "_"

    tags = kwargs.pop("tags", [])

    _cargo_build_script(
        name = build_script_name,
        # build.rs scripts always use the name `build_script_build`
        crate_name = kwargs.pop("crate_name", "build_script_build"),
        env = env,
        links = links,
        tags = tags + (["manual"] if "manual" not in tags else []),
        **kwargs
    )

    # The wrapper target is explicitly tagged to not run clippy or rustfmt to avoid having
    # the same action run twice for the same data.
    wrapper_tags = tags
    if "noclippy" not in wrapper_tags:
        wrapper_tags.append("noclippy")
    if "norustfmt" not in wrapper_tags:
        wrapper_tags.append("norustfmt")

    _exec_cargo_build_script_wrapper(
        name = name,
        script = build_script_name,
        tags = wrapper_tags,
    )

def _name_to_pkg_name(name):
    name = name.rstrip("_")
    if name.endswith("_build_script"):
        return name[:-len("_build_script")]
    return name
