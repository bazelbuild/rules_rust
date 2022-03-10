# buildifier: disable=module-docstring
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//rust/private:common.bzl", "rust_common")
load(
    "//rust/private:repository_utils.bzl",
    "BUILD_for_toolchain",
    "DEFAULT_STATIC_RUST_URL_TEMPLATES",
    "DEFAULT_TOOLCHAIN_NAME_PREFIX",
    "check_version_valid",
    "load_llvm_tools",
    "load_rust_compiler",
    "load_rust_src",
    "load_rust_stdlib",
    "load_rustc_dev_nightly",
    "load_rustfmt",
    "should_include_rustc_srcs",
    _load_arbitrary_tool = "load_arbitrary_tool",
)

# Reexport `load_arbitrary_tool` as it's currently in use in https://github.com/google/cargo-raze
load_arbitrary_tool = _load_arbitrary_tool

# Note: Code in `.github/workflows/crate_universe.yaml` looks for this line, if you remove it or change its format, you will also need to update that code.
DEFAULT_TOOLCHAIN_TRIPLES = {
    "aarch64-apple-darwin": "rust_darwin_aarch64",
    "aarch64-unknown-linux-gnu": "rust_linux_aarch64",
    "x86_64-apple-darwin": "rust_darwin_x86_64",
    "x86_64-pc-windows-msvc": "rust_windows_x86_64",
    "x86_64-unknown-freebsd": "rust_freebsd_x86_64",
    "x86_64-unknown-linux-gnu": "rust_linux_x86_64",
}

def rules_rust_dependencies():
    """Dependencies used in the implementation of `rules_rust`."""
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
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.2.0/bazel-skylib-1.2.0.tar.gz",
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.2.0/bazel-skylib-1.2.0.tar.gz",
        ],
        sha256 = "af87959afe497dc8dfd4c6cb66e1279cb98ccc84284619ebfec27d9c09a903de",
    )

    # Make the iOS simulator constraint available, which is referenced in abi_to_constraints()
    # rules_rust does not require this dependency; it is just imported as a convenience for users.
    maybe(
        http_archive,
        name = "build_bazel_apple_support",
        sha256 = "76df040ade90836ff5543888d64616e7ba6c3a7b33b916aa3a4b68f342d1b447",
        url = "https://github.com/bazelbuild/apple_support/releases/download/0.11.0/apple_support.0.11.0.tar.gz",
    )

# buildifier: disable=unnamed-macro
def rust_register_toolchains(
        dev_components = False,
        edition = None,
        include_rustc_srcs = False,
        iso_date = None,
        register_toolchains = True,
        rustfmt_version = None,
        sha256s = None,
        extra_target_triples = ["wasm32-unknown-unknown", "wasm32-wasi"],
        urls = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        version = rust_common.default_version):
    """Emits a default set of toolchains for Linux, MacOS, and Freebsd

    Skip this macro and call the `rust_repository_set` macros directly if you need a compiler for \
    other hosts or for additional target triples.

    The `sha256` attribute represents a dict associating tool subdirectories to sha256 hashes. As an example:
    ```python
    {
        "rust-1.46.0-x86_64-unknown-linux-gnu": "e3b98bc3440fe92817881933f9564389eccb396f5f431f33d48b979fa2fbdcf5",
        "rustfmt-1.4.12-x86_64-unknown-linux-gnu": "1894e76913303d66bf40885a601462844eec15fca9e76a6d13c390d7000d64b0",
        "rust-std-1.46.0-x86_64-unknown-linux-gnu": "ac04aef80423f612c0079829b504902de27a6997214eb58ab0765d02f7ec1dbc",
    }
    ```
    This would match for `exec_triple = "x86_64-unknown-linux-gnu"`.  If not specified, rules_rust pulls from a non-exhaustive \
    list of known checksums..

    See `load_arbitrary_tool` in `@rules_rust//rust:repositories.bzl` for more details.

    Args:
        dev_components (bool, optional): Whether to download the rustc-dev components (defaults to False). Requires version to be "nightly".
        edition (str, optional): The rust edition to be used by default (2015, 2018 (default), or 2021)
        include_rustc_srcs (bool, optional): Whether to download rustc's src code. This is required in order to use rust-analyzer support.
            See [rust_toolchain_repository.include_rustc_srcs](#rust_toolchain_repository-include_rustc_srcs). for more details
        iso_date (str, optional): The date of the nightly or beta release (ignored if the version is a specific version).
        register_toolchains (bool): If true, repositories will be generated to produce and register `rust_toolchain` targets.
        rustfmt_version (str, optional): The version of rustfmt. Either "nightly", "beta", or an exact version. Defaults to `version` if not specified.
        sha256s (str, optional): A dict associating tool subdirectories to sha256 hashes.
        extra_target_triples (list, optional): Additional rust-style targets that rust toolchains should support.
        urls (list, optional): A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format).
        version (str, optional): The version of Rust. Either "nightly", "beta", or an exact version. Defaults to a modern version.
    """
    if dev_components and version != "nightly":
        fail("Rust version must be set to \"nightly\" to enable rustc-dev components")

    if not rustfmt_version:
        rustfmt_version = version

    for exec_triple, name in DEFAULT_TOOLCHAIN_TRIPLES.items():
        maybe(
            rust_repository_set,
            name = name,
            dev_components = dev_components,
            edition = edition,
            exec_triple = exec_triple,
            extra_target_triples = extra_target_triples,
            include_rustc_srcs = include_rustc_srcs,
            iso_date = iso_date,
            register_toolchain = register_toolchains,
            rustfmt_version = rustfmt_version,
            sha256s = sha256s,
            urls = urls,
            version = version,
        )

