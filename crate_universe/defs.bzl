"""A module defining the `crate_universe` rule"""

load("//crate_universe/private:defaults.bzl", "DEFAULT_SHA256_CHECKSUMS", "DEFAULT_URL_TEMPLATE")
load("//crate_universe/private:util.bzl", "get_cargo_and_rustc", "get_host_triple")
load("//rust:repositories.bzl", "DEFAULT_RUST_VERSION", "DEFAULT_TOOLCHAIN_TRIPLES")
load("//rust/platform:triple_mappings.bzl", "system_to_binary_ext", "triple_to_system")
load(":bootstrap.bzl", "BOOTSTRAP_ENV_VAR")

DEFAULT_CRATE_REGISTRY_TEMPLATE = "https://crates.io/api/v1/crates/{crate}/{version}/download"

def _input_content_template(ctx, name, packages, cargo_toml_files, overrides, registry_template, targets, cargo_bin_path):
    """Generate json encoded dependency info for the crate resolver.

    Args:
        ctx (repository_ctx): The repository rule's context object.
        name (str): The name of the repository.
        packages (list): A list of json encoded `crate.spec` entries.
        cargo_toml_files (list): A list of `Label`s to Cargo manifests.
        overrides (dict): A dict of crate name (`str`) to json encoded `crate.override` data.
        registry_template (str): A crate registry url template
        targets (list): A list of target platform triples
        cargo_bin_path (path): The label of a Cargo binary.

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
                cargo = str(cargo_bin_path),
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

def _crate_universe_resolve_impl(repository_ctx):
    """Entry-point repository to manage rust dependencies.

    General flow is:
    - Serialize user-provided rule attributes into JSON
    - Call the Rust resolver script. It writes a `defs.bzl` file in this repo containing the
      transitive dependencies as repo rules in a `pinned_rust_install()` macro.
    - The user then calls defs.bzl%pinned_rust_install().
    """

    host_triple, resolver_triple = get_host_triple(repository_ctx)
    tools = get_cargo_and_rustc(repository_ctx, host_triple)
    extension = system_to_binary_ext(triple_to_system(host_triple))

    if BOOTSTRAP_ENV_VAR in repository_ctx.os.environ and not "RULES_RUST_CRATE_UNIVERSE_RESOLVER_URL_OVERRIDE" in repository_ctx.os.environ:
        resolver_label = Label("@rules_rust_crate_universe_bootstrap//:release/crate_universe_resolver" + extension)
        resolver_path = repository_ctx.path(resolver_label)
    else:
        # Allow for an an override environment variable to define a url to a binary
        resolver_url = repository_ctx.os.environ.get("RULES_RUST_CRATE_UNIVERSE_RESOLVER_URL_OVERRIDE", None)
        resolver_sha = repository_ctx.os.environ.get("RULES_RUST_CRATE_UNIVERSE_RESOLVER_URL_OVERRIDE_SHA256", None)
        if resolver_url:
            if resolver_url.startswith("file://"):
                sha256_result = repository_ctx.execute(["sha256sum", resolver_url[7:]])
                resolver_sha = sha256_result.stdout[:64]
        else:
            resolver_url = repository_ctx.attr.resolver_download_url_template.format(
                host_triple = resolver_triple,
                extension = extension,
            )
            resolver_sha = repository_ctx.attr.resolver_sha256s.get(resolver_triple, None)

        resolver_path = repository_ctx.path("resolver")
        repository_ctx.download(
            url = resolver_url,
            sha256 = resolver_sha,
            output = resolver_path,
            executable = True,
        )

    lockfile_path = None
    if repository_ctx.attr.lockfile:
        lockfile_path = repository_ctx.path(repository_ctx.attr.lockfile)

    input_content = _input_content_template(
        ctx = repository_ctx,
        name = repository_ctx.attr.name,
        packages = repository_ctx.attr.packages,
        cargo_toml_files = repository_ctx.attr.cargo_toml_files,
        overrides = repository_ctx.attr.overrides,
        registry_template = repository_ctx.attr.crate_registry_template,
        targets = repository_ctx.attr.supported_targets,
        cargo_bin_path = tools.cargo,
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
            "CARGO": str(tools.cargo),
            "RUSTC": str(tools.rustc),
            "RUST_LOG": "info",
        },
        quiet = False,
    )
    if result.return_code != 0:
        fail("Error resolving crate_universe deps - see above output for more information")

    repository_ctx.file("BUILD.bazel")

crate_universe = repository_rule(
    doc = """\
