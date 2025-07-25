"""Rules for Cargo build scripts (`build.rs` files)"""

load(
    "//cargo/private:cargo_build_script.bzl",
    "cargo_build_script_runfiles",
    "name_to_crate_name",
    "name_to_pkg_name",
    _build_script_run = "cargo_build_script",
)
load("//rust:defs.bzl", "rust_binary")

def cargo_build_script(
        *,
        name,
        edition = None,
        crate_name = None,
        crate_root = None,
        srcs = [],
        crate_features = [],
        version = None,
        deps = [],
        link_deps = [],
        proc_macro_deps = [],
        build_script_env = {},
        use_default_shell_env = None,
        data = [],
        compile_data = [],
        tools = [],
        links = None,
        rundir = None,
        rustc_env = {},
        rustc_env_files = [],
        rustc_flags = [],
        visibility = None,
        tags = None,
        aliases = None,
        pkg_name = None,
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

    load("@rules_rust//rust:defs.bzl", "rust_binary", "rust_library")
    load("@rules_rust//cargo:defs.bzl", "cargo_build_script")

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
        },
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
        name (str): The name for the underlying rule. This should be the name of the package
            being compiled, optionally with a suffix of `_bs`. Otherwise, you can set the package name via `pkg_name`.
        edition (str): The rust edition to use for the internal binary crate.
        crate_name (str): Crate name to use for build script.
        crate_root (label): The file that will be passed to rustc to be used for building this crate.
        srcs (list of label): Source files of the crate to build. Passing source files here can be used to trigger rebuilds when changes are made.
        crate_features (list, optional): A list of features to enable for the build script.
        version (str, optional): The semantic version (semver) of the crate.
        deps (list, optional): The build-dependencies of the crate.
        pkg_name (string, optional): Override the package name used for the build script. This is useful if the build target name gets too long otherwise.
        link_deps (list, optional): The subset of the (normal) dependencies of the crate that have the
            links attribute and therefore provide environment variables to this build script.
        proc_macro_deps (list of label, optional): List of rust_proc_macro targets used to build the script.
        build_script_env (dict, optional): Environment variables for build scripts.
        use_default_shell_env (bool, optional): Whether or not to include the default shell environment for the build script action. If unset the global
            setting `@rules_rust//cargo/settings:use_default_shell_env` will be used to determine this value.
        data (list, optional): Files needed by the build script.
        compile_data (list, optional): Files needed for the compilation of the build script.
        tools (list, optional): Tools (executables) needed by the build script.
        links (str, optional): Name of the native library this crate links against.
        rundir (str, optional): A directory to `cd` to before the cargo_build_script is run. This should be a path relative to the exec root.

            The default behaviour (and the behaviour if rundir is set to the empty string) is to change to the relative path corresponding to the cargo manifest directory, which replicates the normal behaviour of cargo so it is easy to write compatible build scripts.

            If set to `.`, the cargo build script will run in the exec root.
        rustc_env (dict, optional): Environment variables to set in rustc when compiling the build script.
        rustc_env_files (list of label, optional): Files containing additional environment variables to set for rustc
            when building the build script.
        rustc_flags (list, optional): List of compiler flags passed to `rustc`.
        visibility (list of label, optional): Visibility to apply to the generated build script output.
        tags: (list of str, optional): Tags to apply to the generated build script output.
        aliases (dict, optional): Remap crates to a new name or moniker for linkage to this target. \
            These are other `rust_library` targets and will be presented as the new name given.
        **kwargs: Forwards to the underlying `rust_binary` rule. An exception is the `compatible_with`
            attribute, which shouldn't be forwarded to the `rust_binary`, as the `rust_binary` is only
            built and used in `exec` mode. We propagate the `compatible_with` attribute to the `_build_script_run`
            target.
    """

    # This duplicates the code in _cargo_build_script_impl because we need to make these
    # available both when we invoke rustc (this code) and when we run the compiled build
    # script (_cargo_build_script_impl). https://github.com/bazelbuild/rules_rust/issues/661
    # will hopefully remove this duplication.
    if pkg_name == None:
        pkg_name = name_to_pkg_name(name)

    rustc_env = dict(rustc_env)
    if "CARGO_PKG_NAME" not in rustc_env:
        rustc_env["CARGO_PKG_NAME"] = pkg_name
    if "CARGO_CRATE_NAME" not in rustc_env:
        rustc_env["CARGO_CRATE_NAME"] = name_to_crate_name(name_to_pkg_name(name))

    script_kwargs = {}
    for arg in ("exec_compatible_with", "testonly"):
        if arg in kwargs:
            script_kwargs[arg] = kwargs[arg]

    wrapper_kwargs = dict(script_kwargs)
    for arg in ("compatible_with", "target_compatible_with"):
        if arg in kwargs:
            wrapper_kwargs[arg] = kwargs[arg]

    binary_tags = depset(
        (tags if tags else []) + ["manual"],
    ).to_list()

    # This target exists as the actual build script.
    rust_binary(
        name = name + "_",
        crate_name = crate_name,
        srcs = srcs,
        crate_root = crate_root,
        crate_features = crate_features,
        deps = deps,
        proc_macro_deps = proc_macro_deps,
        data = tools,
        compile_data = compile_data,
        rustc_env = rustc_env,
        rustc_env_files = rustc_env_files,
        rustc_flags = rustc_flags,
        edition = edition,
        tags = binary_tags,
        aliases = aliases,
        **script_kwargs
    )

    # Because the build script is expected to be run on the exec host, the
    # script above needs to be in the exec configuration but the script may
    # need data files that are in the target configuration. This rule wraps
    # the script above so the `cfg=exec` target can be run without issue in
    # a `cfg=target` environment. More details can be found on the rule.
    cargo_build_script_runfiles(
        name = name + "-",
        script = ":{}_".format(name),
        data = data,
        tools = tools,
        tags = binary_tags,
        **wrapper_kwargs
    )

    if use_default_shell_env == None:
        sanitized_use_default_shell_env = -1
    elif type(use_default_shell_env) == "bool":
        sanitized_use_default_shell_env = 1 if use_default_shell_env else 0
    else:
        sanitized_use_default_shell_env = use_default_shell_env

    # This target executes the build script.
    _build_script_run(
        name = name,
        script = ":{}-".format(name),
        crate_features = crate_features,
        version = version,
        build_script_env = build_script_env,
        use_default_shell_env = sanitized_use_default_shell_env,
        links = links,
        deps = deps,
        link_deps = link_deps,
        rundir = rundir,
        rustc_flags = rustc_flags,
        visibility = visibility,
        tags = tags,
        pkg_name = pkg_name,
        **kwargs
    )
