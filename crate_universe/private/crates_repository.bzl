"""`crates_repository` rule implementation"""

load("//crate_universe/private:common_utils.bzl", "get_host_triple", "get_rust_tools")
load(
    "//crate_universe/private:generate_utils.bzl",
    "CRATES_REPOSITORY_ENVIRON",
    "determine_repin",
    "execute_generator",
    "generate_config",
    "get_generator",
    "get_lockfile",
)
load(
    "//crate_universe/private:splicing_utils.bzl",
    "create_splicing_manifest",
    "splice_workspace_manifest",
)
load("//crate_universe/private:urls.bzl", "CARGO_BAZEL_SHA256S", "CARGO_BAZEL_URLS")
load("//rust:defs.bzl", "rust_common")
load("//rust/platform:triple_mappings.bzl", "SUPPORTED_PLATFORM_TRIPLES")

def _crates_repository_impl(repository_ctx):
    # Determine the current host's platform triple
    host_triple = get_host_triple(repository_ctx)

    # Locate the generator to use
    generator, generator_sha256 = get_generator(repository_ctx, host_triple.triple)

    # Generate a config file for all settings
    config_path = generate_config(repository_ctx)

    # Locate the lockfile
    lockfile = get_lockfile(repository_ctx)

    # Locate Rust tools (cargo, rustc)
    tools = get_rust_tools(repository_ctx, host_triple)
    cargo_path = repository_ctx.path(tools.cargo)
    rustc_path = repository_ctx.path(tools.rustc)

    # Create a manifest of all dependency inputs
    splicing_manifest = create_splicing_manifest(repository_ctx)

    # Determine whether or not to repin depednencies
    repin = determine_repin(
        repository_ctx = repository_ctx,
        generator = generator,
        lockfile_path = lockfile.path,
        lockfile_kind = lockfile.kind,
        config = config_path,
        splicing_manifest = splicing_manifest,
        cargo = cargo_path,
        rustc = rustc_path,
    )

    # If re-pinning is enabled, gather additional inputs for the generator
    kwargs = dict()
    if repin or lockfile.kind == "cargo":
        # Generate a top level Cargo workspace and manifest for use in generation
        metadata_path = splice_workspace_manifest(
            repository_ctx = repository_ctx,
            generator = generator,
            lockfile = lockfile,
            splicing_manifest = splicing_manifest,
            cargo = cargo_path,
            rustc = rustc_path,
        )

        kwargs.update({
            "metadata": metadata_path,
            "repin": True,
        })

    # Run the generator
    execute_generator(
        repository_ctx = repository_ctx,
        generator = generator,
        config = config_path,
        splicing_manifest = splicing_manifest,
        lockfile_path = lockfile.path,
        lockfile_kind = lockfile.kind,
        repository_dir = repository_ctx.path("."),
        cargo = cargo_path,
        rustc = rustc_path,
        # sysroot = tools.sysroot,
        **kwargs
    )

    # Determine the set of reproducible values
    attrs = {attr: getattr(repository_ctx.attr, attr) for attr in dir(repository_ctx.attr)}
    exclude = ["to_json", "to_proto"]
    for attr in exclude:
        attrs.pop(attr, None)

    # Note that this is only scoped to the current host platform. Users should
    # ensure they provide all the values necessary for the host environments
    # they support
    if generator_sha256:
        attrs.update({"generator_sha256s": generator_sha256})

    return attrs