A rule for downloading Rust dependencies (crates).

__WARNING__: This rule experimental and subject to change without warning.

Environment Variables:
- `REPIN`: Re-pin the lockfile if set (useful for repinning deps from multiple rulesets).
- `RULES_RUST_REPIN`: Re-pin the lockfile if set (useful for only repinning Rust deps).
- `RULES_RUST_CRATE_UNIVERSE_RESOLVER_URL_OVERRIDE`: Override URL to use to download resolver binary 
    - for local paths use a `file://` URL.
- `RULES_RUST_CRATE_UNIVERSE_RESOLVER_URL_OVERRIDE_SHA256`: An optional sha256 value for the binary at the override url location.
""",
    implementation = _crate_universe_resolve_impl,
    attrs = {
        "cargo_toml_files": attr.label_list(
            doc = "A list of Cargo manifests (`Cargo.toml` files).",
            allow_files = True,
        ),
        "crate_registry_template": attr.string(
            doc = "A template for where to download crates from for the default crate registry. This must contain `{version}` and `{crate}` templates.",
            default = DEFAULT_CRATE_REGISTRY_TEMPLATE,
        ),
        "iso_date": attr.string(
            doc = "The iso_date of cargo binary the resolver should use. Note: This can only be set if `version` is `beta` or `nightly`",
        ),
        "lockfile": attr.label(
            doc = (
                "The path to a file which stores pinned information about the generated dependency graph. " +
                "this target must be a file and will be updated by the repository rule when the `REPIN` " +
                "environment variable is set. If this is not set, dependencies will be re-resolved more " +
                "often, setting this allows caching resolves, but will error if the cache is stale."
            ),
            allow_single_file = True,
            mandatory = False,
        ),
        "overrides": attr.string_dict(
            doc = (
                "Mapping of crate name to specification overrides. See [crate.override](#crateoverride) " +
                " for more details."
            ),
        ),
        "packages": attr.string_list(
            doc = "A list of crate specifications. See [crate.spec](#cratespec) for more details.",
            allow_empty = True,
        ),
        "resolver_download_url_template": attr.string(
            doc = (
                "URL template from which to download the resolver binary. {host_triple} and {extension} will be " +
                "filled in according to the host platform."
            ),
            default = DEFAULT_URL_TEMPLATE,
        ),
        "resolver_sha256s": attr.string_dict(
            doc = "Dictionary of host_triple -> sha256 for resolver binary.",
            default = DEFAULT_SHA256_CHECKSUMS,
        ),
        "rust_toolchain_repository_template": attr.string(
            doc = (
                "The template to use for finding the host `rust_toolchain` repository. `{version}` (eg. '1.53.0'), " +
                "`{triple}` (eg. 'x86_64-unknown-linux-gnu'), `{system}` (eg. 'darwin'), and `{arch}` (eg. 'aarch64') " +
                "will be replaced in the string if present."
            ),
            default = "rust_{system}_{arch}",
        ),
        "sha256s": attr.string_dict(
            doc = "The sha256 checksum of the desired rust artifacts",
        ),
        "supported_targets": attr.string_list(
            doc = (
                "A list of supported [platform triples](https://doc.rust-lang.org/nightly/rustc/platform-support.html) " +
                "to consider when resoliving dependencies."
            ),
            allow_empty = False,
            default = DEFAULT_TOOLCHAIN_TRIPLES.keys(),
        ),
        "version": attr.string(
            doc = "The version of cargo the resolver should use",
            default = DEFAULT_RUST_VERSION,
        ),
    },
    environ = [
        "REPIN",
        "RULES_RUST_REPIN",
        "RULES_RUST_CRATE_UNIVERSE_RESOLVER_URL_OVERRIDE",
        "RULES_RUST_CRATE_UNIVERSE_RESOLVER_URL_OVERRIDE_SHA256",
        BOOTSTRAP_ENV_VAR,
    ],
)

def _spec(
        name,
        semver,
        features = None):
    """A simple crate definition for use in the `crate_universe` rule.

    __WARNING__: This rule experimental and subject to change without warning.

    Example:

    ```python
    load("@rules_rust//crate_universe:defs.bzl", "crate_universe", "crate")

    crate_universe(
        name = "spec_example",
        packages = [
            crate.spec(
                name = "lazy_static",
                semver = "=1.4",
            ),
        ],
    )
    ```

    Args:
        name (str): The name of the crate as it would appear in a crate registry.
        semver (str): The desired version ([semver](https://semver.org/)) of the crate
        features (list, optional): A list of desired [features](https://doc.rust-lang.org/cargo/reference/features.html).

    Returns:
        str: A json encoded struct of crate info
    """
    return json.encode(struct(
        name = name,
        semver = semver,
        features = features or [],
    ))

def _override(
        extra_bazel_data_deps = None,
        extra_bazel_deps = None,
        extra_build_script_bazel_data_deps = None,
        extra_build_script_bazel_deps = None,
        extra_build_script_env_vars = None,
        extra_rustc_env_vars = None,
        features_to_remove = []):
    """A map of overrides for a particular crate

    __WARNING__: This rule experimental and subject to change without warning.

    Example:

    ```python
    load("@rules_rust//crate_universe:defs.bzl", "crate_universe", "crate")

    crate_universe(
        name = "override_example",
        # [...]
        overrides = {
            "tokio": crate.override(
                extra_rustc_env_vars = {
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

    Args:
        extra_bazel_data_deps (dict, optional): Targets to add to the `data` attribute
            of the generated target (eg: [rust_library.data](./defs.md#rust_library-data)).
        extra_bazel_deps (dict, optional): Targets to add to the `deps` attribute
            of the generated target (eg: [rust_library.deps](./defs.md#rust_library-data)).
        extra_rustc_env_vars (dict, optional): Environment variables to add to the `rustc_env`
            attribute for the generated target (eg: [rust_library.rustc_env](./defs.md#rust_library-rustc_env)).
        extra_build_script_bazel_data_deps (dict, optional): Targets to add to the
            [data](./cargo_build_script.md#cargo_build_script-data) attribute of the generated
            `cargo_build_script` target.
        extra_build_script_bazel_deps (dict, optional): Targets to add to the
            [deps](./cargo_build_script.md#cargo_build_script-deps) attribute of the generated
            `cargo_build_script` target.
        extra_build_script_env_vars (dict, optional): Environment variables to add to the
            [build_script_env](./cargo_build_script.md#cargo_build_script-build_script_env)
            attribute of the generated `cargo_build_script` target.
        features_to_remove (list, optional): A list of features to remove from a generated target.

    Returns:
        str: A json encoded struct of crate overrides
    """
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
        extra_rustc_env_vars = extra_rustc_env_vars or {},
        extra_build_script_env_vars = extra_build_script_env_vars or {},
        extra_bazel_deps = extra_bazel_deps or {},
        extra_build_script_bazel_deps = extra_build_script_bazel_deps or {},
        extra_bazel_data_deps = extra_bazel_data_deps or {},
        extra_build_script_bazel_data_deps = extra_build_script_bazel_data_deps or {},
        features_to_remove = features_to_remove,
    ))

crate = struct(
    spec = _spec,
    override = _override,
)
