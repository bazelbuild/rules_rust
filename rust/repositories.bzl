load(":known_shas.bzl", "FILE_KEY_TO_SHA")
load("//rust/platform:triple_mappings.bzl", "system_to_binary_ext", "system_to_dylib_ext", "system_to_staticlib_ext", "triple_to_constraint_set", "triple_to_system")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

DEFAULT_TOOLCHAIN_NAME_PREFIX = "toolchain_for"

def rust_repositories(version = "1.44.0", iso_date = None, rustfmt_version = "1.4.8", edition = None, dev_components = False):
    """Emits a default set of toolchains for Linux, OSX, and Freebsd

    Skip this macro and call the `rust_repository_set` macros directly if you need a compiler for
    other hosts or for additional target triples.

    Args:
      version: The version of Rust. Either "nightly", "beta", or an exact version.
      rustfmt_version: The version of rustfmt. Either "nightly", "beta", or an exact version.
      iso_date: The date of the nightly or beta release (or None, if the version is a specific version).
      edition: The rust edition to be used by default (2015 (default) or 2018)
      dev_components: Whether to download the rustc-dev components (defaults to False). Requires version to be "nightly".
    """

    if dev_components and version != "nightly":
        fail("Rust version must be set to \"nightly\" to enable rustc-dev components")

    maybe(
        http_archive,
        name = "rules_cc",
        url = "https://github.com/bazelbuild/rules_cc/archive/624b5d59dfb45672d4239422fa1e3de1822ee110.zip",
        sha256 = "8c7e8bf24a2bf515713445199a677ee2336e1c487fa1da41037c6026de04bbc3",
        strip_prefix = "rules_cc-624b5d59dfb45672d4239422fa1e3de1822ee110",
        type = "zip",
    )

    rust_repository_set(
        name = "rust_linux_x86_64",
        exec_triple = "x86_64-unknown-linux-gnu",
        extra_target_triples = ["wasm32-unknown-unknown"],
        version = version,
        iso_date = iso_date,
        rustfmt_version = rustfmt_version,
        edition = edition,
        dev_components = dev_components,
    )

    rust_repository_set(
        name = "rust_darwin_x86_64",
        exec_triple = "x86_64-apple-darwin",
        extra_target_triples = ["wasm32-unknown-unknown"],
        version = version,
        iso_date = iso_date,
        rustfmt_version = rustfmt_version,
        edition = edition,
        dev_components = dev_components,
    )

    rust_repository_set(
        name = "rust_freebsd_x86_64",
        exec_triple = "x86_64-unknown-freebsd",
        extra_target_triples = ["wasm32-unknown-unknown"],
        version = version,
        iso_date = iso_date,
        rustfmt_version = rustfmt_version,
        edition = edition,
        dev_components = dev_components,
    )

def _check_version_valid(version, iso_date, param_prefix = ""):
    """Verifies that the provided rust version and iso_date make sense."""

    if not version and iso_date:
        fail("{param_prefix}iso_date must be paired with a {param_prefix}version".format(param_prefix = param_prefix))

    if version in ("beta", "nightly") and not iso_date:
        fail("{param_prefix}iso_date must be specified if version is 'beta' or 'nightly'".format(param_prefix = param_prefix))

    if version not in ("beta", "nightly") and iso_date:
        print("{param_prefix}iso_date is ineffective if an exact version is specified".format(param_prefix = param_prefix))

def serialized_constraint_set_from_triple(target_triple):
    constraint_set = triple_to_constraint_set(target_triple)
    constraint_set_strs = []
    for constraint in constraint_set:
        constraint_set_strs.append("\"{}\"".format(constraint))
    return "[{}]".format(", ".join(constraint_set_strs))

