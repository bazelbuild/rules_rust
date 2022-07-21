# buildifier: disable=module-docstring
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load(
    "//rust/platform:triple_mappings.bzl",
    "triple_to_constraint_set",
)
load("//rust/private:common.bzl", "rust_common")
load(
    "//rust/private:repository_utils.bzl",
    "BUILD_for_rust_analyzer_toolchain",
    "BUILD_for_rust_toolchain",
    "BUILD_for_toolchain",
    "DEFAULT_STATIC_RUST_URL_TEMPLATES",
    "check_version_valid",
    "load_cargo",
    "load_clippy",
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
        name = "platforms",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/platforms/releases/download/0.0.5/platforms-0.0.5.tar.gz",
            "https://github.com/bazelbuild/platforms/releases/download/0.0.5/platforms-0.0.5.tar.gz",
        ],
        sha256 = "379113459b0feaf6bfbb584a91874c065078aa673222846ac765f86661c27407",
    )
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
        sha256 = "5bbce1b2b9a3d4b03c0697687023ef5471578e76f994363c641c5f50ff0c7268",
        url = "https://github.com/bazelbuild/apple_support/releases/download/0.13.0/apple_support.0.13.0.tar.gz",
    )

    # process_wrapper needs a low-dependency way to process json.
    maybe(
        http_archive,
        name = "rules_rust_tinyjson",
        sha256 = "1a8304da9f9370f6a6f9020b7903b044aa9ce3470f300a1fba5bc77c78145a16",
        url = "https://crates.io/api/v1/crates/tinyjson/2.3.0/download",
        strip_prefix = "tinyjson-2.3.0",
        type = "tar.gz",
        build_file = "@rules_rust//util/process_wrapper:BUILD.tinyjson.bazel",
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
        edition (str, optional): The rust edition to be used by default (2015, 2018, or 2021). If absent, every target is required to specify its `edition` attribute.
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

    rust_analyzer_repo_name = "rust_analyzer_{}".format(version)
    if iso_date:
        rust_analyzer_repo_name = "{}-{}".format(
            rust_analyzer_repo_name,
            iso_date,
        )

    maybe(
        rust_analyzer_toolchain_repository,
        name = rust_analyzer_repo_name,
        version = version,
        urls = urls,
        sha256s = sha256s,
        iso_date = iso_date,
    )

    if register_toolchains:
        native.register_toolchains("@{}//:toolchain".format(
            rust_analyzer_repo_name,
        ))

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

def _rust_toolchain_tools_repository_impl(ctx):
    """The implementation of the rust toolchain tools repository rule."""

    check_version_valid(ctx.attr.version, ctx.attr.iso_date)

    # Conditionally download rustc sources. Generally used for `rust-analyzer`
    if should_include_rustc_srcs(ctx):
        load_rust_src(ctx)

    build_components = [
        load_rust_compiler(ctx),
        load_clippy(ctx),
        load_cargo(ctx),
    ]

    if ctx.attr.rustfmt_version:
        build_components.append(load_rustfmt(ctx))

    # Rust 1.45.0 and nightly builds after 2020-05-22 need the llvm-tools gzip to get the libLLVM dylib
    include_llvm_tools = ctx.attr.version >= "1.45.0" or (ctx.attr.version == "nightly" and ctx.attr.iso_date > "2020-05-22")
    if include_llvm_tools:
        build_components.append(load_llvm_tools(ctx, ctx.attr.exec_triple))

    build_components.append(load_rust_stdlib(ctx, ctx.attr.target_triple))

    stdlib_linkflags = None
    if "BAZEL_RUST_STDLIB_LINKFLAGS" in ctx.os.environ:
        stdlib_linkflags = ctx.os.environ["BAZEL_RUST_STDLIB_LINKFLAGS"].split(":")

    build_components.append(BUILD_for_rust_toolchain(
        name = "rust_toolchain",
        exec_triple = ctx.attr.exec_triple,
        include_rustc_srcs = should_include_rustc_srcs(ctx),
        target_triple = ctx.attr.target_triple,
        stdlib_linkflags = stdlib_linkflags,
        workspace_name = ctx.attr.name,
        default_edition = ctx.attr.edition,
        include_rustfmt = not (not ctx.attr.rustfmt_version),
        include_llvm_tools = include_llvm_tools,
    ))

    # Not all target triples are expected to have dev components
    if ctx.attr.dev_components:
        load_rustc_dev_nightly(ctx, ctx.attr.target_triple)

    ctx.file("WORKSPACE.bazel", "")
    ctx.file("BUILD.bazel", "\n".join(build_components))

rust_toolchain_tools_repository = repository_rule(
    doc = (
        "Composes a single workspace containing the toolchain components for compiling on a given " +
        "platform to a series of target platforms.\n" +
        "\n" +
        "A given instance of this rule should be accompanied by a toolchain_repository_proxy " +
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
            doc = (
                "The rust edition to be used by default (2015, 2018, or 2021). " +
                "If absent, every rule is required to specify its `edition` attribute."
            ),
        ),
        "exec_triple": attr.string(
            doc = "The Rust-style target that this compiler runs on",
            mandatory = True,
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
        "target_triple": attr.string(
            doc = "The Rust-style target that this compiler builds for",
            mandatory = True,
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
    implementation = _rust_toolchain_tools_repository_impl,
    environ = ["RULES_RUST_TOOLCHAIN_INCLUDE_RUSTC_SRCS"],
)

def _toolchain_repository_proxy_impl(repository_ctx):
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    repository_ctx.file("BUILD.bazel", BUILD_for_toolchain(
        name = "toolchain",
        toolchain = repository_ctx.attr.toolchain,
        toolchain_type = repository_ctx.attr.toolchain_type,
        target_compatible_with = json.encode(repository_ctx.attr.target_compatible_with),
        exec_compatible_with = json.encode(repository_ctx.attr.exec_compatible_with),
    ))

toolchain_repository_proxy = repository_rule(
    doc = (
        "Generates a toolchain-bearing repository that declares the toolchains from some other " +
        "rust_toolchain_repository."
    ),
    attrs = {
        "exec_compatible_with": attr.string_list(
            doc = "A list of constraints for the execution platform for this toolchain.",
        ),
        "target_compatible_with": attr.string_list(
            doc = "A list of constraints for the target platform for this toolchain.",
        ),
        "toolchain": attr.string(
            doc = "The name of the toolchain implementation target.",
            mandatory = True,
        ),
        "toolchain_type": attr.string(
            doc = "The toolchain type of the toolchain to declare",
            mandatory = True,
        ),
    },
    implementation = _toolchain_repository_proxy_impl,
)

# For legacy support
rust_toolchain_repository_proxy = toolchain_repository_proxy

def rust_toolchain_repository(
        name,
        version,
        exec_triple,
        target_triple,
        exec_compatible_with = None,
        target_compatible_with = None,
        include_rustc_srcs = False,
        iso_date = None,
        rustfmt_version = None,
        edition = None,
        dev_components = False,
        sha256s = None,
        urls = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        auth = None):
    """Assembles a remote repository for the given toolchain params, produces a proxy repository \
    to contain the toolchain declaration, and registers the toolchains.

    N.B. A "proxy repository" is needed to allow for registering the toolchain (with constraints) \
    without actually downloading the toolchain.

    Args:
        name (str): The name of the generated repository
        version (str): The version of the tool among "nightly", "beta', or an exact version.
        exec_triple (str): The Rust-style target that this compiler runs on.
        target_triple (str): The Rust-style target to build for.
        exec_compatible_with (list, optional): A list of constraints for the execution platform for this toolchain.
        target_compatible_with (list, optional): A list of constraints for the target platform for this toolchain.
        include_rustc_srcs (bool, optional): Whether to download rustc's src code. This is required in order to use rust-analyzer support.
        iso_date (str, optional): The date of the tool.
        rustfmt_version (str, optional):  The version of rustfmt to be associated with the
            toolchain.
        edition (str, optional): The rust edition to be used by default (2015, 2018, or 2021). If absent, every rule is required to specify its `edition` attribute.
        dev_components (bool, optional): Whether to download the rustc-dev components.
            Requires version to be "nightly". Defaults to False.
        sha256s (str, optional): A dict associating tool subdirectories to sha256 hashes. See
            [rust_repositories](#rust_repositories) for more details.
        urls (list, optional): A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format). Defaults to ['https://static.rust-lang.org/dist/{}.tar.gz']
        auth (dict): Auth object compatible with repository_ctx.download to use when downloading files.
            See [repository_ctx.download](https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download) for more details.

    Returns:
        str: The name of the registerable toolchain created by this rule.
    """

    if exec_compatible_with == None:
        exec_compatible_with = triple_to_constraint_set(exec_triple)

    if target_compatible_with == None:
        target_compatible_with = triple_to_constraint_set(target_triple)

    rust_toolchain_tools_repository(
        name = name + "_tools",
        exec_triple = exec_triple,
        include_rustc_srcs = include_rustc_srcs,
        target_triple = target_triple,
        iso_date = iso_date,
        version = version,
        rustfmt_version = rustfmt_version,
        edition = edition,
        dev_components = dev_components,
        sha256s = sha256s,
        urls = urls,
        auth = auth,
    )

    toolchain_repository_proxy(
        name = name,
        toolchain = "@{}//:{}".format(name + "_tools", "rust_toolchain"),
        toolchain_type = "@rules_rust//rust:toolchain",
        exec_compatible_with = exec_compatible_with,
        target_compatible_with = target_compatible_with,
    )

    return "@{name}//:toolchain".format(
        name = name,
    )

def _rust_analyzer_toolchain_srcs_repository_impl(repository_ctx):
    load_rust_src(repository_ctx)

    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    repository_ctx.file("BUILD.bazel", BUILD_for_rust_analyzer_toolchain(
        name = "rust_analyzer_toolchain",
    ))

rust_analyzer_toolchain_srcs_repository = repository_rule(
    doc = "A repository rule for defining a rust_analyzer_toolchain with a `rust-src` artifact.",
    attrs = {
        "auth": attr.string_dict(
            doc = (
                "Auth object compatible with repository_ctx.download to use when downloading files. " +
                "See [repository_ctx.download](https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download) for more details."
            ),
        ),
        "iso_date": attr.string(
            doc = "The date of the tool (or None, if the version is a specific version).",
        ),
        "sha256s": attr.string_dict(
            doc = "A dict associating tool subdirectories to sha256 hashes. See [rust_repositories](#rust_repositories) for more details.",
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
    implementation = _rust_analyzer_toolchain_srcs_repository_impl,
)

def rust_analyzer_toolchain_repository(
        name,
        version,
        exec_compatible_with = [],
        target_compatible_with = [],
        iso_date = None,
        sha256s = None,
        urls = None,
        auth = None):
    """Assemble a remote rust_analyzer_toolchain target based on the given params.

    Args:
        name (str): The name of the toolchain proxy repository contianing the registerable toolchain.
        version (str): The version of the tool among "nightly", "beta', or an exact version.
        exec_compatible_with (list, optional): A list of constraints for the execution platform for this toolchain.
        target_compatible_with (list, optional): A list of constraints for the target platform for this toolchain.
        iso_date (str, optional): The date of the tool.
        sha256s (str, optional): A dict associating tool subdirectories to sha256 hashes. See
            [rust_repositories](#rust_repositories) for more details.
        urls (list, optional): A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format). Defaults to ['https://static.rust-lang.org/dist/{}.tar.gz']
        auth (dict): Auth object compatible with repository_ctx.download to use when downloading files.
            See [repository_ctx.download](https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download) for more details.

    Returns:
        str: The name of a registerable rust_analyzer_toolchain.
    """
    rust_analyzer_toolchain_srcs_repository(
        name = name + "_srcs",
        version = version,
        iso_date = iso_date,
        sha256s = sha256s,
        urls = urls,
        auth = auth,
    )

    toolchain_repository_proxy(
        name = name,
        toolchain = "@{}//:{}".format(name + "_srcs", "rust_analyzer_toolchain"),
        toolchain_type = "@rules_rust//rust/rust_analyzer:toolchain_type",
        exec_compatible_with = exec_compatible_with,
        target_compatible_with = target_compatible_with,
    )

    return "@{}//:toolchain".format(
        name,
    )

def _rust_toolchain_set_repository_impl(repository_ctx):
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    repository_ctx.file("BUILD.bazel", """exports_files(["defs.bzl"])""")
    repository_ctx.file("defs.bzl", "ALL_TOOLCHAINS = {}\n".format(
        json.encode_indent(repository_ctx.attr.toolchains, indent = " " * 4),
    ))

rust_toolchain_set_repository = repository_rule(
    doc = (
        "Generates a toolchain-bearing repository that declares the toolchains from some other " +
        "rust_toolchain_repository."
    ),
    attrs = {
        "toolchains": attr.string_list(
            doc = "The list of all toolchains created by the current `rust_toolchain_set`",
            mandatory = True,
        ),
    },
    implementation = _rust_toolchain_set_repository_impl,
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
        edition (str, optional): The rust edition to be used by default (2015, 2018, or 2021). If absent, every rule is required to specify its `edition` attribute.
        dev_components (bool, optional): Whether to download the rustc-dev components.
            Requires version to be "nightly". Defaults to False.
        sha256s (str, optional): A dict associating tool subdirectories to sha256 hashes. See
            [rust_repositories](#rust_repositories) for more details.
        urls (list, optional): A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format). Defaults to ['https://static.rust-lang.org/dist/{}.tar.gz']
        auth (dict): Auth object compatible with repository_ctx.download to use when downloading files.
            See [repository_ctx.download](https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download) for more details.
        register_toolchain (bool): If True, the generated `rust_toolchain` target will become a registered toolchain.
    """

    all_toolchain_names = []
    for target_triple in [exec_triple] + extra_target_triples:
        toolchain_name = "{}__{}".format(name, target_triple)
        all_toolchain_names.append(rust_toolchain_repository(
            name = toolchain_name,
            exec_triple = exec_triple,
            include_rustc_srcs = include_rustc_srcs,
            target_triple = target_triple,
            iso_date = iso_date,
            version = version,
            rustfmt_version = rustfmt_version,
            edition = edition,
            dev_components = dev_components,
            sha256s = sha256s,
            urls = urls,
            auth = auth,
        ))

    # This repository exists to allow `rust_repository_set` to work with the `maybe` wrapper.
    rust_toolchain_set_repository(
        name = name,
        toolchains = all_toolchain_names,
    )

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
