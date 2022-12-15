"""The `cargo_bootstrap` rule is used for bootstrapping cargo binaries in a repository rule."""

load("//cargo/private:cargo_utils.bzl", "get_rust_tools")
load("//rust:defs.bzl", "rust_common")
load("//rust/platform:triple.bzl", "get_host_triple")

_CARGO_BUILD_MODES = [
    "release",
    "debug",
]

_FAIL_MESSAGE = """\
Process exited with code '{code}'
# ARGV ########################################################################
{argv}

# STDOUT ######################################################################
{stdout}

# STDERR ######################################################################
{stderr}
"""

def cargo_bootstrap(
        repository_ctx,
        cargo_bin,
        rustc_bin,
        binary,
        cargo_manifest,
        environment = {},
        quiet = False,
        build_mode = "release",
        target_dir = None,
        timeout = 600):
    """A function for bootstrapping a cargo binary within a repository rule

    Args:
        repository_ctx (repository_ctx): The rule's context object.
        cargo_bin (path): The path to a Cargo binary.
        rustc_bin (path): The path to a Rustc binary.
        binary (str): The binary to build (the `--bin` parameter for Cargo).
        cargo_manifest (path): The path to a Cargo manifest (Cargo.toml file).
        environment (dict): Environment variables to use during execution.
        quiet (bool, optional): Whether or not to print output from the Cargo command.
        build_mode (str, optional): The build mode to use
        target_dir (path, optional): The directory in which to produce build outputs
            (Cargo's --target-dir argument).
        timeout (int, optional): Maximum duration of the Cargo build command in seconds,

    Returns:
        path: The path of the built binary within the target directory
    """

    if not target_dir:
        target_dir = repository_ctx.path(".")

    args = [
        cargo_bin,
        "build",
        "--bin",
        binary,
        "--locked",
        "--target-dir",
        target_dir,
        "--manifest-path",
        cargo_manifest,
    ]

    if build_mode not in _CARGO_BUILD_MODES:
        fail("'{}' is not a supported build mode. Use one of {}".format(build_mode, _CARGO_BUILD_MODES))

    if build_mode == "release":
        args.append("--release")

    env = dict({
        "RUSTC": str(rustc_bin),
    }.items() + environment.items())

    repository_ctx.report_progress("Cargo Bootstrapping {}".format(binary))
    result = repository_ctx.execute(
        args,
        environment = env,
        quiet = quiet,
        timeout = timeout,
    )

    if result.return_code != 0:
        fail(_FAIL_MESSAGE.format(
            code = result.return_code,
            argv = args,
            stdout = result.stdout,
            stderr = result.stderr,
        ))

    extension = ""
    if "win" in repository_ctx.os.name:
        extension = ".exe"

    binary_path = "{}/{}{}".format(
        build_mode,
        binary,
        extension,
    )

    if not repository_ctx.path(binary_path).exists:
        fail("Failed to produce binary at {}".format(binary_path))

    return binary_path

_BUILD_FILE_CONTENT = """\
load("@rules_rust//rust:defs.bzl", "rust_binary")

package(default_visibility = ["//visibility:public"])

exports_files([
    "{binary_name}",
    "{binary}"
])

alias(
    name = "binary",
    actual = "{binary}",
)

rust_binary(
    name = "install",
    rustc_env = {{
        "RULES_RUST_CARGO_BOOTSTRAP_BINARY": "$(rootpath {binary})"
    }},
    data = [
        "{binary}",
    ],
    srcs = [
        "@rules_rust//cargo/bootstrap:bootstrap_installer.rs"
    ],
)
"""

def _collect_environ(repository_ctx, host_triple):
    """Gather environment varialbes to use from the current rule context

    Args:
        repository_ctx (repository_ctx): The rule's context object.
        host_triple (str): A string of the current host triple

    Returns:
        dict: A map of environment variables
    """
    env_vars = dict(json.decode(repository_ctx.attr.env.get(host_triple, "{}")))

    # Gather the path for each label and ensure it exists
    env_labels = dict(json.decode(repository_ctx.attr.env_label.get(host_triple, "{}")))
    env_labels = {key: repository_ctx.path(Label(value)) for (key, value) in env_labels.items()}
    for key in env_labels:
        if not env_labels[key].exists:
            fail("File for key '{}' does not exist: {}", key, env_labels[key])
    env_labels = {key: str(value) for (key, value) in env_labels.items()}

    return dict(env_vars.items() + env_labels.items())

def _detect_changes(repository_ctx):
    """Inspect files that are considered inputs to the build for changes

    Args:
        repository_ctx (repository_ctx): The rule's context object.
    """
    # Simply generating a `path` object consideres the file as 'tracked' or
    # 'consumed' which means changes to it will trigger rebuilds

    for src in repository_ctx.attr.srcs:
        repository_ctx.path(src)

    repository_ctx.path(repository_ctx.attr.cargo_lockfile)
    repository_ctx.path(repository_ctx.attr.cargo_toml)