def BUILD_for_compiler(target_triple):
    """Emits a BUILD file the compiler .tar.gz."""

    system = triple_to_system(target_triple)
    return """
load("@io_bazel_rules_rust//rust:toolchain.bzl", "rust_toolchain")

filegroup(
    name = "rustc",
    srcs = ["bin/rustc{binary_ext}"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "rustc_lib",
    srcs = glob(
        [
            "lib/*{dylib_ext}",
            "lib/rustlib/{target_triple}/codegen-backends/*{dylib_ext}",
        ],
        allow_empty = True,
    ),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "rustdoc",
    srcs = ["bin/rustdoc{binary_ext}"],
    visibility = ["//visibility:public"],
)
""".format(
        binary_ext = system_to_binary_ext(system),
        staticlib_ext = system_to_staticlib_ext(system),
        dylib_ext = system_to_dylib_ext(system),
        target_triple = target_triple,
    )

def BUILD_for_rustfmt(target_triple):
    """Emits a BUILD file the rustfmt .tar.gz."""

    system = triple_to_system(target_triple)
    return """
load("@io_bazel_rules_rust//rust:toolchain.bzl", "rust_toolchain")

filegroup(
    name = "rustfmt_bin",
    srcs = ["bin/rustfmt{binary_ext}"],
    visibility = ["//visibility:public"],
)

sh_binary(
    name = "rustfmt",
    srcs = [":rustfmt_bin"],
    visibility = ["//visibility:public"],
)
""".format(
        binary_ext = system_to_binary_ext(system),
    )

def BUILD_for_clippy(target_triple):
    """Emits a BUILD file the clippy's extracted files."""

    system = triple_to_system(target_triple)
    return """
load("@io_bazel_rules_rust//rust:toolchain.bzl", "rust_toolchain")

filegroup(
    name = "clippy_driver_bin",
    srcs = ["bin/clippy-driver{binary_ext}"],
    visibility = ["//visibility:public"],
)
""".format(binary_ext = system_to_binary_ext(system))

def BUILD_for_stdlib(target_triple):
    """Emits a BUILD file the stdlib .tar.gz."""

    system = triple_to_system(target_triple)
    return """
filegroup(
    name = "rust_lib-{target_triple}",
    srcs = glob(
        [
            "lib/rustlib/{target_triple}/lib/*.rlib",
            "lib/rustlib/{target_triple}/lib/*{dylib_ext}",
            "lib/rustlib/{target_triple}/lib/*{staticlib_ext}",
        ],
        # Some patterns (e.g. `lib/*.a`) don't match anything, see https://github.com/bazelbuild/rules_rust/pull/245
        allow_empty = True,
    ),
    visibility = ["//visibility:public"],
)
""".format(
        binary_ext = system_to_binary_ext(system),
        staticlib_ext = system_to_staticlib_ext(system),
        dylib_ext = system_to_dylib_ext(system),
        target_triple = target_triple,
    )

def BUILD_for_rust_toolchain(workspace_name, name, exec_triple, target_triple, default_edition = "2015"):
    """Emits a toolchain declaration to match an existing compiler and stdlib.

    Args:
      workspace_name: The name of the workspace that this toolchain resides in
      name: The name of the toolchain declaration
      exec_triple: The rust-style target that this compiler runs on
      target_triple: The rust-style target triple of the tool
    """

    system = triple_to_system(target_triple)

    return """
rust_toolchain(
    name = "{toolchain_name}_impl",
    rust_doc = "@{workspace_name}//:rustdoc",
    rust_lib = "@{workspace_name}//:rust_lib-{target_triple}",
    rustc = "@{workspace_name}//:rustc",
    rustfmt = "@{workspace_name}//:rustfmt_bin",
    clippy_driver = "@{workspace_name}//:clippy_driver_bin",
    rustc_lib = "@{workspace_name}//:rustc_lib",
    staticlib_ext = "{staticlib_ext}",
    dylib_ext = "{dylib_ext}",
    os = "{system}",
    default_edition = "{default_edition}",
    exec_triple = "{exec_triple}",
    target_triple = "{target_triple}",
    visibility = ["//visibility:public"],
)
""".format(
        toolchain_name = name,
        workspace_name = workspace_name,
        staticlib_ext = system_to_staticlib_ext(system),
        dylib_ext = system_to_dylib_ext(system),
        system = system,
        default_edition = default_edition,
        exec_triple = exec_triple,
        target_triple = target_triple,
    )

