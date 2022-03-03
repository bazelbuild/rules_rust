"""Rules for generating repositories containing components of a `rust_toolchain`"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//rust:known_shas.bzl", "FILE_KEY_TO_SHA")
load("//rust/platform:triple.bzl", "triple")
load(
    "//rust/platform:triple_mappings.bzl",
    "system_to_binary_ext",
    "system_to_dylib_ext",
    "system_to_staticlib_ext",
    "system_to_stdlib_linkflags",
    "triple_to_constraint_set",
    "triple_to_system",
)
load("//rust/private:common.bzl", "rust_common")
load(
    "//rust/private:repository_utils.bzl",
    "BUILD_for_cargo",
    "BUILD_for_llvm_tools",
    "BUILD_for_rustfmt",
    "BUILD_for_stdlib",
    "DEFAULT_STATIC_RUST_URL_TEMPLATES",
    "check_version_valid",
    "load_clippy",
    "load_rust_src",
    "load_rustc",
    "load_rustc_dev_nightly",
    "produce_tool_path",
    "produce_tool_suburl",
    "update_attrs",
    "write_build_and_workspace",
)
load("//rust/private:utils.bzl", "dedent")

_TOOLCHAIN_BUILD_FILE = """\
load(
    "@rules_rust//rust:toolchain.bzl", 
    "rust_toolchain",
)

package(default_visibility = ["//visibility:public"])

rust_toolchain(
    name = "rust_toolchain",
    allocator_library = {allocator_library},
    binary_ext = "{binary_ext}",
    cargo = {cargo},
    clippy_driver = {clippy},
    default_edition = "{default_edition}",
    dylib_ext = "{dylib_ext}",
    exec_triple = "{exec_triple}",
    iso_date = {iso_date},
    llvm_tools = {llvm_tools},
    os = "{os}",
    rust_doc = "{rustdoc}",
    rust_std = {rust_std},
    rustc = "{rustc}",
    rustc_lib = "{rustc_lib}",
    rustc_srcs = {rustc_srcs},
    rustfmt = {rustfmt},
    staticlib_ext = "{staticlib_ext}",
    stdlib_linkflags = {stdlib_linkflags},
    target_triple = "{target_triple}",
)

toolchain(
    name = "toolchain",
    exec_compatible_with = {exec_constraints},
    target_compatible_with = {target_constraints},
    toolchain = ":rust_toolchain",
    toolchain_type = "@rules_rust//rust:toolchain",
)