def _cargo_bootstrap_repository_impl(repository_ctx):
    # Pretend to Bazel that this rule's input files have been used, so that it will re-run the rule if they change.
    _detect_changes(repository_ctx)

    if repository_ctx.attr.version in ("beta", "nightly"):
        channel = repository_ctx.attr.version
        version = repository_ctx.attr.iso_date
    else:
        channel = "stable"
        version = repository_ctx.attr.version

    host_triple = get_host_triple(repository_ctx)
    cargo_template = repository_ctx.attr.rust_toolchain_cargo_template
    rustc_template = repository_ctx.attr.rust_toolchain_rustc_template

    tools = get_rust_tools(
        cargo_template = cargo_template,
        rustc_template = rustc_template,
        host_triple = host_triple,
        channel = channel,
        version = version,
    )

    binary_name = repository_ctx.attr.binary or repository_ctx.name

    # In addition to platform specific environment variables, a common set (indicated by `*`) will always
    # be gathered.
    environment = dict(_collect_environ(repository_ctx, "*").items() + _collect_environ(repository_ctx, host_triple.str).items())

    built_binary = cargo_bootstrap(
        repository_ctx = repository_ctx,
        cargo_bin = repository_ctx.path(tools.cargo),
        rustc_bin = repository_ctx.path(tools.rustc),
        binary = binary_name,
        cargo_manifest = repository_ctx.path(repository_ctx.attr.cargo_toml),
        build_mode = repository_ctx.attr.build_mode,
        environment = environment,
        timeout = repository_ctx.attr.timeout,
    )

    # Create a symlink so that the binary can be accesed via it's target name
    repository_ctx.symlink(built_binary, binary_name)

    repository_ctx.file("BUILD.bazel", _BUILD_FILE_CONTENT.format(
        binary_name = binary_name,
        binary = built_binary,
    ))

cargo_bootstrap_repository = repository_rule(
    doc = "A rule for bootstrapping a Rust binary using [Cargo](https://doc.rust-lang.org/cargo/)",
    implementation = _cargo_bootstrap_repository_impl,
    attrs = {
        "binary": attr.string(
            doc = "The binary to build (the `--bin` parameter for Cargo). If left empty, the repository name will be used.",
        ),
        "build_mode": attr.string(
            doc = "The build mode the binary should be built with",
            values = [
                "debug",
                "release",
            ],
            default = "release",
        ),
        "cargo_lockfile": attr.label(
            doc = "The lockfile of the crate_universe resolver",
            allow_single_file = ["Cargo.lock"],
            mandatory = True,
        ),
        "cargo_toml": attr.label(
            doc = "The path of the crate_universe resolver manifest (`Cargo.toml` file)",
            allow_single_file = ["Cargo.toml"],
            mandatory = True,
        ),
        "env": attr.string_dict(
            doc = (
                "A mapping of platform triple to a set of environment variables. See " +
                "[cargo_env](#cargo_env) for usage details. Additionally, the platform triple `*` applies to all platforms."
            ),
        ),
        "env_label": attr.string_dict(
            doc = (
                "A mapping of platform triple to a set of environment variables. This " +
                "attribute differs from `env` in that all variables passed here must be " +
                "fully qualified labels of files. See [cargo_env](#cargo_env) for usage details. " +
                "Additionally, the platform triple `*` applies to all platforms."
            ),
        ),
        "iso_date": attr.string(
            doc = "The iso_date of cargo binary the resolver should use. Note: This can only be set if `version` is `beta` or `nightly`",
        ),
        "rust_toolchain_cargo_template": attr.string(
            doc = (
                "The template to use for finding the host `cargo` binary. `{version}` (eg. '1.53.0'), " +
                "`{triple}` (eg. 'x86_64-unknown-linux-gnu'), `{arch}` (eg. 'aarch64'), `{vendor}` (eg. 'unknown'), " +
                "`{system}` (eg. 'darwin'), `{channel}` (eg. 'stable'), and `{tool}` (eg. 'rustc.exe') will be " +
                "replaced in the string if present."
            ),
            default = "@rust_{system}_{arch}__{triple}__{channel}_tools//:bin/{tool}",
        ),
        "rust_toolchain_rustc_template": attr.string(
            doc = (
                "The template to use for finding the host `rustc` binary. `{version}` (eg. '1.53.0'), " +
                "`{triple}` (eg. 'x86_64-unknown-linux-gnu'), `{arch}` (eg. 'aarch64'), `{vendor}` (eg. 'unknown'), " +
                "`{system}` (eg. 'darwin'), `{channel}` (eg. 'stable'), and `{tool}` (eg. 'rustc.exe') will be " +
                "replaced in the string if present."
            ),
            default = "@rust_{system}_{arch}__{triple}__{channel}_tools//:bin/{tool}",
        ),
        "srcs": attr.label_list(
            doc = "Souce files of the crate to build. Passing source files here can be used to trigger rebuilds when changes are made",
            allow_files = True,
        ),
        "timeout": attr.int(
            doc = "Maximum duration of the Cargo build command in seconds",
            default = 600,
        ),
        "version": attr.string(
            doc = "The version of cargo the resolver should use",
            default = rust_common.default_version,
        ),
        "_cc_toolchain": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
    },
)

def cargo_env(env):
    """A helper for generating platform specific environment variables

    ```python
    load("@rules_rust//rust:defs.bzl", "rust_common")
    load("@rules_rust//cargo:defs.bzl", "cargo_bootstrap_repository", "cargo_env")

    cargo_bootstrap_repository(
        name = "bootstrapped_bin",
        cargo_lockfile = "//:Cargo.lock",
        cargo_toml = "//:Cargo.toml",
        srcs = ["//:resolver_srcs"],
        version = rust_common.default_version,
        binary = "my-crate-binary",
        env = {
            "x86_64-unknown-linux-gnu": cargo_env({
                "FOO": "BAR",
            }),
        },
        env_label = {
            "aarch64-unknown-linux-musl": cargo_env({
                "DOC": "//:README.md",
            }),
        }
    )
    ```

    Args:
        env (dict): A map of environment variables

    Returns:
        str: A json encoded string of the environment variables
    """
    return json.encode(dict(env))