def BUILD_for_toolchain(name, parent_workspace_name, exec_triple, target_triple):
    return """
toolchain(
    name = "{name}",
    exec_compatible_with = {exec_constraint_sets_serialized},
    target_compatible_with = {target_constraint_sets_serialized},
    toolchain = "@{parent_workspace_name}//:{name}_impl",
    toolchain_type = "@io_bazel_rules_rust//rust:toolchain",
)
""".format(
        name = name,
        exec_constraint_sets_serialized = serialized_constraint_set_from_triple(exec_triple),
        target_constraint_sets_serialized = serialized_constraint_set_from_triple(target_triple),
        parent_workspace_name = parent_workspace_name,
    )

def produce_tool_suburl(tool_name, target_triple, version, iso_date = None):
    """Produces a fully qualified Rust tool name for URL

    Args:
      tool_name: The name of the tool per static.rust-lang.org
      target_triple: The rust-style target triple of the tool
      version: The version of the tool among "nightly", "beta', or an exact version.
      iso_date: The date of the tool (or None, if the version is a specific version).
    """

    if iso_date:
        return "{}/{}-{}-{}".format(iso_date, tool_name, version, target_triple)
    else:
        return "{}-{}-{}".format(tool_name, version, target_triple)

def produce_tool_path(tool_name, target_triple, version):
    """Produces a qualified Rust tool name

    Args:
      tool_name: The name of the tool per static.rust-lang.org
      target_triple: The rust-style target triple of the tool
      version: The version of the tool among "nightly", "beta', or an exact version.
    """

    return "{}-{}-{}".format(tool_name, version, target_triple)

def load_arbitrary_tool(ctx, tool_name, tool_subdirectories, version, iso_date, target_triple, sha256 = ""):
    """Loads a Rust tool, downloads, and extracts into the common workspace.

    This function sources the tool from the Rust-lang static file server. The index is available
    at: https://static.rust-lang.org/dist/index.html (or the path specified by
    "${RUST_STATIC_URL}/dist/index.html" if the RUST_STATIC_URL envinronment variable is set).

    Args:
      ctx: A repository_ctx (no attrs required).
      tool_name: The name of the given tool per the archive naming.
      param_prefix: The name of the versioning param if the repository rule supports multiple tools.
      tool_subdirectories: The subdirectories of the tool files (at a level below the root directory of
                           the archive). The root directory of the archive is expected to match
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
      version: The version of the tool among "nightly", "beta', or an exact version.
      iso_date: The date of the tool (or None, if the version is a specific version).
      target_triple: The rust-style target triple of the tool
    """

    _check_version_valid(version, iso_date, param_prefix = tool_name + "_")

    # N.B. See https://static.rust-lang.org/dist/index.html to find the tool_suburl for a given
    # tool.
    tool_suburl = produce_tool_suburl(tool_name, target_triple, version, iso_date)
    static_rust = ctx.os.environ["STATIC_RUST_URL"] if "STATIC_RUST_URL" in ctx.os.environ else "https://static.rust-lang.org"
    url = "{}/dist/{}.tar.gz".format(static_rust, tool_suburl)

    tool_path = produce_tool_path(tool_name, target_triple, version)
    archive_path = tool_path + ".tar.gz"
    ctx.download(
        url,
        output = archive_path,
        sha256 = FILE_KEY_TO_SHA.get(tool_suburl) or sha256,
    )
    for subdirectory in tool_subdirectories:
        ctx.extract(
            archive_path,
            output = "",
            stripPrefix = "{}/{}".format(tool_path, subdirectory),
        )