crates_repository = repository_rule(
    doc = """\
A rule for defining and downloading Rust dependencies (crates).

Environment Variables:

| variable | usage |
| --- | --- |
| `CARGO_BAZEL_GENERATOR_SHA256` | The sha256 checksum of the file located at `CARGO_BAZEL_GENERATOR_URL` |
| `CARGO_BAZEL_GENERATOR_URL` | The URL of a cargo-bazel binary. This variable takes precedence over attributes and can use `file://` for local paths |
| `CARGO_BAZEL_ISOLATED` | An authorative flag as to whether or not the `CARGO_HOME` environment variable should be isolated from the host configuration |
| `CARGO_BAZEL_REPIN` | An indicator that the dependencies represented by the rule should be regenerated. `REPIN` may also be used. |

""",
    implementation = _crates_repository_impl,
    attrs = {
        "annotations": attr.string_list_dict(
            doc = "Extra settings to apply to crates. See [crate.annotation](#crateannotation).",
        ),
        "cargo_config": attr.label(
            doc = "A [Cargo configuration](https://doc.rust-lang.org/cargo/reference/config.html) file",
        ),
        "extra_workspace_member_url_template": attr.string(
            doc = "The registry url to use when fetching extra workspace members",
            default = "https://crates.io/api/v1/crates/{name}/{version}/download",
        ),
        "extra_workspace_members": attr.string_dict(
            doc = (
                "Additional crates to download and include as a workspace member. This is unfortunately required in " +
                "order to add information about \"binary-only\" crates so that a `rust_binary` may be generated for " +
                "it. [rust-lang/cargo#9096](https://github.com/rust-lang/cargo/issues/9096) tracks an RFC which may " +
                "solve for this."
            ),
        ),
        "generate_build_scripts": attr.bool(
            doc = (
                "Whether or not to generate " +
                "[cargo build scripts](https://doc.rust-lang.org/cargo/reference/build-scripts.html) by default."
            ),
            default = True,
        ),
        "generator": attr.string(
            doc = (
                "The absolute label of a generator. Eg. `@cargo_bazel_bootstrap//:cargo-bazel`. " +
                "This is typically used when bootstrapping"
            ),
        ),
        "generator_sha256s": attr.string_dict(
            doc = "Dictionary of `host_triple` -> `sha256` for a `cargo-bazel` binary.",
            default = CARGO_BAZEL_SHA256S,
        ),
        "generator_urls": attr.string_dict(
            doc = (
                "URL template from which to download the `cargo-bazel` binary. `{host_triple}` and will be " +
                "filled in according to the host platform."
            ),
            default = CARGO_BAZEL_URLS,
        ),
        "isolated": attr.bool(
            doc = (
                "If true, `CARGO_HOME` will be overwritten to a directory within the generated repository in " +
                "order to prevent other uses of Cargo from impacting having any effect on the generated targets " +
                "produced by this rule. For users who either have multiple `crate_repository` definitions in a " +
                "WORKSPACE or rapidly re-pin dependencies, setting this to false may improve build times. This " +
                "variable is also controled by `CARGO_BAZEL_ISOLATED` environment variable."
            ),
            default = True,
        ),
        "lockfile": attr.label(
            doc = (
                "The path to a file to use for reproducible renderings. Two kinds of lock files are supported, " +
                "Cargo (`Cargo.lock` files) and Bazel (custom files generated by this rule, naming is irrelevant). " +
                "Bazel lockfiles should be the prefered kind as they're desigend with Bazel's notions of " +
                "reporducibility in mind. Cargo lockfiles can be used in cases where it's intended to be the " +
                "source of truth, but more work will need to be done to generate BUILD files which are not " +
                "guaranteed to be determinsitic."
            ),
            mandatory = True,
        ),
        "lockfile_kind": attr.string(
            doc = (
                "Two different kinds of lockfiles are supported, the custom \"Bazel\" lockfile, which is generated " +
                "by this rule, and Cargo lockfiles (`Cargo.lock`). This attribute allows for explicitly defining " +
                "the type in cases where it may not be auto-detectable."
            ),
            values = [
                "auto",
                "bazel",
                "cargo",
            ],
            default = "auto",
        ),
        "manifests": attr.label_list(
            doc = "A list of Cargo manifests (`Cargo.toml` files).",
        ),
        "packages": attr.string_dict(
            doc = "A set of crates (packages) specifications to depend on. See [crate.spec](#crate.spec).",
        ),
        "quiet": attr.bool(
            doc = "If stdout and stderr should not be printed to the terminal.",
            default = True,
        ),
        "render_config": attr.string(
            doc = (
                "The configuration flags to use for rendering. Use `//crate_universe:defs.bzl\\%render_config` to " +
                "generate the value for this field. If unset, the defaults defined there will be used."
            ),
        ),
        "rust_toolchain_cargo_template": attr.string(
            doc = (
                "The template to use for finding the host `cargo` binary. `{version}` (eg. '1.53.0'), " +
                "`{triple}` (eg. 'x86_64-unknown-linux-gnu'), `{arch}` (eg. 'aarch64'), `{vendor}` (eg. 'unknown'), " +
                "`{system}` (eg. 'darwin'), `{cfg}` (eg. 'exec'), and `{tool}` (eg. 'rustc.exe') will be replaced in " +
                "the string if present."
            ),
            default = "@rust_{system}_{arch}//:bin/{tool}",
        ),
        "rust_toolchain_rustc_template": attr.string(
            doc = (
                "The template to use for finding the host `rustc` binary. `{version}` (eg. '1.53.0'), " +
                "`{triple}` (eg. 'x86_64-unknown-linux-gnu'), `{arch}` (eg. 'aarch64'), `{vendor}` (eg. 'unknown'), " +
                "`{system}` (eg. 'darwin'), `{cfg}` (eg. 'exec'), and `{tool}` (eg. 'cargo.exe') will be replaced in " +
                "the string if present."
            ),
            default = "@rust_{system}_{arch}//:bin/{tool}",
        ),
        "rust_version": attr.string(
            doc = "The version of Rust the currently registered toolchain is using. Eg. `1.56.0`, or `nightly-2021-09-08`",
            default = rust_common.default_version,
        ),
        "splicing_config": attr.string(
            doc = (
                "The configuration flags to use for splicing Cargo maniests. Use `//crate_universe:defs.bzl\\%rsplicing_config` to " +
                "generate the value for this field. If unset, the defaults defined there will be used."
            ),
        ),
        "supported_platform_triples": attr.string_list(
            doc = "A set of all platform triples to consider when generating dependencies.",
            default = SUPPORTED_PLATFORM_TRIPLES,
        ),
    },
    environ = CRATES_REPOSITORY_ENVIRON,
)
