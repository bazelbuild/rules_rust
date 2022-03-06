"""Utilities directly related to the `generate` step of `cargo-bazel`."""

load(":common_utils.bzl", "CARGO_BAZEL_ISOLATED", "cargo_environ", "execute")

CARGO_BAZEL_GENERATOR_SHA256 = "CARGO_BAZEL_GENERATOR_SHA256"
CARGO_BAZEL_GENERATOR_URL = "CARGO_BAZEL_GENERATOR_URL"
CARGO_BAZEL_REPIN = "CARGO_BAZEL_REPIN"
REPIN = "REPIN"

GENERATOR_ENV_VARS = [
    CARGO_BAZEL_GENERATOR_URL,
    CARGO_BAZEL_GENERATOR_SHA256,
]

REPIN_ENV_VARS = [
    REPIN,
    CARGO_BAZEL_REPIN,
]

CRATES_REPOSITORY_ENVIRON = GENERATOR_ENV_VARS + REPIN_ENV_VARS + [
    CARGO_BAZEL_ISOLATED,
]

def get_generator(repository_ctx, host_triple):
    """Query network resources to locate a `cargo-bazel` binary

    Args:
        repository_ctx (repository_ctx): The rule's context object.
        host_triple (string): A string representing the host triple

    Returns:
        tuple(path, dict): The path to a `cargo-bazel` binary and the host sha256 pairing.
            The pairing (dict) may be `None` if there is no need to update the attribute
    """
    use_environ = False
    for var in GENERATOR_ENV_VARS:
        if var in repository_ctx.os.environ:
            use_environ = True

    output = repository_ctx.path("cargo-bazel.exe" if "win" in repository_ctx.os.name else "cargo-bazel")

    # The `generator` attribute is the next highest priority behind
    # environment variables. We check those first before deciding to
    # use an explicitly provided variable.
    if not use_environ and repository_ctx.attr.generator:
        generator = repository_ctx.path(Label(repository_ctx.attr.generator))

        # Resolve a few levels of symlinks to ensure we're accessing the direct binary
        for _ in range(1, 100):
            real_generator = generator.realpath
            if real_generator == generator:
                break
            generator = real_generator
        return generator, None

    # The environment variable will take precedence if set
    if use_environ:
        generator_sha256 = repository_ctx.os.environ.get(CARGO_BAZEL_GENERATOR_SHA256)
        generator_url = repository_ctx.os.environ.get(CARGO_BAZEL_GENERATOR_URL)
    else:
        generator_sha256 = repository_ctx.attr.generator_sha256s.get(host_triple)
        generator_url = repository_ctx.attr.generator_urls.get(host_triple)

    if not generator_url:
        fail((
            "No generator URL was found either in the `CARGO_BAZEL_GENERATOR_URL` " +
            "environment variable or for the `{}` triple in the `generator_urls` attribute"
        ).format(host_triple))

    # Download the file into place
    if generator_sha256:
        repository_ctx.download(
            output = output,
            url = generator_url,
            sha256 = generator_sha256,
            executable = True,
        )
        return output, None

    result = repository_ctx.download(
        output = output,
        url = generator_url,
        executable = True,
    )

    return output, {host_triple: result.sha256}

def render_config(
        build_file_template = "//:BUILD.{name}-{version}.bazel",
        crate_label_template = "@{repository}__{name}-{version}//:{target}",
        crate_repository_template = "{repository}__{name}-{version}",
        crates_module_template = "//:{file}",
        default_package_name = None,
        platforms_template = "@rules_rust//rust/platform:{triple}",
        vendor_mode = None):
    """Various settings used to configure rendered outputs

    The template parameters each support a select number of format keys. A description of each key
    can be found below where the supported keys for each template can be found in the parameter docs

    | key | definition |
    | --- | --- |
    | `name` | The name of the crate. Eg `tokio` |
    | `repository` | The rendered repository name for the crate. Directly relates to `crate_repository_template`. |
    | `triple` | A platform triple. Eg `x86_64-unknown-linux-gnu` |
    | `version` | The crate version. Eg `1.2.3` |
    | `target` | The library or binary target of the crate |
    | `file` | The basename of a file |

    Args:
        build_file_template (str, optional): The base template to use for BUILD file names. The available format keys
            are [`{name}`, {version}`].
        crate_label_template (str, optional): The base template to use for crate labels. The available format keys
            are [`{repository}`, `{name}`, `{version}`, `{target}`].
        crate_repository_template (str, optional): The base template to use for Crate label repository names. The
            available format keys are [`{repository}`, `{name}`, `{version}`].
        crates_module_template (str, optional): The pattern to use for the `defs.bzl` and `BUILD.bazel`
            file names used for the crates module. The available format keys are [`{file}`].
        default_package_name (str, optional): The default package name to in the rendered macros. This affects the
            auto package detection of things like `all_crate_deps`.
        platforms_template (str, optional): The base template to use for platform names.
            See [platforms documentation](https://docs.bazel.build/versions/main/platforms.html). The available format
            keys are [`{triple}`].
        vendor_mode (str, optional): An optional configuration for rendirng content to be rendered into repositories.

    Returns:
        string: A json encoded struct to match the Rust `config::RenderConfig` struct
    """
    return json.encode(struct(
        build_file_template = build_file_template,
        crate_label_template = crate_label_template,
        crate_repository_template = crate_repository_template,
        crates_module_template = crates_module_template,
        default_package_name = default_package_name,
        platforms_template = platforms_template,
        vendor_mode = vendor_mode,
    ))

