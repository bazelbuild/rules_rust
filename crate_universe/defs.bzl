"""A module defining the `crate_universe` rule"""

load("//rust:repositories.bzl", "DEFAULT_TOOLCHAIN_TRIPLES")
load(":deps.bzl", _crate_universe_deps = "crate_universe_deps")

DEFAULT_CRATE_REGISTRY_TEMPLATE = "https://crates.io/api/v1/crates/{crate}/{version}/download"

_CPU_ARCH_ERROR_MSG = """\
Command failed with exit code '{code}': {args}
----------stdout:
{stdout}
----------stderr:
{stderr}
"""

def _input_content_template(ctx, name, packages, cargo_toml_files, overrides, registry_template, targets, cargo_bin_label):
    """Generate json encoded dependency info for the crate resolver.

    Args:
        ctx (repository_ctx): The repository rule's context object.
        name (str): The name of the repository.
        packages (list): A list of json encoded `crate.spec` entries.
        cargo_toml_files (list): A list of `Label`s to Cargo manifests.
        overrides (dict): A dict of crate name (`str`) to json encoded `crate.override` data.
        registry_template (str): A crate registry url template
        targets (list): A list of target platform triples
        cargo_bin_label (Label): The label of a Cargo binary.

    Returns:
        str: Json encoded config data for the resolver
    """

    # packages are expected to be json encoded, so we decode them
    # to ensure they are correctly re-encoded
    dcoded_pkgs = [json.decode(artifact) for artifact in packages]

    # Generate an easy to use map of `Cargo.toml` files
    encodable_cargo_toml_files = dict()
    for label in cargo_toml_files:
        encodable_cargo_toml_files.update({str(label): str(ctx.path(label))})

    # Overrides are passed as encoded json strings, so we decode
    # them to ensure they are correctly re-encoded
    encodable_overrides = dict()
    for key, value in overrides.items():
        encodable_overrides.update({key: json.decode(value)})

    return "{}\n".format(
        json.encode_indent(
            struct(
                cargo = str(ctx.path(cargo_bin_label)),
                cargo_toml_files = encodable_cargo_toml_files,
                crate_registry_template = registry_template,
                overrides = encodable_overrides,
                packages = dcoded_pkgs,
                repository_name = name,
                target_triples = targets,
            ),
            indent = " " * 4,
        ),
    )

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
    input_content = _input_content_template(
        ctx = repository_ctx,
        name = repository_ctx.attr.name,
        packages = repository_ctx.attr.packages,
        cargo_toml_files = repository_ctx.attr.cargo_toml_files,
        overrides = repository_ctx.attr.overrides,
        registry_template = repository_ctx.attr.crate_registry_template,
        targets = repository_ctx.attr.supported_targets,
        cargo_bin_label = cargo_label,
    )

    input_path = "{name}.resolver_config.json".format(name = repository_ctx.attr.name)
    repository_ctx.file(input_path, content = input_content)

    args = [
        resolver_path,
        "--input_path",
        input_path,
        "--repository_dir",
        repository_ctx.path("."),
        "--repo-name",
        repository_ctx.attr.name,
    ]
    if lockfile_path != None:
        args.append("--lockfile")
        str(args.append(lockfile_path))
    env_var_names = repository_ctx.os.environ.keys()
    if "RULES_RUST_REPIN" in env_var_names or "REPIN" in env_var_names:
        args.append("--update-lockfile")

    result = repository_ctx.execute(
        args,
        environment = {
            # The resolver invokes `cargo metadata` which relies on `rustc` being on the $PATH
            # See https://github.com/rust-lang/cargo/issues/8219
            "CARGO": str(repository_ctx.path(cargo_label)),
            "RUSTC": str(repository_ctx.path(rustc_label)),
            "RUST_LOG": "info",
        },
    )
    if result.stderr:
        print("Output from resolver: " + result.stderr)  # buildifier: disable=print
    if result.return_code != 0:
        fail("Error resolving deps:\n" + result.stdout + "\n" + result.stderr)

    repository_ctx.file("BUILD.bazel")

crate_universe = repository_rule(
    doc = """\
A rule for downloading Rust dependencies (crates).

Environment Variables:
- `REPIN`: Re-pin the lockfile if set (useful for repinning deps from multiple rulesets).
- `RULES_RUST_REPIN`: Re-pin the lockfile if set (useful for only repinning Rust deps).
- `RULES_RUST_CRATE_UNIVERSE_RESOLVER_URL_OVERRIDE`: Override URL to use to download resolver binary - for local paths use a `file://` URL.

`override` Example:

```python
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
```
""",
    implementation = _crate_universe_resolve_impl,
    attrs = {
        "cargo_toml_files": attr.label_list(
            doc = "",
        ),
        "crate_registry_template": attr.string(
            doc = "A Crate registry url template. This must contain `{version}` and `{crate}` templates",
            default = DEFAULT_CRATE_REGISTRY_TEMPLATE,
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
        "supported_targets": attr.string_list(
            doc = "",
            allow_empty = False,
            default = DEFAULT_TOOLCHAIN_TRIPLES.keys(),
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

def _spec(
        name,
        semver,
        features = None):
    return json.encode(struct(
        name = name,
        semver = semver,
        features = features if features else [],
    ))

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

    return json.encode(struct(
        extra_rust_env_vars = extra_rust_env_vars if extra_rust_env_vars else {},
        extra_build_script_env_vars = extra_build_script_env_vars if extra_build_script_env_vars else {},
        extra_bazel_deps = extra_bazel_deps if extra_bazel_deps else {},
        extra_build_script_bazel_deps = extra_build_script_bazel_deps if extra_build_script_bazel_deps else {},
        extra_bazel_data_deps = extra_bazel_data_deps if extra_bazel_data_deps else {},
        extra_build_script_bazel_data_deps = extra_build_script_bazel_data_deps if extra_build_script_bazel_data_deps else {},
        features_to_remove = features_to_remove,
    ))

crate = struct(
    spec = _spec,
    override = _override,
)

# Reexport the dependencies macro
crate_universe_deps = _crate_universe_deps
