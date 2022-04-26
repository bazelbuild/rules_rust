"""Utilities directly related to the `splicing` step of `cargo-bazel`."""

load(":common_utils.bzl", "cargo_environ", "execute")

CARGO_BAZEL_DEBUG = "CARGO_BAZEL_DEBUG"

def splicing_config(resolver_version = "1"):
    """arious settings used to configure Cargo manifest splicing behavior.

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

def download_extra_workspace_members(repository_ctx, cache_dir, render_template_registry_url):
    """Download additional workspace members for use in splicing.

    Args:
        repository_ctx (repository_ctx): The rule's context object.
        cache_dir (path): A directory in which to download and extract extra workspace members
        render_template_registry_url (str): The base template to use for determining the crate's registry URL.

    Returns:
        list: A list of information related to the downloaded crates
            - manifest: The path of the manifest.
            - url: The url the manifest came from.
            - sha256: The sha256 checksum of the new manifest.
    """
    manifests = []
    extra_workspace_members = repository_ctx.attr.extra_workspace_members
    if extra_workspace_members:
        repository_ctx.report_progress("Downloading extra workspace members.")

    for name, spec in repository_ctx.attr.extra_workspace_members.items():
        spec = struct(**json.decode(spec))

        url = render_template_registry_url
        url = url.replace("{name}", name)
        url = url.replace("{version}", spec.version)

        if spec.sha256:
            result = repository_ctx.download_and_extract(
                output = cache_dir,
                url = url,
                sha256 = spec.sha256,
                type = "tar.gz",
            )
        else:
            result = repository_ctx.download_and_extract(
                output = cache_dir,
                url = url,
                type = "tar.gz",
            )

        manifest = repository_ctx.path("{}/{}-{}/Cargo.toml".format(
            cache_dir,
            name,
            spec.version,
        ))

        if not manifest.exists:
            fail("Extra workspace member '{}' has no root Cargo.toml file".format(name))

        manifests.append(struct(
            manifest = str(manifest),
            url = url,
            sha256 = result.sha256,
        ))

    return manifests

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
    """Produce a manifest containing required components for splciing a new Cargo workspace

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

    repo_dir = repository_ctx.path(".")

    splicing_manifest = repository_ctx.path("{}/splicing_manifest.json".format(repo_dir))

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

def splice_workspace_manifest(repository_ctx, generator, lockfile, splicing_manifest, cargo, rustc):
    """Splice together a Cargo workspace from various other manifests and package definitions

    Args:
        repository_ctx (repository_ctx): The rule's context object.
        generator (path): The `cargo-bazel` binary.
        lockfile (path): The path to a "lock" file for reproducible `cargo-bazel` renderings.
        splicing_manifest (path): The path to a splicing manifest.
        cargo (path): The path to a Cargo binary.
        rustc (path): The Path to a Rustc binary.

    Returns:
        path: The path to a Cargo metadata json file found in the spliced workspace root.
    """
    repository_ctx.report_progress("Splicing Cargo workspace.")
    repo_dir = repository_ctx.path(".")

    # Download extra workspace members
    crates_cache_dir = repository_ctx.path("{}/.crates_cache".format(repo_dir))
    extra_manifest_info = download_extra_workspace_members(
        repository_ctx = repository_ctx,
        cache_dir = crates_cache_dir,
        render_template_registry_url = repository_ctx.attr.extra_workspace_member_url_template,
    )

    extra_manifests_manifest = repository_ctx.path("{}/extra_manifests_manifest.json".format(repo_dir))
    repository_ctx.file(
        extra_manifests_manifest,
        json.encode_indent(struct(
            manifests = extra_manifest_info,
        ), indent = " " * 4),
    )

    splicing_output_dir = repository_ctx.path("splicing-output")

    # Generate a workspace root which contains all workspace members
    arguments = [
        generator,
        "splice",
        "--output-dir",
        splicing_output_dir,
        "--splicing-manifest",
        splicing_manifest,
        "--extra-manifests-manifest",
        extra_manifests_manifest,
        "--cargo",
        cargo,
        "--rustc",
        rustc,
    ]

    # Optionally set the splicing workspace directory to somewhere within the repository directory
    # to improve the debugging experience.
    if CARGO_BAZEL_DEBUG in repository_ctx.os.environ:
        arguments.extend([
            "--workspace-dir",
            repository_ctx.path("{}/splicing-workspace".format(repo_dir)),
        ])

    # Splicing accepts a Cargo.lock file in some scenarios. Ensure it's passed
    # if the lockfile is a actually a Cargo lockfile.
    if lockfile.kind == "cargo":
        arguments.extend([
            "--cargo-lockfile",
            lockfile.path,
        ])

    env = {
        "CARGO": str(cargo),
        "RUSTC": str(rustc),
        "RUST_BACKTRACE": "full",
    }

    # Add any Cargo environment variables to the `cargo-bazel` execution
    env.update(cargo_environ(repository_ctx))

    execute(
        repository_ctx = repository_ctx,
        args = arguments,
        env = env,
    )

    # This file must have been produced by the execution above.
    spliced_lockfile = repository_ctx.path("{}/Cargo.lock".format(splicing_output_dir))
    if not spliced_lockfile.exists:
        fail("Lockfile file does not exist: {}".format(spliced_lockfile))
    spliced_metadata = repository_ctx.path("{}/metadata.json".format(splicing_output_dir))
    if not spliced_metadata.exists:
        fail("Metadata file does not exist: {}".format(spliced_metadata))

    return spliced_metadata