def _crate_id(name, version):
    """Creates a `cargo_bazel::config::CrateId`.

    Args:
        name (str): The name of the crate
        version (str): The crate's version

    Returns:
        str: A serialized representation of a CrateId
    """
    return "{} {}".format(name, version)

def collect_crate_annotations(annotations, repository_name):
    """Deserialize and sanitize crate annotations.

    Args:
        annotations (dict): A mapping of crate names to lists of serialized annotations
        repository_name (str): The name of the repository that owns the annotations

    Returns:
        dict: A mapping of `cargo_bazel::config::CrateId` to sets of annotations
    """
    annotations = {name: [json.decode(a) for a in annotation] for name, annotation in annotations.items()}
    crate_annotations = {}
    for name, annotation in annotations.items():
        for (version, data) in annotation:
            if name == "*" and version != "*":
                fail(
                    "Wildcard crate names must have wildcard crate versions. " +
                    "Please update the `annotations` attribute of the {} crates_repository".format(
                        repository_name,
                    ),
                )
            id = _crate_id(name, version)
            if id in crate_annotations:
                fail("Found duplicate entries for {}".format(id))

            crate_annotations.update({id: data})
    return crate_annotations

def _read_cargo_config(repository_ctx):
    if repository_ctx.attr.cargo_config:
        config = repository_ctx.path(repository_ctx.attr.cargo_config)
        return repository_ctx.read(config)
    return None

def _get_render_config(repository_ctx):
    if repository_ctx.attr.render_config:
        config = dict(json.decode(repository_ctx.attr.render_config))
    else:
        config = dict(json.decode(render_config()))

    # Add the repository name as it's very relevant to rendering.
    config.update({"repository_name": repository_ctx.name})

    return struct(**config)

def generate_config(repository_ctx):
    """Generate a config file from various attributes passed to the rule.

    Args:
        repository_ctx (repository_ctx): The rule's context object.

    Returns:
        struct: A struct containing the path to a config and it's contents
    """
    annotations = collect_crate_annotations(repository_ctx.attr.annotations, repository_ctx.name)

    # Load additive build files if any have been provided.
    content = list()
    for data in annotations.values():
        additive_build_file_content = data.pop("additive_build_file_content", None)
        if additive_build_file_content:
            content.append(additive_build_file_content)
        additive_build_file = data.pop("additive_build_file", None)
        if additive_build_file:
            file_path = repository_ctx.path(Label(additive_build_file))
            content.append(repository_ctx.read(file_path))
        data.update({"additive_build_file_content": "\n".join(content) if content else None})

    config = struct(
        generate_build_scripts = repository_ctx.attr.generate_build_scripts,
        annotations = annotations,
        cargo_config = _read_cargo_config(repository_ctx),
        rendering = _get_render_config(repository_ctx),
        supported_platform_triples = repository_ctx.attr.supported_platform_triples,
    )

    config_path = repository_ctx.path("cargo-bazel.json")
    repository_ctx.file(
        config_path,
        json.encode_indent(config, indent = " " * 4),
    )

    # This was originally written to return a struct and not just the config path
    # so splicing can have access to some rendering information embedded in the config
    # If splicing should no longer need that info, it'd be simpler to just return a `path`.
    return struct(
        path = config_path,
        info = config,
    )

def get_lockfile(repository_ctx):
    """Locate the lockfile and identify the it's type (Cargo or Bazel).

    Args:
        repository_ctx (repository_ctx): The rule's context object.

    Returns:
        struct: The path to the lockfile as well as it's type
    """
    if repository_ctx.attr.lockfile_kind == "auto":
        if str(repository_ctx.attr.lockfile).endswith("Cargo.lock"):
            kind = "cargo"
        else:
            kind = "bazel"
    else:
        kind = repository_ctx.attr.lockfile_kind

    return struct(
        path = repository_ctx.path(repository_ctx.attr.lockfile),
        kind = kind,
    )