def _load_rustfmt(ctx):
    target_triple = ctx.attr.exec_triple

    if ctx.attr.rustfmt_version in ("beta", "nightly"):
        iso_date = ctx.attr.iso_date
    else:
        iso_date = None

    load_arbitrary_tool(
        ctx,
        iso_date = iso_date,
        target_triple = target_triple,
        tool_name = "rustfmt",
        tool_subdirectories = ["rustfmt-preview"],
        version = ctx.attr.rustfmt_version,
    )

    return BUILD_for_rustfmt(target_triple)

def _load_rust_compiler(ctx):
    """Loads a rust compiler and yields corresponding BUILD for it

    Args:
      ctx: A repository_ctx.
    Returns:
      The BUILD file contents for this compiler and compiler library
    """

    target_triple = ctx.attr.exec_triple
    load_arbitrary_tool(
        ctx,
        iso_date = ctx.attr.iso_date,
        target_triple = target_triple,
        tool_name = "rust",
        tool_subdirectories = ["rustc", "clippy-preview"],
        version = ctx.attr.version,
    )

    compiler_BUILD = BUILD_for_compiler(target_triple) + BUILD_for_clippy(target_triple)

    return compiler_BUILD

def _load_rust_stdlib(ctx, target_triple):
    """Loads a rust standard library and yields corresponding BUILD for it

    Args:
      ctx: A repository_ctx.
      target_triple: The rust-style target triple of the tool
    Returns:
      The BUILD file contents for this stdlib, and a toolchain decl to match
    """

    load_arbitrary_tool(
        ctx,
        iso_date = ctx.attr.iso_date,
        target_triple = target_triple,
        tool_name = "rust-std",
        tool_subdirectories = ["rust-std-{}".format(target_triple)],
        version = ctx.attr.version,
    )

    toolchain_prefix = ctx.attr.toolchain_name_prefix or DEFAULT_TOOLCHAIN_NAME_PREFIX
    stdlib_BUILD = BUILD_for_stdlib(target_triple)
    toolchain_BUILD = BUILD_for_rust_toolchain(
        name = "{toolchain_prefix}_{target_triple}".format(
            toolchain_prefix = toolchain_prefix,
            target_triple = target_triple,
        ),
        exec_triple = ctx.attr.exec_triple,
        target_triple = target_triple,
        workspace_name = ctx.attr.name,
        default_edition = ctx.attr.edition,
    )

    return stdlib_BUILD + toolchain_BUILD

def _load_rustc_dev_nightly(ctx, target_triple):
    """Loads the nightly rustc dev component

    Args:
      ctx: A repository_ctx.
      target_triple: The rust-style target triple of the tool
    """

    load_arbitrary_tool(
        ctx,
        iso_date = ctx.attr.iso_date,
        target_triple = target_triple,
        tool_name = "rustc-dev",
        tool_subdirectories = ["rustc-dev-{}".format(target_triple)],
        version = ctx.attr.version,
    )

    return

def _rust_toolchain_repository_impl(ctx):
    """The implementation of the rust toolchain repository rule."""

    _check_version_valid(ctx.attr.version, ctx.attr.iso_date)

    BUILD_components = [_load_rust_compiler(ctx)]

    if ctx.attr.rustfmt_version:
        BUILD_components.append(_load_rustfmt(ctx))

    for target_triple in [ctx.attr.exec_triple] + ctx.attr.extra_target_triples:
        BUILD_components.append(_load_rust_stdlib(ctx, target_triple))

        # extra_target_triples contains targets such as wasm, which don't have rustc_dev components
        if ctx.attr.dev_components and target_triple not in ctx.attr.extra_target_triples:
            _load_rustc_dev_nightly(ctx, target_triple)

    ctx.file("WORKSPACE", "")
    ctx.file("BUILD", "\n".join(BUILD_components))

def _rust_toolchain_repository_proxy_impl(ctx):
    BUILD_components = []
    for target_triple in [ctx.attr.exec_triple] + ctx.attr.extra_target_triples:
        BUILD_components.append(BUILD_for_toolchain(
            name = "{toolchain_prefix}_{target_triple}".format(
                toolchain_prefix = ctx.attr.toolchain_name_prefix,
                target_triple = target_triple,
            ),
            exec_triple = ctx.attr.exec_triple,
            parent_workspace_name = ctx.attr.parent_workspace_name,
            target_triple = target_triple,
        ))

    ctx.file("WORKSPACE", "")
    ctx.file("BUILD", "\n".join(BUILD_components))

