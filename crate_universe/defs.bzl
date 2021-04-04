"""A module defining the `crate_universe` rule"""

load(":deps.bzl", _crate_universe_deps = "crate_universe_deps")

DEFAULT_REPOSITORY_TEMPLATE = "https://crates.io/api/v1/crates/{crate}/{version}/download"

_INPUT_CONTENT_TEMPLATE = """{{
  "repository_name": {name},
  "packages": [
      {packages}
  ],
  "cargo_toml_files": {{
      {cargo_toml_files}
  }},
  "overrides": {{
      {overrides}
  }},
  "repository_template": "{repository_template}",
  "target_triples": [
    {targets}
  ],
  "cargo": "{cargo}"
}}"""

_CPU_ARCH_ERROR_MSG = """\
Command failed with exit code '{code}': {args}
----------stdout:
{stdout}
----------stderr:
{stderr}
"""

def _query_cpu_architecture(repository_ctx, expected_archs, is_windows = False):
    """Detect the host CPU architecture

    Args:
        repository_ctx (repository_ctx): The repository rule's context object
        expected_archs (list): A list of expected architecture strings
        is_windows (bool, optional): If true, the cpu lookup will use the windows method (`wmic` vs `uname`)

    Returns:
        str: The host's CPU architecture
    """
    if is_windows:
        arguments = ["wmic", "os", "get", "osarchitecture"]
    else:
        arguments = ["uname", "-m"]

    result = repository_ctx.execute(arguments)

    if result.return_code:
        fail(_CPU_ARCH_ERROR_MSG.format(
            code = result.return_code,
            args = arguments,
            stdout = result.stdout,
            stderr = result.stderr,
        ))

    if is_windows:
        # Example output:
        # OSArchitecture
        # 64-bit
        lines = result.stdout.split("\n")
        arch = lines[1]
    else:
        arch = result.stdout.strip("\n")

    if not arch in expected_archs:
        fail("{} is not a expected cpu architecture. {}".format(
            arch,
            expected_archs,
        ))

    return arch

def _get_host_info(repository_ctx):
    """Query host information for the appropriate triple and toolchain repo name

    Args:
        repository_ctx (repository_ctx): The rule's repository_ctx

    Returns:
        tuple: A tuple containing a triple (str) and repository name (str)
    """

    # Detect the host's cpu architecture

    supported_architectures = {
        "linux": ["aarch64", "x86_64"],
        "macos": ["aarch64", "x86_64"],
        "windows": ["x86_64"],
    }

    # The expected file extension of crate resolver binaries
    extension = ""

    if "linux" in repository_ctx.os.name:
        cpu = _query_cpu_architecture(repository_ctx, supported_architectures["linux"])
        resolver_triple = "{}-unknown-linux-gnu".format(cpu)
        toolchain_repo = "@rust_linux_{}".format(cpu)
    elif "mac" in repository_ctx.os.name:
        cpu = _query_cpu_architecture(repository_ctx, supported_architectures["macos"])
        resolver_triple = "{}-apple-darwin".format(cpu)
        toolchain_repo = "@rust_darwin_{}".format(cpu)
    elif "win" in repository_ctx.os.name:
        cpu = _query_cpu_architecture(repository_ctx, supported_architectures["windows"], True)
        resolver_triple = "{}-pc-windows-gnu".format(cpu)
        toolchain_repo = "@rust_windows_{}".format(cpu)
        extension = ".exe"
    else:
        fail("Could not locate resolver for OS " + repository_ctx.os.name)

    return (resolver_triple, toolchain_repo, extension)

