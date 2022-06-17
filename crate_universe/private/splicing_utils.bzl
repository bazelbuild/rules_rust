"""Utilities directly related to the `splicing` step of `cargo-bazel`."""

CARGO_BAZEL_DEBUG = "CARGO_BAZEL_DEBUG"

def splicing_config(resolver_version = "1"):
    """Various settings used to configure Cargo manifest splicing behavior.

    [rv]: https://doc.rust-lang.org/cargo/reference/resolver.html#resolver-versions

    Args:
        resolver_version (str, optional): The [resolver version][rv] to use in generated Cargo
            manifests. This flag is **only** used when splicing a manifest from direct package
            definitions. See `crates_repository::packages`.

    Returns:
        str: A json encoded string of the parameters provided
    """
    return json.encode(struct(
        resolver_version = resolver_version,
    ))

def kebab_case_keys(data):
    """Ensure the key value of the data given are kebab-case

    Args:
        data (dict): A deserialized json blob

    Returns:
        dict: The same `data` but with kebab-case keys
    """
    return {
        key.lower().replace("_", "-"): val
        for (key, val) in data.items()
    }

def compile_splicing_manifest(splicing_config, manifests, cargo_config_path, packages):
    """Produce a manifest containing required components for splciing a new Cargo workspace

    [cargo_config]: https://doc.rust-lang.org/cargo/reference/config.html
    [cargo_toml]: https://doc.rust-lang.org/cargo/reference/manifest.html

    Args:
        splicing_config (dict): A deserialized `splicing_config`
        manifests (dict): A mapping of paths to Bazel labels which represent [Cargo manifests][cargo_toml].
        cargo_config_path (str): The absolute path to a [Cargo config][cargo_config].
        packages (dict): A set of crates (packages) specifications to depend on

    Returns:
        dict: A dictionary representation of a `cargo_bazel::splicing::SplicingManifest`
    """

    # Deserialize information about direct packges
    direct_packages_info = {
        # Ensure the data is using kebab-case as that's what `cargo_toml::DependencyDetail` expects.
        pkg: kebab_case_keys(dict(json.decode(data)))
        for (pkg, data) in packages.items()
    }

    # Auto-generated splicier manifest values
    splicing_manifest_content = {
        "cargo_config": cargo_config_path,
        "direct_packages": direct_packages_info,
        "manifests": manifests,
    }

    return dict(splicing_config.items() + splicing_manifest_content.items())

def create_splicing_manifest(repository_ctx):
    """Produce a manifest containing required components for splicing a new Cargo workspace

    Args:
        repository_ctx (repository_ctx): The rule's context object.

    Returns:
        path: The path to a json encoded manifest
    """

    manifests = {str(repository_ctx.path(m)): str(m) for m in repository_ctx.attr.manifests}

    if repository_ctx.attr.cargo_config:
        cargo_config = str(repository_ctx.path(repository_ctx.attr.cargo_config))
    else:
        cargo_config = None

    # Load user configurable splicing settings
    config = json.decode(repository_ctx.attr.splicing_config or splicing_config())

    splicing_manifest = "splicing_manifest.json"

    data = compile_splicing_manifest(
        splicing_config = config,
        manifests = manifests,
        cargo_config_path = cargo_config,
        packages = repository_ctx.attr.packages,
    )

    # Serialize information required for splicing
    repository_ctx.file(
        splicing_manifest,
        json.encode_indent(
            data,
            indent = " " * 4,
        ),
    )

    return splicing_manifest