alias(
    name = "{name}",
    actual = ":toolchain",
)
"""

def _rust_toolchain_repository_impl(repository_ctx):
    """The implementation of the rust toolchain repository rule."""
    exec_triple = triple(repository_ctx.attr.exec_triple)
    target_triple = triple(repository_ctx.attr.target_triple)

    cargo_repository = repository_ctx.attr.cargo_repository
    clippy_repository = repository_ctx.attr.clippy_repository
    rustc_repository = repository_ctx.attr.rustc_repository
    stdlib_repository = repository_ctx.attr.stdlib_repository
    rustfmt_repository = repository_ctx.attr.rustfmt_repository
    rustc_srcs_repository = repository_ctx.attr.rustc_srcs_repository
    llvm_tools_repository = repository_ctx.attr.llvm_tools_repository

    iso_date = "\"{}\"".format(repository_ctx.attr.iso_date) if repository_ctx.attr.iso_date else None
    allocator_library = "\"{}\"".format(repository_ctx.attr.allocator_library) if repository_ctx.attr.allocator_library else None

    stdlib_linkflags = None
    if "BAZEL_RUST_STDLIB_LINKFLAGS" in repository_ctx.os.environ:
        stdlib_linkflags = repository_ctx.os.environ["BAZEL_RUST_STDLIB_LINKFLAGS"].split(":")
    if stdlib_linkflags == None:
        stdlib_linkflags = repository_ctx.attr.stdlib_linkflags

    if rustc_repository:
        include_rustc_srcs_env = repository_ctx.os.environ.get("RULES_RUST_TOOLCHAIN_INCLUDE_RUSTC_SRCS")
        if include_rustc_srcs_env != None:
            include_rustc_srcs = include_rustc_srcs_env.lower() in ["true", "1"]
        else:
            include_rustc_srcs = repository_ctx.attr.include_rustc_srcs
        rustc_srcs = "\"@{}//:rustc_srcs\"".format(rustc_srcs_repository) if include_rustc_srcs else None
    else:
        rustc_srcs = None

    build_file_contents = _TOOLCHAIN_BUILD_FILE.format(
        name = repository_ctx.name,
        allocator_library = allocator_library,
        binary_ext = system_to_binary_ext(target_triple.system),
        cargo = "\"@{}//:cargo\"".format(cargo_repository) if cargo_repository else None,
        clippy = "\"@{}//:clippy_driver_bin\"".format(clippy_repository) if clippy_repository else None,
        default_edition = repository_ctx.attr.edition,
        dylib_ext = system_to_dylib_ext(target_triple.system),
        exec_constraints = repository_ctx.attr.exec_compatible_with,
        exec_triple = exec_triple.str,
        iso_date = iso_date,
        llvm_tools = "\"@{}//:llvm_tools\"".format(llvm_tools_repository) if llvm_tools_repository else None,
        os = target_triple.system,
        rust_std = "\"@{}//:rust_std-{}\"".format(stdlib_repository, target_triple.str) if stdlib_repository else None,
        rustc = "@{}//:rustc".format(rustc_repository),
        rustc_lib = "@{}//:rustc_lib".format(rustc_repository),
        rustc_srcs = rustc_srcs,
        rustdoc = "@{}//:rustdoc".format(rustc_repository),
        rustfmt = "\"@{}//:rustfmt_bin\"".format(rustfmt_repository) if rustfmt_repository else None,
        staticlib_ext = system_to_staticlib_ext(target_triple.system),
        stdlib_linkflags = stdlib_linkflags,
        target_constraints = repository_ctx.attr.target_compatible_with,
        target_triple = target_triple.str,
        version = repository_ctx.attr.version,
    )

    write_build_and_workspace(repository_ctx, build_file_contents)

_rust_toolchain_repository = repository_rule(
    doc = dedent("""\
    A repository rule for wiring together all tools and components required by a host/exec platform for compilation.

    This rule can be used to represent any rustc platform with "host" tools. It creates a `rust_exec_toolchain` using
    generated labels for it's dependencies to allow the toolchain to be registered without requiring that the components
    are first downloaded. For more details on rustc platforms and host tools, see
    [The rustc book](https://doc.rust-lang.org/stable/rustc/platform-support.html).
    """),
    attrs = {
        "allocator_library": attr.label(
            doc = "Target that provides allocator functions when rust_library targets are embedded in a `cc_binary`.",
        ),
        "auth": attr.string_dict(
            doc = (
                "Auth object compatible with repository_ctx.download to use when downloading files. " +
                "See [repository_ctx.download](https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download) for more details."
            ),
        ),
        "cargo_repository": attr.string(
            doc = "The repository name of `rust_cargo_repository`.",
        ),
        "clippy_repository": attr.string(
            doc = "The repository name of `rust_clippy_repository`.",
        ),
        "edition": attr.string(
            doc = (
                "The edition to use for `rust_*` rules that don't specify an edition. " +
                "If absent, every rule is required to specify its `edition` attribute."
            ),
        ),
        "exec_compatible_with": attr.string_list(
            doc = (
                "A list of constraint_values that must be present in the execution platform for this target. " +
                "If left unspecified, a default set for the provided triple will be used. See " +
                "`@rules_rust//rust/platform:triple_mappings.bzl%triple_to_constraint_set`."
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
                "This variable will take precedence over the hard coded attribute. Setting it to `true` " +
                "to activates this attribute where all other values deactivate it."
            ),
            default = False,
        ),
        "iso_date": attr.string(
            doc = "The date of the tool (or None, if the version is a specific version).",
        ),
        "llvm_tools_repository": attr.string(
            doc = "The repository name of `rust_llvm_tools_repository`.",
        ),
        "rustc_repository": attr.string(
            doc = "The repository name of `rust_rustc_repository`.",
            mandatory = True,
        ),
        "rustc_srcs_repository": attr.string(
            doc = "The repository name of `rust_rustc_srcs_repository`.",
        ),
        "rustfmt_repository": attr.string(
            doc = "The repository name of `rust_rustfmt_repository`.",
        ),
        "stdlib_linkflags": attr.string_list(
            doc = "Additional linker libs used when rust-std lib is linked.",
        ),
        "stdlib_repository": attr.string(
            doc = "The repository name for a `rust_stdlib_repository`.",
            mandatory = True,
        ),
        "target_compatible_with": attr.string_list(
            doc = (
                "A list of constraint_values that must be present in the target platform for this target to " +
                "be considered compatible. If left unspecified, a default set for the provided triple will be used. See " +
                "`@rules_rust//rust/platform:triple_mappings.bzl%triple_to_constraint_set`."
            ),
        ),
        "target_triple": attr.string(
            doc = "The platform triple of the target environment.",
            mandatory = True,
        ),
        "version": attr.string(
            doc = "The version of the tool among \"nightly\", \"beta\", or an exact version.",
            mandatory = True,
        ),
    },
    implementation = _rust_toolchain_repository_impl,
    environ = ["RULES_RUST_TOOLCHAIN_INCLUDE_RUSTC_SRCS", "BAZEL_RUST_STDLIB_LINKFLAGS"],
)

_COMMON_TOOL_ATTRS = {
    "auth": attr.string_dict(
        doc = (
            "Auth object compatible with repository_ctx.download to use when downloading files. " +
            "See [repository_ctx.download](https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download) for more details."
        ),
    ),
    "iso_date": attr.string(
        doc = "The date of the tool (or None, if the version is a specific version).",
    ),
    "sha256": attr.string(
        doc = "The expected SHA-256 of the file downloaded. This must match the SHA-256 of the file downloaded.",
    ),
    "urls": attr.string_list(
        doc = (
            "A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used " +
            "to substitute the tool being fetched (using .format)."
        ),
        default = DEFAULT_STATIC_RUST_URL_TEMPLATES,
    ),
    "version": attr.string(
        doc = "The version of the tool among \"nightly\", \"beta\", or an exact version.",
        mandatory = True,
    ),
}

def _rust_rustc_repository_impl(repository_ctx):
    """The implementation of the rust compiler repository rule."""

    check_version_valid(repository_ctx.attr.version, repository_ctx.attr.iso_date)

    build_content, sha256 = load_rustc(repository_ctx)

    dev_components_sha256 = repository_ctx.attr.dev_components_sha256
    if repository_ctx.attr.dev_components:
        dev_components_sha256 = load_rustc_dev_nightly(repository_ctx, repository_ctx.attr.triple)

    write_build_and_workspace(repository_ctx, build_content)

    return update_attrs(repository_ctx.attr, {
        "dev_components_sha256": dev_components_sha256,
        "sha256": sha256,
    })

rust_rustc_repository = repository_rule(
    doc = "A rule for fetching a `rustc` artifact",
    attrs = dict(_COMMON_TOOL_ATTRS.items() + {
        "dev_components": attr.bool(
            doc = "Whether to download the rustc-dev components (defaults to False). Requires version to be \"nightly\".",
            default = False,
        ),
        "dev_components_sha256": attr.string(
            doc = "The expected SHA-256 of the dev components archive.",
        ),
        "triple": attr.string(
            doc = "The Rust-style target that this compiler runs on",
            mandatory = True,
        ),
    }.items()),
    implementation = _rust_rustc_repository_impl,
)

def _rust_http_archive(
        name,
        tool_name,
        triple,
        version,
        iso_date,
        sha256s_map,
        url_templates,
        build_file_content,
        tool_subdirectory,
        **kwargs):
    """A macro backed by [http_archive][ha] for fetching Rust toolchain components.

    The tool_subdirectory of the archive is expected to match
    ```text
    $TOOL_NAME-$VERSION-$TARGET_TRIPLE.
    Example:
    tool_name
    |    version
    |    |      target_triple
    v    v      v
    rust-1.39.0-x86_64-unknown-linux-gnu/clippy-preview
                                        .../rustc
                                        .../etc
    tool_subdirectories = ["clippy-preview", "rustc"]
    ```

    [ha]: https://docs.bazel.build/versions/4.0.0/repo/http.html

    Args:
        name (str): The name to give to the new repository.
        tool_name (str): The name of the Rust static asset bundle to download.
        triple (str): The platform triple of the asset.
        version (str): The version of the tool among "nightly", "beta', or an exact version.
        iso_date (str, optional): The date of the tool (or None, if the version is a specific version).
        sha256s_map (dict): A dict associating tool subdirectories to sha256 hashes.
        url_templates (list): A list of URL templates from where to download the bundle associated with `tool_name`.
        build_file_content (str): The content for the BUILD file for this repository
        tool_subdirectory (str):  The subdirectory of the tool files (at a level below the root directory of the archive).
        **kwargs (dict): Additional keyword arguments to pass to [http_archive][ha]
    """
    for restricted_attr in ("urls", "url", "sha256", "build_file"):
        if restricted_attr in kwargs:
            fail("{} cannot be passed to `rust_http_archive`".format(restricted_attr))

    check_version_valid(version, iso_date)

    suburl = produce_tool_suburl(tool_name, triple, version, iso_date)

    tool_urls = [template.format(suburl) for template in url_templates]
    if not tool_urls:
        tool_urls.extend([template.format(suburl) for template in DEFAULT_STATIC_RUST_URL_TEMPLATES])

    if sha256s_map and suburl in sha256s_map:
        sha256 = sha256s_map[suburl]
    elif suburl in FILE_KEY_TO_SHA:
        sha256 = FILE_KEY_TO_SHA[suburl]
    else:
        sha256 = None

    tool_path = produce_tool_path(tool_name, triple, version)

    http_archive(
        name = name,
        urls = tool_urls,
        sha256 = sha256,
        build_file_content = build_file_content,
        strip_prefix = "{}/{}".format(tool_path, tool_subdirectory),
        **kwargs
    )

def rust_llvm_tools_repository(name, triple, **kwargs):
    """A rule for fetching the `llvm-tool` Rust static asset.

    Args:
        name (str): The name to use for the repository.
        triple (str): The platform triple of the Rust static asset.
        **kwargs (dict): Keyword arguments for `rust_http_archive`.
    """
    _rust_http_archive(
        name = name,
        tool_name = "llvm-tools",
        triple = triple,
        build_file_content = BUILD_for_llvm_tools(triple),
        tool_subdirectory = "llvm-tools-preview",
        **kwargs
    )

def rust_stdlib_repository(name, triple, **kwargs):
    """A rule for fetching the `rust-std` (Rust standard library) asset bundle.

    Args:
        name (str): The name to use for the repository.
        triple (str): The platform triple of the Rust static asset.
        **kwargs (dict): Keyword arguments for `rust_http_archive`.
    """
    _rust_http_archive(
        name = name,
        tool_name = "rust-std",
        triple = triple,
        build_file_content = BUILD_for_stdlib(triple),
        tool_subdirectory = "rust-std-{}".format(triple),
        **kwargs
    )

def _rust_srcs_repository_impl(repository_ctx):
    """The `rust_srcs_repository` repository rule implementation"""

    build_content, sha256 = load_rust_src(repository_ctx, repository_ctx.attr.sha256)

    write_build_and_workspace(
        repository_ctx,
        build_content,
    )

    return update_attrs(repository_ctx.attr, {"sha256": sha256})

rust_srcs_repository = repository_rule(
    doc = (
        "A repository rule for fetching rustc sources. These are typically useful for things " +
        "[rust-analyzer](https://rust-analyzer.github.io/)."
    ),
    implementation = _rust_srcs_repository_impl,
    attrs = _COMMON_TOOL_ATTRS,
)

def rust_rustfmt_repository(name, triple, **kwargs):
    """A rule for fetching the `rustfmt` Rust asset bundle.

    Args:
        name (str): The name to use for the repository.
        triple (str): The platform triple of the Rust static asset.
        **kwargs (dict): Keyword arguments for `rust_http_archive`.
    """
    _rust_http_archive(
        name = name,
        tool_name = "rustfmt",
        triple = triple,
        build_file_content = BUILD_for_rustfmt(triple),
        tool_subdirectory = "rustfmt-preview",
        **kwargs
    )

def rust_cargo_repository(name, triple, **kwargs):
    """A rule for fetching the `cargo` Rust asset bundle.

    Args:
        name (str): The name to use for the repository.
        triple (str): The platform triple of the Rust static asset.
        **kwargs (dict): Keyword arguments for `rust_http_archive`.
    """
    _rust_http_archive(
        name = name,
        tool_name = "cargo",
        triple = triple,
        build_file_content = BUILD_for_cargo(triple),
        tool_subdirectory = "cargo",
        **kwargs
    )

def _rust_clippy_repository_impl(repository_ctx):
    """The `rust_clippy_repository` repository rule implementation"""

    build_content, sha256 = load_clippy(repository_ctx)

    write_build_and_workspace(repository_ctx, build_content)

    return update_attrs(repository_ctx.attr, {"sha256": sha256})

rust_clippy_repository = repository_rule(
    doc = (
        "A repository rule for defining a `rust_clippy_toolchain` from the requested version of " +
        "[Clippy](https://github.com/rust-lang/rust-clippy#readme)"
    ),
    implementation = _rust_clippy_repository_impl,
    attrs = dict(_COMMON_TOOL_ATTRS.items() + {
        "triple": attr.string(
            doc = "The Rust-style target that this compiler runs on",
            mandatory = True,
        ),
    }.items()),
)

def _get_sha256(tool_name, target_triple, version, sha256s, iso_date = None):
    """Produce the sha256 of a particular Rust tool

    Args:
        tool_name (str): The name of the tool per static.rust-lang.org
        target_triple (str): The rust-style target triple of the tool
        version (str): The version of the tool among "nightly", "beta', or an exact version.
        sha256s (dict, optional): A dict associating tool subdirectories to sha256 hashes.
        iso_date (str, optional): The date of the tool (or None, if the version is a specific version).

    Returns:
        tuple: The URL of a Rust artifact and it's sha256 value if one was found
    """
    suburl = produce_tool_suburl(tool_name, target_triple, version, iso_date)

    if sha256s and suburl in sha256s:
        return sha256s[suburl]
    elif suburl in FILE_KEY_TO_SHA:
        return FILE_KEY_TO_SHA[suburl]

    return None

def rust_exec_tool_repositories(
        name,
        triple,
        auth = None,
        dev_components = False,
        iso_date = None,
        rustfmt_iso_date = None,
        rustfmt_version = None,
        sha256s_map = None,
        url_templates = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        version = rust_common.default_version):
    """Generates repositories for host tools (as described by [The rustc book][trc]) for use in a `rust_toolchain`.

    Tool Repositories Created:
    - [rust_cargo_repository](#rust_cargo_repository)
    - [rust_clippy_repository](#rust_clippy_repository)
    - [rust_rustc_repository](#rust_rustc_repository)
    - [rust_rustfmt_repository](#rust_rustfmt_repository)
    - [rust_srcs_repository](#rust_srcs_repository)

    [trc]: https://doc.rust-lang.org/nightly/rustc/platform-support.html#platform-support

    Args:
        name (str): The name of the toolchain repository as well as the prefix for each individual 'tool repository'.
        triple (str): The triple of the host tools to fetch
        auth (str, optional): Auth object compatible with `repository_ctx.download` to use when downloading files.
        dev_components (bool, optional): Whether to download the rustc-dev components. Requires version to be \"nightly\"."
        iso_date (str, optional): The date of the tool (or None, if the version is a specific version).
        rustfmt_iso_date (str, optional): Similar to `iso_date` but specific to Rustfmt. If unspecified, `iso_date` will be used.
        rustfmt_version (str, optional): Similar to `version` but specific to Rustfmt. If unspecified, `version` will be used.
        sha256s_map (dict, optional): A dict associating tool subdirectories to sha256 hashes.
        url_templates (list, optional): A list of mirror urls containing the tools from the Rust-lang static file server. These must
            contain the '{}' used to substitute the tool being fetched (using .format).
        version (str, optional): The version of the tool among \"nightly\", \"beta\", or an exact version.

    Returns:
        struct: A struct of generated repository names: `[rustc, rustc_srcs, rustfmt, cargo, clippy, llvm_tools]`
    """
    rustfmt_name = "{}_rustfmt".format(name)
    if rustfmt_version:
        rustfmt_version_str = rustfmt_version if rustfmt_version not in ["nightly", "beta"] else "{}-{}".format(
            rustfmt_version,
            rustfmt_iso_date,
        )
        rustfmt_name = "{}_{}".format(rustfmt_name, rustfmt_version_str)

    if not rustfmt_version:
        rustfmt_version = version
    if not rustfmt_iso_date:
        rustfmt_iso_date = iso_date

    llvm_tools = None

    # Rust 1.45.0 and nightly builds after 2020-05-22 need the llvm-tools gzip to get the libLLVM dylib
    if version >= "1.45.0" or (version == "nightly" and iso_date > "2020-05-22"):
        llvm_tools = "{}_llvm_tools".format(name)

    rules = struct(
        rustc = "{}_rustc".format(name),
        # rustc_srcs are platform agnostic so it should be something
        # defined once and shared accross various toolchains. This
        # is acheived by ensuring it has a consistent repository name.
        rustc_srcs = "rust_rustc_srcs",
        rustfmt = rustfmt_name,
        cargo = "{}_cargo".format(name),
        clippy = "{}_clippy".format(name),
        llvm_tools = llvm_tools,
    )

    if not native.existing_rule(rules.rustc):
        rust_rustc_repository(
            name = rules.rustc,
            auth = auth,
            dev_components = dev_components,
            triple = triple,
            iso_date = iso_date,
            sha256 = _get_sha256("rustc", triple, version, iso_date, sha256s_map),
            dev_components_sha256 = _get_sha256("rustc-dev", triple, version, iso_date, sha256s_map),
            urls = url_templates,
            version = version,
        )

    # Rust 1.45.0 and nightly builds after 2020-05-22 need the llvm-tools gzip to get the libLLVM dylib
    if rules.llvm_tools and not native.existing_rule(rules.llvm_tools):
        rust_llvm_tools_repository(
            name = rules.llvm_tools,
            auth = auth,
            triple = triple,
            iso_date = iso_date,
            url_templates = url_templates,
            sha256s_map = sha256s_map,
            version = version,
        )

    if not native.existing_rule(rules.rustc_srcs):
        rust_srcs_repository(
            name = rules.rustc_srcs,
            auth = auth,
            iso_date = iso_date,
            sha256 = _get_sha256("rust-src", None, version, iso_date, sha256s_map),
            urls = url_templates,
            version = version,
        )

    if not native.existing_rule(rules.rustfmt):
        rust_rustfmt_repository(
            name = rules.rustfmt,
            auth = auth,
            triple = triple,
            iso_date = rustfmt_iso_date,
            sha256s_map = sha256s_map,
            url_templates = url_templates,
            version = rustfmt_version,
        )

    if not native.existing_rule(rules.cargo):
        rust_cargo_repository(
            name = rules.cargo,
            auth = auth,
            triple = triple,
            iso_date = iso_date,
            sha256s_map = sha256s_map,
            url_templates = url_templates,
            version = version,
        )

    if not native.existing_rule(rules.clippy):
        rust_clippy_repository(
            name = rules.clippy,
            auth = auth,
            triple = triple,
            iso_date = iso_date,
            sha256 = _get_sha256("clippy", triple, version, iso_date, sha256s_map),
            urls = url_templates,
            version = version,
        )

    return rules

def rust_target_tool_repositories(
        name,
        triple,
        auth = None,
        iso_date = None,
        sha256s_map = None,
        url_templates = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        version = rust_common.default_version):
    """Generates repositories for target components of a `rust_toolchain`.

    Tool Repositories Created:
    - [rust_stdlib_repository](#rust_stdlib_repository)

    Args:
        name (str): The name of the toolchain repository as well as the prefix for each individual 'tool repository'.
        triple (str): The platform triple of the target environment.
        auth (str, optional): Auth object compatible with `repository_ctx.download` to use when downloading files.
        iso_date (str, optional): The date of the tool (or None, if the version is a specific version).
        sha256s_map (dict, optional): A dict associating tool subdirectories to sha256 hashes.
        url_templates (list, optional): A list of mirror urls containing the tools from the Rust-lang static file server. These must
            contain the '{}' used to substitute the tool being fetched (using .format).
        version (str, optional): The version of the tool among \"nightly\", \"beta\", or an exact version.

    Returns:
        struct: A struct of generated repository names: `[rust_std]`
    """

    rules = struct(
        stdlib = "{}_stdlib".format(name),
    )

    if not native.existing_rule(rules.stdlib):
        rust_stdlib_repository(
            name = rules.stdlib,
            auth = auth,
            iso_date = iso_date,
            sha256s_map = sha256s_map,
            triple = triple,
            url_templates = url_templates,
            version = version,
        )

    return rules

def rust_toolchain_repository(
        name,
        exec_triple,
        target_triple,
        rustc_repository,
        allocator_library = None,
        cargo_repository = None,
        clippy_repository = None,
        edition = None,
        exec_compatible_with = None,
        include_rustc_srcs = False,
        iso_date = None,
        llvm_tools_repository = None,
        register_toolchain = True,
        rustc_srcs_repository = None,
        rustfmt_repository = None,
        stdlib_linkflags = None,
        stdlib_repository = None,
        target_compatible_with = None,
        version = rust_common.default_version,
        **kwargs):
    """A repository rule for defining a [rust_toolchain](#rust_toolchain).

    This repository rule generates repositories for host tools (as described by [The rustc book][trc]) and wires
    them into a `rust_exec_toolchain` target. Note that the `rust_exec_toolchain` only includes `rustc` and it's
    dependencies. Additional host tools such as `Cargo`, `Clippy`, and `Rustfmt` are all declared as separate
    toolchains. This rule should be used to define more customized exec toolchains than those created by
    `rust_repositories`.

    Args:
        name (str): The name of the toolchain repository as well as the prefix for each individual 'tool repository'.
        exec_triple (str): The platform triple of the execution environment.
        target_triple (str): The platform triple of the target environment.
        rustc_repository (str): The name of a `rust_rustc_repository` repository.
        allocator_library (str, optional): Target that provides allocator functions when rust_library targets are embedded in a `cc_binary`.
        cargo_repository (str, optional): The name of a `rust_cargo_repository` repository.
        clippy_repository (str, optional): The name of a `rust_clippy_repository` repository.
        edition (str, optional): The Rust edition to be used by default.
        exec_compatible_with (list, optional): Optional exec constraints for the toolchain. If unset, a default will be used
            based on the value of `exec_triple`. See `@rules_rust//rust/platform:triple_mappings.bzl` for more details.
        include_rustc_srcs (bool, optional): Whether to download and unpack the
            rustc source files. These are very large, and slow to unpack, but are required to support rust analyzer.
        iso_date (str, optional): The date of the tool (or None, if the version is a specific version).
        llvm_tools_repository (str, optional): The name of a `rust_llvm_tools_repository` repository.
        register_toolchain (bool): If true, repositories will be generated to produce and register `rust_toolchain` targets.
        rustc_srcs_repository (str, optional): The name of a `rust_rustc_srcs_repository` repository.
        rustfmt_repository (str, optional): The name of a `rust_rustfmt_repository` repository.
        stdlib_linkflags (list, optional): The repository name for a `rust_stdlib_repository`.
        stdlib_repository (str, optional): The name of a `rust_stdlib_repository` repository.
        target_compatible_with (list, optional): Optional target constraints for the toolchain. If unset, a default will be used
            based on the value of `target_triple`. See `@rules_rust//rust/platform:triple_mappings.bzl` for more details.
        version (str, optional): The version of the tool among \"nightly\", \"beta\", or an exact version.
        **kwargs (dict): Additional keyword arguments for the underlying `rust_toolchain_repositry` rule.
    """

    stdlib_opts = stdlib_linkflags
    if stdlib_opts == None:
        stdlib_opts = system_to_stdlib_linkflags(triple_to_system(target_triple))

    if exec_compatible_with == None:
        exec_compatible_with = triple_to_constraint_set(exec_triple)

    if target_compatible_with == None:
        target_compatible_with = triple_to_constraint_set(target_triple)

    _rust_toolchain_repository(
        name = name,
        allocator_library = allocator_library,
        cargo_repository = cargo_repository,
        clippy_repository = clippy_repository,
        edition = edition,
        exec_compatible_with = exec_compatible_with,
        exec_triple = exec_triple,
        include_rustc_srcs = include_rustc_srcs,
        iso_date = iso_date,
        llvm_tools_repository = llvm_tools_repository,
        rustc_repository = rustc_repository,
        rustc_srcs_repository = rustc_srcs_repository,
        rustfmt_repository = rustfmt_repository,
        stdlib_linkflags = stdlib_opts,
        stdlib_repository = stdlib_repository,
        target_compatible_with = target_compatible_with,
        target_triple = target_triple,
        version = version,
        **kwargs
    )

    if register_toolchain:
        native.register_toolchains("@{}//:toolchain".format(name))