def _crate_universe_resolve_impl(repository_ctx):
    """Entry-point repository to manage rust dependencies.

    General flow is:
    - Serialize user-provided rule attributes into JSON
    - Call the Rust resolver script. It writes a `defs.bzl` file in this repo containing the
      transitive dependencies as repo rules in a `pinned_rust_install()` macro.
    - The user then calls defs.bzl%pinned_rust_install().

    Environment Variables:
        RULES_RUST_UPDATE_CRATE_UNIVERSE_LOCKFILE: Re-pin the lockfile if `true`.
        RULES_RUST_CRATE_UNIVERSE_RESOLVER_URL_OVERRIDE: Override URL to use to download resolver binary - for local paths use a file:// URL.
    """

    # Get info about the current host's tool locations
    resolver_triple, toolchain_repo, extension = _get_host_info(repository_ctx)

    cargo_label = Label(toolchain_repo + "//:bin/cargo")
    rustc_label = Label(toolchain_repo + "//:bin/rustc")

    # Allow for an an override environment variable to define a url to a binary
    resolver_url = repository_ctx.os.environ.get("RULES_RUST_CRATE_UNIVERSE_RESOLVER_URL_OVERRIDE", None)
    resolver_sha = repository_ctx.os.environ.get("RULES_RUST_CRATE_UNIVERSE_RESOLVER_URL_OVERRIDE_SHA256", None)
    if resolver_url:
        if resolver_url.startswith("file://"):
            sha256_result = repository_ctx.execute(["sha256sum", resolver_url[7:]])
            resolver_sha = sha256_result.stdout[:64]

        resolver_path = repository_ctx.path("resolver")
        repository_ctx.download(
            url = resolver_url,
            sha256 = resolver_sha,
            output = resolver_path,
            executable = True,
        )
    else:
        resolver_label = Label("@rules_rust_crate_universe__{}//file:resolver{}".format(
            resolver_triple,
            extension,
        ))
        resolver_path = repository_ctx.path(resolver_label)

    lockfile_path = None
    if repository_ctx.attr.lockfile:
        lockfile_path = repository_ctx.path(repository_ctx.attr.lockfile)

    # Yay hand-crafted JSON serialisation...
    input_content = _INPUT_CONTENT_TEMPLATE.format(
        name = "\"{}\"".format(repository_ctx.attr.name),
        packages = ",\n".join([artifact for artifact in repository_ctx.attr.packages]),
        cargo_toml_files = ",\n".join(['"{}": "{}"'.format(ct, repository_ctx.path(ct)) for ct in repository_ctx.attr.cargo_toml_files]),
        overrides = ",\n".join(["\"{}\": {}".format(oname, ovalue) for (oname, ovalue) in repository_ctx.attr.overrides.items()]),
        repository_template = repository_ctx.attr.repository_template,
        targets = ",\n".join(['"{}"'.format(target) for target in repository_ctx.attr.supported_targets]),
        cargo = repository_ctx.path(cargo_label),
    )

    input_path = "_{name}.json".format(name = repository_ctx.attr.name)
    repository_ctx.file(input_path, content = input_content)

    args = [
        resolver_path,
        "--input_path",
        input_path,
        "--output_path",
        repository_ctx.path("defs.bzl"),
        "--repo-name",
        repository_ctx.attr.name,
    ]
    if lockfile_path != None:
        args.append("--lockfile")
        str(args.append(lockfile_path))
    if repository_ctx.os.environ.get("RULES_RUST_UPDATE_CRATE_UNIVERSE_LOCKFILE", "false") == "true":
        args.append("--update-lockfile")

    path_binaries = [
        repository_ctx.path(rustc_label),
    ]

    result = repository_ctx.execute(
        args,
        environment = {
            # The resolver invokes `cargo metadata` which relies on `rustc` being on the $PATH
            # See https://github.com/rust-lang/cargo/issues/8219
            "PATH": ":".join([str(b.dirname) for b in path_binaries]),
            "RUST_LOG": "info",
        },
    )
    repository_ctx.delete(input_path)
    if result.stderr:
        print("Output from resolver: " + result.stderr)  # buildifier: disable=print
    if result.return_code != 0:
        fail("Error resolving deps:\n" + result.stdout + "\n" + result.stderr)

    repository_ctx.file("BUILD.bazel")

