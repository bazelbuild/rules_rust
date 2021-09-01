"""`rules_rust` uses a collection of repository rules to generate hermtic
toolchains for execution and target environments. A large set of commonly
used toolchains are defined simply by calling `rust_repositories` in your
WORKSPACE file but toolchains can be defined more granularly by using
`rust_repository_set` or any of the other underlying `rust_*_repository`
repository rules with `rust_exec_toolchain_repository` or
`rust_target_toolchain_repository`.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load(
    "//rust:toolchain_repositories.bzl",
    "rust_exec_toolchain_repository",
    "rust_target_toolchain_repository",
)
load(
    "//rust/platform:triple_mappings.bzl",
    "SUPPORTED_PLATFORM_TRIPLES",
)
load("//rust/private:common.bzl", "rust_common")
load(
    "//rust/private:repository_utils.bzl",
    "DEFAULT_STATIC_RUST_URL_TEMPLATES",
    "bazel_version_repository",
    _load_arbitrary_tool = "load_arbitrary_tool",
)

# Reexport to satisfy previsouly public API
load_arbitrary_tool = _load_arbitrary_tool

DEFAULT_TOOLCHAIN_TRIPLES = [
    "aarch64-apple-darwin",
    "aarch64-unknown-linux-gnu",
    "x86_64-apple-darwin",
    "x86_64-pc-windows-msvc",
    "x86_64-unknown-freebsd",
    "x86_64-unknown-linux-gnu",
]

# buildifier: disable=unnamed-macro
def rust_repositories(
        dev_components = False,
        edition = rust_common.default_edition,
        include_rustc_srcs = False,
        iso_date = None,
        prefix = "rules_rust",
        register_toolchains = True,
        rustfmt_version = None,
        sha256s = None,
        urls = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        version = rust_common.default_version):
    """Instantiate repositories and toolchains required by `rules_rust`.

    Skip this macro and call the [rust_exec_toolchain_repository](#rust_exec_toolchain_repository) or
    [rust_target_toolchain_repository](#rust_target_toolchain_repository) rules directly if you need a
    compiler for other hosts or for additional target triples.

    The `sha256` attribute represents a dict associating tool subdirectories to sha256 hashes. As an example:
    ```python
    {
        "rust-1.46.0-x86_64-unknown-linux-gnu": "e3b98bc3440fe92817881933f9564389eccb396f5f431f33d48b979fa2fbdcf5",
        "rustfmt-1.4.12-x86_64-unknown-linux-gnu": "1894e76913303d66bf40885a601462844eec15fca9e76a6d13c390d7000d64b0",
        "rust-std-1.46.0-x86_64-unknown-linux-gnu": "ac04aef80423f612c0079829b504902de27a6997214eb58ab0765d02f7ec1dbc",
    }
    ```

    Args:
        dev_components (bool, optional): Whether to download the rustc-dev components.
        edition (str, optional): The rust edition to be used by default (2015, 2018 (default), or 2021)
        include_rustc_srcs (bool, optional): Whether to download rustc's src code. This is required in order to use rust-analyzer
            support. See [rust_toolchain_repository.include_rustc_srcs](#rust_toolchain_repository-include_rustc_srcs).
            for more details
        iso_date (str, optional): The date of the nightly or beta release (or None, if the version is a specific version).
        prefix (str, optional): The prefix used for all generated repositories. Eg. `{prefix}_{repository}`.
        register_toolchains (bool, optional): Whether or not to register any toolchains. Setting this to false will
            allow for other repositories the rules depend on to get defined while allowing users to have full control
            over their toolchains
        rustfmt_version (str, optional): Same as `version` but is only used for `rustfmt`
        sha256s (str, optional): A dict associating tool subdirectories to sha256 hashes.
        urls (list, optional): A list of mirror urls containing the tools from the Rust-lang static file server. These must
            contain the '{}' used to substitute the tool being fetched (using .format).
        version (str, optional): The version of Rust. Either "nightly", "beta", or an exact version. Defaults to a modern version.
    """

    if dev_components and version != "nightly":
        fail("Rust version must be set to \"nightly\" to enable rustc-dev components")

    maybe(
        http_archive,
        name = "rules_cc",
        urls = ["https://github.com/bazelbuild/rules_cc/releases/download/0.0.1/rules_cc-0.0.1.tar.gz"],
        sha256 = "4dccbfd22c0def164c8f47458bd50e0c7148f3d92002cdb459c2a96a68498241",
    )

    maybe(
        http_archive,
        name = "bazel_skylib",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.1.1/bazel-skylib-1.1.1.tar.gz",
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.1.1/bazel-skylib-1.1.1.tar.gz",
        ],
        sha256 = "c6966ec828da198c5d9adbaa94c05e3a1c7f21bd012a0b29ba8ddbccb2c93b0d",
    )

    # Used to identify the version of Bazel
    bazel_version_repository(
        name = "rules_rust_bazel_version",
    )

    if register_toolchains:
        version_str = version if version not in ["nightly", "beta"] else "{}-{}".format(
            version,
            iso_date,
        )

        # Register all default exec triples
        for triple in DEFAULT_TOOLCHAIN_TRIPLES:
            maybe(
                rust_exec_toolchain_repository,
                name = "{}_{}_{}_exec".format(prefix, version_str, triple),
                dev_components = dev_components,
                edition = edition,
                include_rustc_srcs = include_rustc_srcs,
                iso_date = iso_date,
                rustfmt_iso_date = iso_date,
                sha256s = sha256s,
                triple = triple,
                urls = urls,
                version = version,
            )

        # Register all target triples
        for triple in SUPPORTED_PLATFORM_TRIPLES:
            maybe(
                rust_target_toolchain_repository,
                name = "{}_{}_{}_target".format(prefix, version_str, triple),
                allocator_library = None,
                iso_date = iso_date,
                sha256s = sha256s,
                triple = triple,
                urls = urls,
                version = version,
            )

        if native.bazel_version >= "4.1.0":
            native.register_toolchains(str(Label("//rust/toolchain:current_rust_toolchain")))

        # Register a fake cc_toolchain for use in wasm_bindgen to allow for the config transition
        # to the wasm target platform.
        native.register_toolchains(str(Label("//rust/private/dummy_cc_toolchain:dummy_cc_wasm32_toolchain")))

def rust_repository_set(
        name,
        version,
        exec_triple,
        include_rustc_srcs = False,
        extra_target_triples = [],
        iso_date = None,
        rustfmt_version = None,
        edition = None,
        dev_components = False,
        sha256s = None,
        urls = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        auth = None):
    """A convenience macro for defining an exec toolchain and a collection of extra target toolchains.

    For more information see on what specifically is generated by this macro, see the
    [rust_exec_toolchain_repository](#rust_exec_toolchain_repository) and
    [rust_target_toolchain_repository](#rust_target_toolchain_repository) rules.

    Args:
        name (str): The name of the generated repository
        version (str): The version of the tool among "nightly", "beta', or an exact version.
        exec_triple (str): The Rust-style target that this compiler runs on
        include_rustc_srcs (bool, optional): Whether to download rustc's src code. This is required in order to
            use rust-analyzer support. Defaults to False.
        extra_target_triples (list, optional): Additional rust-style targets that this set of
            toolchains should support. Defaults to [].
        iso_date (str, optional): The date of the tool. Defaults to None.
        rustfmt_version (str, optional):  The version of rustfmt to be associated with the
            toolchain. Defaults to None.
        edition (str, optional): The rust edition to be used by default (2015, 2018 (if None), or 2021).
        dev_components (bool, optional): Whether to download the rustc-dev components.
            Requires version to be "nightly". Defaults to False.
        sha256s (str, optional): A dict associating tool subdirectories to sha256 hashes. See
            [rust_repositories](#rust_repositories) for more details.
        urls (list, optional): A list of mirror urls containing the tools from the Rust-lang static file server.
            These must contain the '{}' used to substitute the tool being fetched (using .format).
        auth (dict): Auth object compatible with repository_ctx.download to use when downloading files.
            See https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download for more details.
    """

    rust_exec_toolchain_repository(
        name = name,
        dev_components = dev_components,
        edition = edition,
        include_rustc_srcs = include_rustc_srcs,
        iso_date = iso_date,
        rustfmt_iso_date = iso_date,
        sha256s = sha256s,
        triple = exec_triple,
        urls = urls,
        version = version,
        auth = auth,
    )

    # Register all target triples
    for triple in [exec_triple] + extra_target_triples:
        rust_target_toolchain_repository(
            name = "{}_{}_target".format(name, triple),
            allocator_library = None,
            iso_date = iso_date,
            sha256s = sha256s,
            triple = triple,
            urls = urls,
            version = version,
            auth = auth,
        )