# buildifier: disable=unnamed-macro
def rust_repositories(**kwargs):
    """**Deprecated**: Use [rules_rust_dependencies](#rules_rust_dependencies) \
    and [rust_register_toolchains](#rust_register_toolchains) directly.

    Args:
        **kwargs (dict): Keyword arguments for the `rust_register_toolchains` macro.
    """
    rules_rust_dependencies()

    rust_register_toolchains(**kwargs)

def _rust_toolchain_repository_impl(ctx):
    """The implementation of the rust toolchain repository rule."""

    check_version_valid(ctx.attr.version, ctx.attr.iso_date)

    # Conditionally download rustc sources. Generally used for `rust-analyzer`
    if should_include_rustc_srcs(ctx):
        load_rust_src(ctx)

    build_components = [load_rust_compiler(ctx)]

    if ctx.attr.rustfmt_version:
        build_components.append(load_rustfmt(ctx))

    # Rust 1.45.0 and nightly builds after 2020-05-22 need the llvm-tools gzip to get the libLLVM dylib
    if ctx.attr.version >= "1.45.0" or (ctx.attr.version == "nightly" and ctx.attr.iso_date > "2020-05-22"):
        load_llvm_tools(ctx, ctx.attr.exec_triple)

    for target_triple in [ctx.attr.exec_triple] + ctx.attr.extra_target_triples:
        build_components.append(load_rust_stdlib(ctx, target_triple))

        # extra_target_triples contains targets such as wasm, which don't have rustc_dev components
        if ctx.attr.dev_components and target_triple not in ctx.attr.extra_target_triples:
            load_rustc_dev_nightly(ctx, target_triple)

    ctx.file("WORKSPACE.bazel", "")
    ctx.file("BUILD.bazel", "\n".join(build_components))

def _rust_toolchain_repository_proxy_impl(ctx):
    build_components = []
    for target_triple in [ctx.attr.exec_triple] + ctx.attr.extra_target_triples:
        build_components.append(BUILD_for_toolchain(
            name = "{toolchain_prefix}_{target_triple}".format(
                toolchain_prefix = ctx.attr.toolchain_name_prefix,
                target_triple = target_triple,
            ),
            exec_triple = ctx.attr.exec_triple,
            parent_workspace_name = ctx.attr.parent_workspace_name,
            target_triple = target_triple,
        ))

    ctx.file("WORKSPACE.bazel", "")
    ctx.file("BUILD.bazel", "\n".join(build_components))

rust_toolchain_repository = repository_rule(
    doc = (
        "Composes a single workspace containing the toolchain components for compiling on a given " +
        "platform to a series of target platforms.\n" +
        "\n" +
        "A given instance of this rule should be accompanied by a rust_toolchain_repository_proxy " +
        "invocation to declare its toolchains to Bazel; the indirection allows separating toolchain " +
        "selection from toolchain fetching."
    ),
    attrs = {
        "auth": attr.string_dict(
            doc = (
                "Auth object compatible with repository_ctx.download to use when downloading files. " +
                "See [repository_ctx.download](https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download) for more details."
            ),
        ),
        "dev_components": attr.bool(
            doc = "Whether to download the rustc-dev components (defaults to False). Requires version to be \"nightly\".",
            default = False,
        ),
        "edition": attr.string(
            doc = "The rust edition to be used by default.",
            default = rust_common.default_edition,
        ),
        "exec_triple": attr.string(
            doc = "The Rust-style target that this compiler runs on",
            mandatory = True,
        ),
        "extra_target_triples": attr.string_list(
            doc = "Additional rust-style targets that this set of toolchains should support.",
        ),
        "include_rustc_srcs": attr.bool(
            doc = (
                "Whether to download and unpack the rustc source files. These are very large, and " +
                "slow to unpack, but are required to support rust analyzer. An environment variable " +
                "`RULES_RUST_TOOLCHAIN_INCLUDE_RUSTC_SRCS` can also be used to control this attribute. " +
                "This variable will take precedence over the hard coded attribute. Setting it to `true` to " +
                "activates this attribute where all other values deactivate it."
            ),
            default = False,
        ),
        "iso_date": attr.string(
            doc = "The date of the tool (or None, if the version is a specific version).",
        ),
        "rustfmt_version": attr.string(
            doc = "The version of the tool among \"nightly\", \"beta\", or an exact version.",
        ),
        "sha256s": attr.string_dict(
            doc = "A dict associating tool subdirectories to sha256 hashes. See [rust_repositories](#rust_repositories) for more details.",
        ),
        "toolchain_name_prefix": attr.string(
            doc = "The per-target prefix expected for the rust_toolchain declarations in the parent workspace.",
        ),
        "urls": attr.string_list(
            doc = "A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format).",
            default = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        ),
        "version": attr.string(
            doc = "The version of the tool among \"nightly\", \"beta\", or an exact version.",
            mandatory = True,
        ),
    },
    implementation = _rust_toolchain_repository_impl,
    environ = ["RULES_RUST_TOOLCHAIN_INCLUDE_RUSTC_SRCS"],
)