_crate_universe_resolve = repository_rule(
    doc = """\
A rule for downloading Rust dependencies (crates).

`override` Example:

    load("@rules_rust//crate_universe:defs.bzl", "rust_library", "crate")

    rust_library(
        name = "mylib",
        # [...]
        overrides = {
            "tokio": crate.override(
                extra_rust_env_vars = {
                    "MY_ENV_VAR": "MY_ENV_VALUE",
                },
                extra_build_script_env_vars = {
                    "MY_BUILD_SCRIPT_ENV_VAR": "MY_ENV_VALUE",
                },
                extra_bazel_deps = {
                    # Extra dependencies are per target. They are additive.
                    "cfg(unix)": ["@somerepo//:foo"],  # cfg() predicate.
                    "x86_64-apple-darwin": ["@somerepo//:bar"],  # Specific triple.
                    "cfg(all())": ["@somerepo//:baz"],  # Applies to all targets ("regular dependency").
                },
                extra_build_script_bazel_deps = {
                    # Extra dependencies are per target. They are additive.
                    "cfg(unix)": ["@buildscriptdep//:foo"],
                    "x86_64-apple-darwin": ["@buildscriptdep//:bar"],
                    "cfg(all())": ["@buildscriptdep//:baz"],
                },
                extra_bazel_data_deps = {
                    # ...
                },
                extra_build_script_bazel_data_deps = {
                    # ...
                },
            ),
        },
    )
""",
    implementation = _crate_universe_resolve_impl,
    attrs = {
        "cargo_toml_files": attr.label_list(
            doc = "",
        ),
        "lockfile": attr.label(
            doc = "",
            allow_single_file = True,
            mandatory = False,
        ),
        "overrides": attr.string_dict(
            doc = "Mapping of crate name to `crate.override(...)` entries)",
        ),
        "packages": attr.string_list(
            doc = "",
            allow_empty = True,
        ),
        "repository_template": attr.string(
            doc = "",
        ),
        "supported_targets": attr.string_list(
            doc = "",
            allow_empty = False,
        ),
        "_resolvers": attr.label_list(
            doc = "A list of resolver binaries for various platforms",
            default = [
                "@rules_rust_crate_universe__aarch64-apple-darwin//:resolver",
                "@rules_rust_crate_universe__aarch64-unknown-linux-gnu//:resolver",
                "@rules_rust_crate_universe__x86_64-apple-darwin//:resolver",
                "@rules_rust_crate_universe__x86_64-pc-windows-gnu//:resolver.exe",
                "@rules_rust_crate_universe__x86_64-unknown-linux-gnu//:resolver",
            ],
        ),
    },
    environ = [
        "RULES_RUST_CRATE_UNIVERSE_RESOLVER_URL_OVERRIDE",
        "RULES_RUST_CRATE_UNIVERSE_RESOLVER_URL_OVERRIDE_SHA256",
    ],
)

def crate_universe(
        name,
        packages = [],
        cargo_toml_files = [],
        overrides = {},
        repository_template = None,
        supported_targets = [],
        lockfile = None):
    """Resolve crates from a cargo repository which can be consumed as dependencies by targets using rules_rust.

    This is currently highly experimental, and subject to breaking API changes without notice.

    In order to actually use this rule, you will need to make available a built version of the rust binary in `cargo/crate_universe_resolver`
    as an http_file with the name crate_universe_resolver_linux or crate_universe_resolver_darwin (whichever is appropriate for your platform).
    """

    _crate_universe_resolve(
        name = name,
        packages = [package.to_json() for package in packages],
        cargo_toml_files = [_absolutify(label) for label in cargo_toml_files],
        overrides = dict([(k, v.to_json()) for (k, v) in overrides.items()]),
        repository_template = repository_template if repository_template else DEFAULT_REPOSITORY_TEMPLATE,
        supported_targets = supported_targets,
        lockfile = lockfile,
    )

def _absolutify(label):
    if label.startswith("//") or label.startswith("@"):
        return label
    if label.startswith(":"):
        return "//" + native.package_name() + label
    return "//" + native.package_name() + ":" + label

def _spec(
        name,
        semver,
        features = None):
    return struct(
        name = name,
        semver = semver,
        features = features if features else [],
    )

def _override(
        extra_rust_env_vars = None,
        extra_build_script_env_vars = None,
        extra_bazel_deps = None,
        extra_build_script_bazel_deps = None,
        extra_bazel_data_deps = None,
        extra_build_script_bazel_data_deps = None,
        features_to_remove = []):
    for (dep_key, dep_val) in [
        (extra_bazel_deps, extra_bazel_deps),
        (extra_build_script_bazel_deps, extra_build_script_bazel_deps),
        (extra_bazel_data_deps, extra_bazel_data_deps),
        (extra_build_script_bazel_data_deps, extra_build_script_bazel_data_deps),
    ]:
        if dep_val != None:
            if not type(dep_val) == "dict":
                fail("The {} attribute should be a dictionary".format(dep_key))

            for target, deps in dep_val.items():
                if not type(deps) == "list" or any([type(x) != "string" for x in deps]):
                    fail("The {} values should be lists of strings".format(dep_key))

    return struct(
        extra_rust_env_vars = extra_rust_env_vars if extra_rust_env_vars else {},
        extra_build_script_env_vars = extra_build_script_env_vars if extra_build_script_env_vars else {},
        extra_bazel_deps = extra_bazel_deps if extra_bazel_deps else {},
        extra_build_script_bazel_deps = extra_build_script_bazel_deps if extra_build_script_bazel_deps else {},
        extra_bazel_data_deps = extra_bazel_data_deps if extra_bazel_data_deps else {},
        extra_build_script_bazel_data_deps = extra_build_script_bazel_data_deps if extra_build_script_bazel_data_deps else {},
        features_to_remove = features_to_remove,
    )

crate = struct(
    spec = _spec,
    override = _override,
)

# Reexport the dependencies macro
crate_universe_deps = _crate_universe_deps
