"""Repository rules for defining Rust dependencies and toolchains"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//rust/platform:triple.bzl", "get_host_triple", "triple")
load("//rust/platform:triple_mappings.bzl", "triple_to_constraint_set")
load("//rust/private:common.bzl", "DEFAULT_NIGHTLY_ISO_DATE", "rust_common")
load(
    "//rust/private:repository_utils.bzl",
    "BUILD_for_rust_analyzer_proc_macro_srv",
    "BUILD_for_rust_analyzer_toolchain",
    "BUILD_for_rust_toolchain",
    "BUILD_for_rustfmt_toolchain",
    "BUILD_for_toolchain",
    "DEFAULT_EXTRA_TARGET_TRIPLES",
    "DEFAULT_NIGHTLY_VERSION",
    "DEFAULT_STATIC_RUST_URL_TEMPLATES",
    "TINYJSON_KWARGS",
    "check_version_valid",
    "includes_rust_analyzer_proc_macro_srv",
    "load_cargo",
    "load_clippy",
    "load_llvm_tools",
    "load_rust_compiler",
    "load_rust_src",
    "load_rust_stdlib",
    "load_rustc_dev_nightly",
    "load_rustfmt",
    "select_rust_version",
    "toolchain_repository_hub",
    _load_arbitrary_tool = "load_arbitrary_tool",
)

# Reexport `load_arbitrary_tool` as it's currently in use in https://github.com/google/cargo-raze
load_arbitrary_tool = _load_arbitrary_tool

# Note: Code in `.github/workflows/crate_universe.yaml` looks for this line, if you remove it or change its format, you will also need to update that code.
DEFAULT_TOOLCHAIN_TRIPLES = {
    "aarch64-apple-darwin": "rust_darwin_aarch64",
    "aarch64-pc-windows-msvc": "rust_windows_aarch64",
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
            "https://mirror.bazel.build/github.com/bazelbuild/platforms/releases/download/0.0.7/platforms-0.0.7.tar.gz",
            "https://github.com/bazelbuild/platforms/releases/download/0.0.7/platforms-0.0.7.tar.gz",
        ],
        sha256 = "3a561c99e7bdbe9173aa653fd579fe849f1d8d67395780ab4770b1f381431d51",
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
        sha256 = "66ffd9315665bfaafc96b52278f57c7e2dd09f5ede279ea6d39b2be471e7e3aa",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.4.2/bazel-skylib-1.4.2.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.4.2/bazel-skylib-1.4.2.tar.gz",
        ],
    )

    # Make the iOS simulator constraint available, which is referenced in abi_to_constraints()
    # rules_rust does not require this dependency; it is just imported as a convenience for users.
    maybe(
        http_archive,
        name = "build_bazel_apple_support",
        sha256 = "45d6bbad5316c9c300878bf7fffc4ffde13d620484c9184708c917e20b8b63ff",
        url = "https://github.com/bazelbuild/apple_support/releases/download/1.8.1/apple_support.1.8.1.tar.gz",
    )

    # process_wrapper needs a low-dependency way to process json.
    maybe(
        http_archive,
        **TINYJSON_KWARGS
    )

_RUST_TOOLCHAIN_VERSIONS = [
    rust_common.default_version,
    DEFAULT_NIGHTLY_VERSION,
]

# buildifier: disable=unnamed-macro
def rust_register_toolchains(
        dev_components = False,
        edition = None,
        allocator_library = None,
        global_allocator_library = None,
        iso_date = None,
        register_toolchains = True,
        rustfmt_version = DEFAULT_NIGHTLY_VERSION,
        rust_analyzer_version = None,
        sha256s = None,
        extra_target_triples = DEFAULT_EXTRA_TARGET_TRIPLES,
        extra_rustc_flags = None,
        extra_exec_rustc_flags = None,
        urls = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        version = None,
        versions = []):
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
        allocator_library (str, optional): Target that provides allocator functions when rust_library targets are embedded in a cc_binary.
        global_allocator_library (str, optional): Target that provides allocator functions when global allocator is used with cc_common.link.
        iso_date (str, optional):  **Deprecated**: Use `versions` instead.
        register_toolchains (bool): If true, repositories will be generated to produce and register `rust_toolchain` targets.
        rustfmt_version (str, optional): The version of rustfmt.
        rust_analyzer_version (str, optional): The version of Rustc to pair with rust-analyzer.
        sha256s (str, optional): A dict associating tool subdirectories to sha256 hashes.
        extra_target_triples (list, optional): Additional rust-style targets that rust toolchains should support.
        extra_rustc_flags (dict, list, optional): Dictionary of target triples to list of extra flags to pass to rustc in non-exec configuration.
        extra_exec_rustc_flags (list, optional): Extra flags to pass to rustc in exec configuration.
        urls (list, optional): A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format).
        version (str, optional): **Deprecated**: Use `versions` instead.
        versions (list, optional): A list of toolchain versions to download. This paramter only accepts one versions
            per channel. E.g. `["1.65.0", "nightly/2022-11-02", "beta/2020-12-30"]`.
    """
    if version:
        # buildifier: disable=print
        print("`rust_register.toolchains.version` is deprecated. Please use `versions` instead: https://bazelbuild.github.io/rules_rust/flatten.html#rust_register_toolchains-versions")

    if iso_date:
        # buildifier: disable=print
        print("`rust_register.toolchains.iso_date` is deprecated. Please use `versions` instead: https://bazelbuild.github.io/rules_rust/flatten.html#rust_register_toolchains-versions")

    if rustfmt_version in ("nightly", "beta"):
        # buildifier: disable=print
        print("`rust_register.toolchains.rustfmt_version` now requires iso date to be included in the string. E.g. `nightly/2022-12-15`. This version will be assumed until this value is updated")
        rustfmt_version = "{}/{}".format(rustfmt_version, DEFAULT_NIGHTLY_ISO_DATE)

    if not versions:
        if version:
            versions = [version]
        else:
            versions = _RUST_TOOLCHAIN_VERSIONS

    if dev_components:
        has_nightly = False
        for ver in versions:
            if ver.startswith("nightly"):
                has_nightly = True
                break
        if not has_nightly:
            fail("rustc-dev components were requested but no \"nightly\" is being registered. Please update `versions` to include a nightly version.")

    if not rust_analyzer_version:
        rust_analyzer_version = select_rust_version(versions)

    rust_analyzer_repo_name = "rust_analyzer_{}".format(rust_analyzer_version.replace("/", "-"))
    rust_analyzer_iso_date = None
    if rust_analyzer_version.startswith(("beta", "nightly")):
        rust_analyzer_version, _, rust_analyzer_iso_date = rustfmt_version.partition("/")

    toolchain_names = []
    toolchain_labels = {}
    toolchain_types = {}
    exec_compatible_with_by_toolchain = {}
    target_compatible_with_by_toolchain = {}

    maybe(
        rust_analyzer_toolchain_repository,
        name = rust_analyzer_repo_name,
        version = rust_analyzer_version,
        urls = urls,
        sha256s = sha256s,
        iso_date = rust_analyzer_iso_date,
    )

    toolchain_names.append(rust_analyzer_repo_name)
    toolchain_labels[rust_analyzer_repo_name] = "@{}_srcs//:rust_analyzer_toolchain".format(
        rust_analyzer_repo_name,
    )
    exec_compatible_with_by_toolchain[rust_analyzer_repo_name] = []
    target_compatible_with_by_toolchain[rust_analyzer_repo_name] = []
    toolchain_types[rust_analyzer_repo_name] = "@rules_rust//rust/rust_analyzer:toolchain_type"

    if register_toolchains:
        native.register_toolchains("@{}//:toolchain".format(
            rust_analyzer_repo_name,
        ))

    rustfmt_iso_date = None
    rustfmt_version_or_channel = rustfmt_version
    if rustfmt_version.startswith(("beta", "nightly")):
        rustfmt_version_or_channel, _, rustfmt_iso_date = rustfmt_version.partition("/")

    for exec_triple, name in DEFAULT_TOOLCHAIN_TRIPLES.items():
        maybe(
            rust_repository_set,
            name = name,
            dev_components = dev_components,
            edition = edition,
            exec_triple = exec_triple,
            extra_target_triples = extra_target_triples,
            allocator_library = allocator_library,
            global_allocator_library = global_allocator_library,
            iso_date = iso_date,
            register_toolchain = register_toolchains,
            rustfmt_version = rustfmt_version,
            extra_rustc_flags = extra_rustc_flags,
            extra_exec_rustc_flags = extra_exec_rustc_flags,
            sha256s = sha256s,
            urls = urls,
            version = version,
            versions = versions,
        )

        rustfmt_repo_name = "rustfmt_{}__{}".format(rustfmt_version.replace("/", "-"), exec_triple)

        maybe(
            rustfmt_toolchain_repository,
            name = rustfmt_repo_name,
            version = rustfmt_version_or_channel,
            urls = urls,
            sha256s = sha256s,
            iso_date = rustfmt_iso_date,
            exec_triple = exec_triple,
        )

        if register_toolchains:
            native.register_toolchains("@{}//:toolchain".format(
                rustfmt_repo_name,
            ))

        for toolchain in _get_toolchain_repositories(name, exec_triple, extra_target_triples, versions, iso_date):
            toolchain_names.append(toolchain.name)
            toolchain_labels[toolchain.name] = "@{}//:{}".format(toolchain.name + "_tools", "rust_toolchain")
            exec_compatible_with_by_toolchain[toolchain.name] = triple_to_constraint_set(exec_triple)
            target_compatible_with_by_toolchain[toolchain.name] = triple_to_constraint_set(toolchain.target_triple)
            toolchain_types[toolchain.name] = "@rules_rust//rust:toolchain"

    toolchain_repository_hub(
        name = "rust_toolchains",
        toolchain_names = toolchain_names,
        toolchain_labels = toolchain_labels,
        toolchain_types = toolchain_types,
        exec_compatible_with = exec_compatible_with_by_toolchain,
        target_compatible_with = target_compatible_with_by_toolchain,
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

    exec_triple = triple(ctx.attr.exec_triple)

    build_components = [
        load_rust_compiler(
            ctx = ctx,
            iso_date = ctx.attr.iso_date,
            target_triple = exec_triple,
            version = ctx.attr.version,
        ),
        load_clippy(
            ctx = ctx,
            iso_date = ctx.attr.iso_date,
            target_triple = exec_triple,
            version = ctx.attr.version,
        ),
        load_cargo(
            ctx = ctx,
            iso_date = ctx.attr.iso_date,
            target_triple = exec_triple,
            version = ctx.attr.version,
        ),
    ]

    if ctx.attr.rustfmt_version:
        rustfmt_version = ctx.attr.rustfmt_version
        rustfmt_iso_date = None
        if rustfmt_version in ("nightly", "beta"):
            if ctx.attr.iso_date:
                rustfmt_iso_date = ctx.attr.iso_date
            else:
                fail("`rustfmt_version` does not include an iso_date. The following reposiotry should either set `iso_date` or update `rustfmt_version` to include an iso_date suffix: {}".format(
                    ctx.name,
                ))
        elif rustfmt_version.startswith(("nightly", "beta")):
            rustfmt_version, _, rustfmt_iso_date = rustfmt_version.partition("/")
        build_components.append(load_rustfmt(
            ctx = ctx,
            target_triple = triple(ctx.attr.exec_triple),
            version = rustfmt_version,
            iso_date = rustfmt_iso_date,
        ))

    # Rust 1.45.0 and nightly builds after 2020-05-22 need the llvm-tools gzip to get the libLLVM dylib
    include_llvm_tools = ctx.attr.version >= "1.45.0" or (ctx.attr.version == "nightly" and ctx.attr.iso_date > "2020-05-22")
    if include_llvm_tools:
        build_components.append(load_llvm_tools(
            ctx = ctx,
            target_triple = exec_triple,
        ))

    target_triple = triple(ctx.attr.target_triple)
    build_components.append(load_rust_stdlib(
        ctx = ctx,
        target_triple = target_triple,
    ))

    stdlib_linkflags = None
    if "BAZEL_RUST_STDLIB_LINKFLAGS" in ctx.os.environ:
        stdlib_linkflags = ctx.os.environ["BAZEL_RUST_STDLIB_LINKFLAGS"].split(":")

    build_components.append(BUILD_for_rust_toolchain(
        name = "rust_toolchain",
        exec_triple = exec_triple,
        allocator_library = ctx.attr.allocator_library,
        global_allocator_library = ctx.attr.global_allocator_library,
        target_triple = target_triple,
        stdlib_linkflags = stdlib_linkflags,
        default_edition = ctx.attr.edition,
        include_rustfmt = not (not ctx.attr.rustfmt_version),
        include_llvm_tools = include_llvm_tools,
        extra_rustc_flags = ctx.attr.extra_rustc_flags,
        extra_exec_rustc_flags = ctx.attr.extra_exec_rustc_flags,
        opt_level = ctx.attr.opt_level if ctx.attr.opt_level else None,
    ))

    # Not all target triples are expected to have dev components
    if ctx.attr.dev_components:
        load_rustc_dev_nightly(ctx, target_triple)

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
        "allocator_library": attr.string(
            doc = "Target that provides allocator functions when rust_library targets are embedded in a cc_binary.",
        ),
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
        "extra_exec_rustc_flags": attr.string_list(
            doc = "Extra flags to pass to rustc in exec configuration",
        ),
        "extra_rustc_flags": attr.string_list(
            doc = "Extra flags to pass to rustc in non-exec configuration",
        ),
        "global_allocator_library": attr.string(
            doc = "Target that provides allocator functions when a global allocator is used with cc_common.link.",
        ),
        "iso_date": attr.string(
            doc = "The date of the tool (or None, if the version is a specific version).",
        ),
        "opt_level": attr.string_dict(
            doc = "Rustc optimization levels. For more details see the documentation for `rust_toolchain.opt_level`.",
        ),
        "rustfmt_version": attr.string(
            doc = "The version of the tool among \"nightly\", \"beta\", or an exact version.",
        ),
        "sha256s": attr.string_dict(
            doc = "A dict associating tool subdirectories to sha256 hashes. See [rust_repositories](#rust_repositories) for more details.",
        ),
        "target_triple": attr.string(
            doc = "The Rust-style target that this compiler builds for.",
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
)

def _toolchain_repository_proxy_impl(repository_ctx):
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    repository_ctx.file("BUILD.bazel", BUILD_for_toolchain(
        name = "toolchain",
        toolchain = repository_ctx.attr.toolchain,
        target_settings = repository_ctx.attr.target_settings,
        toolchain_type = repository_ctx.attr.toolchain_type,
        target_compatible_with = repository_ctx.attr.target_compatible_with,
        exec_compatible_with = repository_ctx.attr.exec_compatible_with,
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
        "target_settings": attr.string_list(
            doc = "A list of config_settings that must be satisfied by the target configuration in order for this toolchain to be selected during toolchain resolution.",
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

# N.B. A "proxy repository" is needed to allow for registering the toolchain (with constraints)
# without actually downloading the toolchain.
def rust_toolchain_repository(
        name,
        version,
        exec_triple,
        target_triple,
        exec_compatible_with = None,
        target_compatible_with = None,
        target_settings = [],
        channel = None,
        allocator_library = None,
        global_allocator_library = None,
        iso_date = None,
        rustfmt_version = None,
        edition = None,
        dev_components = False,
        extra_rustc_flags = None,
        extra_exec_rustc_flags = None,
        opt_level = None,
        sha256s = None,
        urls = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        auth = None):
    """Assembles a remote repository for the given toolchain params, produces a proxy repository \
    to contain the toolchain declaration, and registers the toolchains.

    Args:
        name (str): The name of the generated repository
        version (str): The version of the tool among "nightly", "beta", or an exact version.
        exec_triple (str): The Rust-style target that this compiler runs on.
        target_triple (str): The Rust-style target to build for.
        channel (str, optional): The channel of the Rust toolchain.
        exec_compatible_with (list, optional): A list of constraints for the execution platform for this toolchain.
        target_compatible_with (list, optional): A list of constraints for the target platform for this toolchain.
        target_settings (list, optional): A list of config_settings that must be satisfied by the target configuration in order for this toolchain to be selected during toolchain resolution.
        allocator_library (str, optional): Target that provides allocator functions when rust_library targets are embedded in a cc_binary.
        global_allocator_library (str, optional): Target that provides allocator functions when a global allocator is used with cc_common.link.
        iso_date (str, optional): The date of the tool.
        rustfmt_version (str, optional):  The version of rustfmt to be associated with the
            toolchain.
        edition (str, optional): The rust edition to be used by default (2015, 2018, or 2021). If absent, every rule is required to specify its `edition` attribute.
        dev_components (bool, optional): Whether to download the rustc-dev components.
            Requires version to be "nightly". Defaults to False.
        extra_rustc_flags (list, optional): Extra flags to pass to rustc in non-exec configuration.
        extra_exec_rustc_flags (list, optional): Extra flags to pass to rustc in exec configuration.
        opt_level (dict, optional): Optimization level config for this toolchain.
        sha256s (str, optional): A dict associating tool subdirectories to sha256 hashes. See
            [rust_repositories](#rust_repositories) for more details.
        urls (list, optional): A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format). Defaults to ['https://static.rust-lang.org/dist/{}.tar.gz']
        auth (dict): Auth object compatible with repository_ctx.download to use when downloading files.
            See [repository_ctx.download](https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download) for more details.

    Returns:
        str: The name of the registerable toolchain created by this rule.
    """

    if rustfmt_version in ("nightly", "beta"):
        # buildifier: disable=print
        print("`rust_toolchain_repository.rustfmt_version` now requires iso date to be included in the string. E.g. `nightly/2022-12-15`. This version will be assumed until this value is updated")
        rustfmt_version = "{}/{}".format(rustfmt_version, DEFAULT_NIGHTLY_ISO_DATE)

    if exec_compatible_with == None:
        exec_compatible_with = triple_to_constraint_set(exec_triple)

    if target_compatible_with == None:
        target_compatible_with = triple_to_constraint_set(target_triple)

    tools_repo_name = "{}_tools".format(name)

    rust_toolchain_tools_repository(
        name = tools_repo_name,
        exec_triple = exec_triple,
        allocator_library = allocator_library,
        global_allocator_library = global_allocator_library,
        target_triple = target_triple,
        iso_date = iso_date,
        version = version,
        rustfmt_version = rustfmt_version,
        edition = edition,
        dev_components = dev_components,
        extra_rustc_flags = extra_rustc_flags,
        extra_exec_rustc_flags = extra_exec_rustc_flags,
        opt_level = opt_level,
        sha256s = sha256s,
        urls = urls,
        auth = auth,
    )

    channel_target_settings = ["@rules_rust//rust/toolchain/channel:{}".format(channel)] if channel else []

    toolchain_repository_proxy(
        name = name,
        toolchain = "@{}//:rust_toolchain".format(tools_repo_name),
        target_settings = channel_target_settings + target_settings,
        toolchain_type = "@rules_rust//rust:toolchain",
        exec_compatible_with = exec_compatible_with,
        target_compatible_with = target_compatible_with,
    )

    return "@{name}//:toolchain".format(
        name = name,
    )

def _rust_analyzer_toolchain_tools_repository_impl(repository_ctx):
    load_rust_src(
        ctx = repository_ctx,
        iso_date = repository_ctx.attr.iso_date,
        version = repository_ctx.attr.version,
    )

    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    host_triple = get_host_triple(repository_ctx)
    build_contents = [
        load_rust_compiler(
            ctx = repository_ctx,
            iso_date = repository_ctx.attr.iso_date,
            target_triple = host_triple,
            version = repository_ctx.attr.version,
        ),
    ]
    rustc = "//:rustc"

    proc_macro_srv = None
    if includes_rust_analyzer_proc_macro_srv(repository_ctx.attr.version, repository_ctx.attr.iso_date):
        build_contents.append(BUILD_for_rust_analyzer_proc_macro_srv(host_triple))
        proc_macro_srv = "//:rust_analyzer_proc_macro_srv"

    build_contents.append(BUILD_for_rust_analyzer_toolchain(
        name = "rust_analyzer_toolchain",
        rustc = rustc,
        proc_macro_srv = proc_macro_srv,
    ))

    repository_ctx.file("BUILD.bazel", "\n".join(build_contents))
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

rust_analyzer_toolchain_tools_repository = repository_rule(
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
    implementation = _rust_analyzer_toolchain_tools_repository_impl,
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
    rust_analyzer_toolchain_tools_repository(
        name = name + "_tools",
        version = version,
        iso_date = iso_date,
        sha256s = sha256s,
        urls = urls,
        auth = auth,
    )

    toolchain_repository_proxy(
        name = name,
        toolchain = "@{}//:{}".format(name + "_tools", "rust_analyzer_toolchain"),
        toolchain_type = "@rules_rust//rust/rust_analyzer:toolchain_type",
        exec_compatible_with = exec_compatible_with,
        target_compatible_with = target_compatible_with,
    )

    return "@{}//:toolchain".format(
        name,
    )

def _rustfmt_toolchain_tools_repository_impl(repository_ctx):
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    rustfmt = "//:rustfmt_bin"
    rustc = "//:rustc"
    rustc_lib = "//:rustc_lib"

    exec_triple = triple(repository_ctx.attr.exec_triple)

    build_contents = [
        load_rust_compiler(
            ctx = repository_ctx,
            iso_date = repository_ctx.attr.iso_date,
            target_triple = exec_triple,
            version = repository_ctx.attr.version,
        ),
        load_rustfmt(
            ctx = repository_ctx,
            iso_date = repository_ctx.attr.iso_date,
            target_triple = exec_triple,
            version = repository_ctx.attr.version,
        ),
        BUILD_for_rustfmt_toolchain(
            name = "rustfmt_toolchain",
            rustfmt = rustfmt,
            rustc = rustc,
            rustc_lib = rustc_lib,
        ),
    ]

    repository_ctx.file("BUILD.bazel", "\n".join(build_contents))
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

rustfmt_toolchain_tools_repository = repository_rule(
    doc = "A repository rule for defining a rustfmt_toolchain.",
    attrs = {
        "auth": attr.string_dict(
            doc = (
                "Auth object compatible with repository_ctx.download to use when downloading files. " +
                "See [repository_ctx.download](https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download) for more details."
            ),
        ),
        "exec_triple": attr.string(
            doc = "The Rust-style triple Rustfmt is expected to run on.",
            mandatory = True,
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
    implementation = _rustfmt_toolchain_tools_repository_impl,
)

def rustfmt_toolchain_repository(
        name,
        version,
        exec_triple,
        exec_compatible_with = None,
        target_compatible_with = None,
        iso_date = None,
        channel = None,
        sha256s = None,
        urls = None,
        auth = None):
    """Assemble a remote rustfmt_toolchain target based on the given params.

    Args:
        name (str): The name of the toolchain proxy repository contianing the registerable toolchain.
        version (str): The version of the tool among "nightly", "beta', or an exact version.
        exec_triple (str): The platform triple Rustfmt is expected to run on.
        exec_compatible_with (list, optional): A list of constraints for the execution platform for this toolchain.
        target_compatible_with (list, optional): A list of constraints for the target platform for this toolchain.
        iso_date (str, optional): The date of the tool.
        channel (str, optional): The channel value to with which to constrain the toolchain.
        sha256s (str, optional): A dict associating tool subdirectories to sha256 hashes. See
            [rust_repositories](#rust_repositories) for more details.
        urls (list, optional): A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format). Defaults to ['https://static.rust-lang.org/dist/{}.tar.gz']
        auth (dict): Auth object compatible with repository_ctx.download to use when downloading files.
            See [repository_ctx.download](https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download) for more details.

    Returns:
        str: The name of a registerable rustfmt_toolchain.
    """
    if exec_compatible_with == None:
        exec_compatible_with = triple_to_constraint_set(exec_triple)

    rustfmt_toolchain_tools_repository(
        name = name + "_tools",
        version = version,
        iso_date = iso_date,
        sha256s = sha256s,
        urls = urls,
        auth = auth,
        exec_triple = exec_triple,
    )

    toolchain_repository_proxy(
        name = name,
        toolchain = "@{}//:{}".format(name + "_tools", "rustfmt_toolchain"),
        toolchain_type = "@rules_rust//rust/rustfmt:toolchain_type",
        target_settings = ["@rules_rust//rust/toolchain/channel:{}".format(channel)] if channel else None,
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

def _get_toolchain_repositories(name, exec_triple, extra_target_triples, versions, iso_date):
    toolchain_repos = []

    for target_triple in [exec_triple] + extra_target_triples:
        # Parse all provided versions while checking for duplicates
        channels = {}
        for version in versions:
            if version.startswith(("beta", "nightly")):
                channel, _, date = version.partition("/")
                ver = channel
            else:
                channel = "stable"
                date = iso_date
                ver = version

            if channel in channels:
                fail("Duplicate {} channels provided for {}: {}".format(channel, name, versions))

            channels.update({channel: struct(
                name = channel,
                iso_date = date,
                version = ver,
            )})

        # Define toolchains for each requested version
        for channel in channels.values():
            toolchain_repos.append(struct(
                name = "{}__{}__{}".format(name, target_triple, channel.name),
                target_triple = target_triple,
                channel = channel,
            ))

    return toolchain_repos

def rust_repository_set(
        name,
        exec_triple,
        target_settings = [],
        version = None,
        versions = [],
        allocator_library = None,
        global_allocator_library = None,
        extra_target_triples = {},
        iso_date = None,
        rustfmt_version = None,
        edition = None,
        dev_components = False,
        extra_rustc_flags = None,
        extra_exec_rustc_flags = None,
        opt_level = None,
        sha256s = None,
        urls = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        auth = None,
        register_toolchain = True,
        exec_compatible_with = None,
        default_target_compatible_with = None):
    """Assembles a remote repository for the given toolchain params, produces a proxy repository \
    to contain the toolchain declaration, and registers the toolchains.

    Args:
        name (str): The name of the generated repository
        exec_triple (str): The Rust-style target that this compiler runs on
        target_settings (list, optional): A list of config_settings that must be satisfied by the target configuration in order for this set of toolchains to be selected during toolchain resolution.
        version (str): The version of the tool among "nightly", "beta', or an exact version.
        versions (list, optional): A list of toolchain versions to download. This paramter only accepts one versions
            per channel. E.g. `["1.65.0", "nightly/2022-11-02", "beta/2020-12-30"]`.
        allocator_library (str, optional): Target that provides allocator functions when rust_library targets are
            embedded in a cc_binary.
        global_allocator_library (str, optional): Target that provides allocator functions a global allocator is used with cc_common.link.
        extra_target_triples (list or map, optional): Additional rust-style targets that this set of
            toolchains should support. If a map, values should be (optional) target_compatible_with lists for that particular target triple.
        iso_date (str, optional): The date of the tool.
        rustfmt_version (str, optional):  The version of rustfmt to be associated with the
            toolchain.
        edition (str, optional): The rust edition to be used by default (2015, 2018, or 2021). If absent, every rule is
            required to specify its `edition` attribute.
        dev_components (bool, optional): Whether to download the rustc-dev components.
            Requires version to be "nightly".
        extra_rustc_flags (dict, list, optional): Dictionary of target triples to list of extra flags to pass to rustc in non-exec configuration.
        extra_exec_rustc_flags (list, optional): Extra flags to pass to rustc in exec configuration.
        opt_level (dict, dict, optional): Dictionary of target triples to optimiztion config.
        sha256s (str, optional): A dict associating tool subdirectories to sha256 hashes. See
            [rust_repositories](#rust_repositories) for more details.
        urls (list, optional): A list of mirror urls containing the tools from the Rust-lang static file server. These
            must contain the '{}' used to substitute the tool being fetched (using .format).
        auth (dict): Auth object compatible with repository_ctx.download to use when downloading files.
            See [repository_ctx.download](https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download) for more details.
        register_toolchain (bool): If True, the generated `rust_toolchain` target will become a registered toolchain.
        exec_compatible_with (list, optional): A list of constraints for the execution platform for this toolchain.
        default_target_compatible_with (list, optional): A list of constraints for the target platform for this toolchain when the exec platform is the same as the target platform.
    """

    if version and versions:
        fail("`version` and `versions` attributes are mutually exclusive. Update {} to use one".format(
            name,
        ))

    if not version and not versions:
        fail("`version` or `versions` attributes are required. Update {} to use one".format(
            name,
        ))

    if version:
        # buildifier: disable=print
        print("`rust_repository_set.version` is deprecated. Instead use `rust_repository_set.versions`")

    if version and not versions:
        versions = [version]

    # extra_target_triples may be a dict or list - make a list we can pass to _get_toolchain_repositories
    extra_target_triples_list = []
    for extra_target_triple in extra_target_triples:
        extra_target_triples_list.append(extra_target_triple)

    all_toolchain_names = []
    for toolchain in _get_toolchain_repositories(name, exec_triple, extra_target_triples_list, versions, iso_date):
        target_compatible_with = None
        if toolchain.target_triple == exec_triple:
            # The exec triple implicitly gets a toolchain with itself as a target - use default_target_compatible_with for it
            target_compatible_with = default_target_compatible_with
        elif type(extra_target_triples) == "dict":
            target_compatible_with = extra_target_triples.get(toolchain.target_triple)

        all_toolchain_names.append(rust_toolchain_repository(
            name = toolchain.name,
            allocator_library = allocator_library,
            global_allocator_library = global_allocator_library,
            auth = auth,
            channel = toolchain.channel.name,
            dev_components = dev_components,
            edition = edition,
            exec_triple = exec_triple,
            extra_exec_rustc_flags = extra_exec_rustc_flags,
            extra_rustc_flags = extra_rustc_flags.get(toolchain.target_triple) if extra_rustc_flags != None else None,
            opt_level = opt_level.get(toolchain.target_triple) if opt_level != None else None,
            target_settings = target_settings,
            iso_date = toolchain.channel.iso_date,
            rustfmt_version = rustfmt_version,
            sha256s = sha256s,
            target_triple = toolchain.target_triple,
            urls = urls,
            version = toolchain.channel.version,
            exec_compatible_with = exec_compatible_with,
            target_compatible_with = target_compatible_with,
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