rust_toolchain_repository_proxy = repository_rule(
    doc = (
        "Generates a toolchain-bearing repository that declares the toolchains from some other " +
        "rust_toolchain_repository."
    ),
    attrs = {
        "exec_triple": attr.string(
            doc = "The Rust-style target triple for the compilation platform",
            mandatory = True,
        ),
        "extra_target_triples": attr.string_list(
            doc = "The Rust-style triples for extra compilation targets",
        ),
        "parent_workspace_name": attr.string(
            doc = "The name of the other rust_toolchain_repository",
            mandatory = True,
        ),
        "toolchain_name_prefix": attr.string(
            doc = "The per-target prefix expected for the rust_toolchain declarations in the parent workspace.",
        ),
    },
    implementation = _rust_toolchain_repository_proxy_impl,
)

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
        auth = None,
        register_toolchain = True):
    """Assembles a remote repository for the given toolchain params, produces a proxy repository \
    to contain the toolchain declaration, and registers the toolchains.

    N.B. A "proxy repository" is needed to allow for registering the toolchain (with constraints) \
    without actually downloading the toolchain.

    Args:
        name (str): The name of the generated repository
        version (str): The version of the tool among "nightly", "beta', or an exact version.
        exec_triple (str): The Rust-style target that this compiler runs on
        include_rustc_srcs (bool, optional): Whether to download rustc's src code. This is required in order to use rust-analyzer support. Defaults to False.
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
        urls (list, optional): A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format). Defaults to ['https://static.rust-lang.org/dist/{}.tar.gz']
        auth (dict): Auth object compatible with repository_ctx.download to use when downloading files.
            See [repository_ctx.download](https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download) for more details.
        register_toolchain (bool): If True, the generated `rust_toolchain` target will become a registered toolchain.
    """

    rust_toolchain_repository(
        name = name,
        exec_triple = exec_triple,
        include_rustc_srcs = include_rustc_srcs,
        extra_target_triples = extra_target_triples,
        iso_date = iso_date,
        toolchain_name_prefix = DEFAULT_TOOLCHAIN_NAME_PREFIX,
        version = version,
        rustfmt_version = rustfmt_version,
        edition = edition,
        dev_components = dev_components,
        sha256s = sha256s,
        urls = urls,
        auth = auth,
    )

    rust_toolchain_repository_proxy(
        name = name + "_toolchains",
        exec_triple = exec_triple,
        extra_target_triples = extra_target_triples,
        parent_workspace_name = name,
        toolchain_name_prefix = DEFAULT_TOOLCHAIN_NAME_PREFIX,
    )

    all_toolchain_names = []
    for target_triple in [exec_triple] + extra_target_triples:
        all_toolchain_names.append("@{name}_toolchains//:{toolchain_name_prefix}_{triple}".format(
            name = name,
            toolchain_name_prefix = DEFAULT_TOOLCHAIN_NAME_PREFIX,
            triple = target_triple,
        ))

    # Register toolchains
    if register_toolchain:
        native.register_toolchains(*all_toolchain_names)
        native.register_toolchains(str(Label("//rust/private/dummy_cc_toolchain:dummy_cc_wasm32_toolchain")))

    # Inform users that they should be using the canonical name if it's not detected
    if "rules_rust" not in native.existing_rules():
        message = "\n" + ("=" * 79) + "\n"
        message += (
            "It appears that you are trying to import rules_rust without using its\n" +
            "canonical name, \"@rules_rust\" Please change your WORKSPACE file to\n" +
            "import this repo with `name = \"rules_rust\"` instead."
        )

        if "io_bazel_rules_rust" in native.existing_rules():
            message += "\n\n" + (
                "Note that the previous name of \"@io_bazel_rules_rust\" is deprecated.\n" +
                "See https://github.com/bazelbuild/rules_rust/issues/499 for context."
            )

        message += "\n" + ("=" * 79)
        fail(message)