"""Composes a single workspace containing the toolchain components for compiling on a given
platform to a series of target platforms.

A given instance of this rule should be accompanied by a rust_toolchain_repository_proxy
invocation to declare its toolchains to Bazel; the indirection allows separating toolchain
selection from toolchain fetching

Args:
  name: A unique name for this rule
  version: The version of the tool among "nightly", "beta', or an exact version.
  rustfmt_version: The version of rustfmt to be associated with the toolchain.
  iso_date: The date of the tool (or None, if the version is a specific version).
  exec_triple: The Rust-style target triple for the compilation platform
  extra_target_triples: The Rust-style triples for extra compilation targets
  toolchain_name_prefix: The per-target prefix expected for the rust_toolchain declarations
  edition: The rust edition to be used by default (2015 (default) or 2018)
"""

rust_toolchain_repository = repository_rule(
    attrs = {
        "version": attr.string(mandatory = True),
        "rustfmt_version": attr.string(),
        "iso_date": attr.string(),
        "exec_triple": attr.string(mandatory = True),
        "extra_target_triples": attr.string_list(),
        "toolchain_name_prefix": attr.string(),
        "edition": attr.string(default = "2015"),
        "dev_components": attr.bool(default = False),
    },
    implementation = _rust_toolchain_repository_impl,
)

"""Generates a toolchain-bearing repository that declares the toolchains from some other
rust_toolchain_repository.

Args:
  name: A unique name for this rule
  parent_workspace_name: The name of the other rust_toolchain_repository
  exec_triple: The Rust-style target triple for the compilation platform
  extra_target_triples: The Rust-style triples for extra compilation targets
  toolchain_name_prefix: The per-target prefix expected for the rust_toolchain declarations in the
                         parent workspace.
"""

rust_toolchain_repository_proxy = repository_rule(
    attrs = {
        "parent_workspace_name": attr.string(mandatory = True),
        "exec_triple": attr.string(mandatory = True),
        "extra_target_triples": attr.string_list(),
        "toolchain_name_prefix": attr.string(),
    },
    implementation = _rust_toolchain_repository_proxy_impl,
)

def rust_repository_set(
        name,
        version,
        exec_triple,
        extra_target_triples = [],
        iso_date = None,
        rustfmt_version = None,
        edition = None,
        dev_components = False):
    """Assembles a remote repository for the given toolchain params, produces a proxy repository
    to contain the toolchain declaration, and registers the toolchains.

    N.B. A "proxy repository" is needed to allow for registering the toolchain (with constraints)
    without actually downloading the toolchain.

    Args:
      name: The name of the generated repository
      version: The version of the tool among "nightly", "beta', or an exact version.
      iso_date: The date of the tool (or None, if the version is a specific version).
      exec_triple: The Rust-style target that this compiler runs on
      extra_target_triples: Additional rust-style targets that this set of toolchains
                            should support.
      rustfmt_version: The version of rustfmt to be associated with the toolchain.
      edition: The rust edition to be used by default (2015 (default) or 2018)
      dev_components: Whether to download the rustc-dev components (defaults to False).
                      Requires version to be "nightly".
    """

    rust_toolchain_repository(
        name = name,
        exec_triple = exec_triple,
        extra_target_triples = extra_target_triples,
        iso_date = iso_date,
        toolchain_name_prefix = DEFAULT_TOOLCHAIN_NAME_PREFIX,
        version = version,
        rustfmt_version = rustfmt_version,
        edition = edition,
        dev_components = dev_components,
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
    native.register_toolchains(*all_toolchain_names)
    native.register_toolchains("@io_bazel_rules_rust//rust/private/dummy_cc_toolchain:dummy_cc_wasm32_toolchain")