def determine_repin(repository_ctx, generator, lockfile_path, lockfile_kind, config, splicing_manifest, cargo, rustc):
    """Use the `cargo-bazel` binary to determine whether or not dpeendencies need to be re-pinned

    Args:
        repository_ctx (repository_ctx): The rule's context object.
        generator (path): The path to a `cargo-bazel` binary.
        config (path): The path to a `cargo-bazel` config file. See `generate_config`.
        splicing_manifest (path): The path to a `cargo-bazel` splicing manifest. See `create_splicing_manifest`
        lockfile_path (path): The path to a "lock" file for reproducible outputs.
        lockfile_kind (str): The type of lock file represented by `lockfile_path`
        cargo (path): The path to a Cargo binary.
        rustc (path): The path to a Rustc binary.

    Returns:
        bool: True if dependencies need to be re-pinned
    """

    # If a repin environment variable is set, always repin
    for var in REPIN_ENV_VARS:
        if repository_ctx.os.environ.get(var, "").lower() in ["true", "yes", "1", "on"]:
            return True

    # Cargo lockfiles should always be repinned.
    if lockfile_kind == "cargo":
        return True

    # Run the binary to check if a repin is needed
    args = [
        generator,
        "query",
        "--lockfile",
        lockfile_path,
        "--config",
        config,
        "--splicing-manifest",
        splicing_manifest,
        "--cargo",
        cargo,
        "--rustc",
        rustc,
    ]

    env = {
        "CARGO": str(cargo),
        "RUSTC": str(rustc),
        "RUST_BACKTRACE": "full",
    }

    # Add any Cargo environment variables to the `cargo-bazel` execution
    env.update(cargo_environ(repository_ctx))

    result = execute(
        repository_ctx = repository_ctx,
        args = args,
        env = env,
    )

    # If it was determined repinning should occur but there was no
    # flag indicating repinning was requested, an error is raised
    # since repinning should be an explicit action
    if result.stdout.strip().lower() == "repin":
        # buildifier: disable=print
        print(result.stderr)
        fail((
            "The current `lockfile` is out of date for '{}'. Please re-run " +
            "bazel using `CARGO_BAZEL_REPIN=true` if this is expected " +
            "and the lockfile should be updated."
        ).format(repository_ctx.name))

    return False

def execute_generator(
        repository_ctx,
        lockfile_path,
        lockfile_kind,
        generator,
        config,
        splicing_manifest,
        repository_dir,
        cargo,
        rustc,
        repin = False,
        metadata = None):
    """Execute the `cargo-bazel` binary to produce `BUILD` and `.bzl` files.

    Args:
        repository_ctx (repository_ctx): The rule's context object.
        lockfile_path (path): The path to a "lock" file (file used for reproducible renderings).
        lockfile_kind (str): The type of lockfile given (Cargo or Bazel).
        generator (path): The path to a `cargo-bazel` binary.
        config (path): The path to a `cargo-bazel` config file.
        splicing_manifest (path): The path to a `cargo-bazel` splicing manifest. See `create_splicing_manifest`
        repository_dir (path): The output path for the Bazel module and BUILD files.
        cargo (path): The path of a Cargo binary.
        rustc (path): The path of a Rustc binary.
        repin (bool, optional): Whether or not to repin dependencies
        metadata (path, optional): The path to a Cargo metadata json file.

    Returns:
        struct: The results of `repository_ctx.execute`.
    """
    repository_ctx.report_progress("Generating crate BUILD files.")

    args = [
        generator,
        "generate",
        "--lockfile",
        lockfile_path,
        "--lockfile-kind",
        lockfile_kind,
        "--config",
        config,
        "--splicing-manifest",
        splicing_manifest,
        "--repository-dir",
        repository_dir,
        "--cargo",
        cargo,
        "--rustc",
        rustc,
    ]

    env = {
        "RUST_BACKTRACE": "full",
    }

    # Some components are not required unless re-pinning is enabled
    if repin:
        args.extend([
            "--repin",
            "--metadata",
            metadata,
        ])
        env.update({
            "CARGO": str(cargo),
            "RUSTC": str(rustc),
        })

    # Add any Cargo environment variables to the `cargo-bazel` execution
    env.update(cargo_environ(repository_ctx))

    result = execute(
        repository_ctx = repository_ctx,
        args = args,
        env = env,
    )

    return result
