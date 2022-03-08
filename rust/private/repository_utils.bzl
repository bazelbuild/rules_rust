"""Utility macros for use in rules_rust repository rules"""

load("//rust:known_shas.bzl", "FILE_KEY_TO_SHA")
load(
    "//rust/platform:triple_mappings.bzl",
    "system_to_binary_ext",
    "system_to_dylib_ext",
    "system_to_staticlib_ext",
    "system_to_stdlib_linkflags",
    "triple_to_constraint_set",
    "triple_to_system",
)

DEFAULT_TOOLCHAIN_NAME_PREFIX = "toolchain_for"
DEFAULT_STATIC_RUST_URL_TEMPLATES = ["https://static.rust-lang.org/dist/{}.tar.gz"]

_build_file_for_compiler_template = """\
load("@rules_rust//rust:toolchain.bzl", "rust_toolchain")

filegroup(
    name = "rustc",
    srcs = ["bin/rustc{binary_ext}"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "rustc_lib",
    srcs = glob(
        [
            "bin/*{dylib_ext}",
            "lib/*{dylib_ext}",
            "lib/rustlib/{target_triple}/codegen-backends/*{dylib_ext}",
            "lib/rustlib/{target_triple}/bin/rust-lld{binary_ext}",
            "lib/rustlib/{target_triple}/lib/*{dylib_ext}",
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
"""

def BUILD_for_compiler(target_triple):
    """Emits a BUILD file the compiler `.tar.gz`.

    Args:
        target_triple (str): The triple of the target platform

    Returns:
        str: The contents of a BUILD file
    """
    system = triple_to_system(target_triple)
    return _build_file_for_compiler_template.format(
        binary_ext = system_to_binary_ext(system),
        staticlib_ext = system_to_staticlib_ext(system),
        dylib_ext = system_to_dylib_ext(system),
        target_triple = target_triple,
    )

_build_file_for_cargo_template = """\
load("@rules_rust//rust:toolchain.bzl", "rust_toolchain")

filegroup(
    name = "cargo",
    srcs = ["bin/cargo{binary_ext}"],
    visibility = ["//visibility:public"],
)"""

def BUILD_for_cargo(target_triple):
    """Emits a BUILD file the cargo `.tar.gz`.

    Args:
        target_triple (str): The triple of the target platform

    Returns:
        str: The contents of a BUILD file
    """
    system = triple_to_system(target_triple)
    return _build_file_for_cargo_template.format(
        binary_ext = system_to_binary_ext(system),
    )

_build_file_for_rustfmt_template = """\
load("@rules_rust//rust:toolchain.bzl", "rust_toolchain")

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
"""

def BUILD_for_rustfmt(target_triple):
    """Emits a BUILD file the rustfmt `.tar.gz`.

    Args:
        target_triple (str): The triple of the target platform

    Returns:
        str: The contents of a BUILD file
    """
    system = triple_to_system(target_triple)
    return _build_file_for_rustfmt_template.format(
        binary_ext = system_to_binary_ext(system),
    )

_build_file_for_clippy_template = """\
load("@rules_rust//rust:toolchain.bzl", "rust_toolchain")

filegroup(
    name = "clippy_driver_bin",
    srcs = ["bin/clippy-driver{binary_ext}"],
    visibility = ["//visibility:public"],
)
"""

def BUILD_for_clippy(target_triple):
    """Emits a BUILD file the clippy `.tar.gz`.

    Args:
        target_triple (str): The triple of the target platform

    Returns:
        str: The contents of a BUILD file
    """
    system = triple_to_system(target_triple)
    return _build_file_for_clippy_template.format(binary_ext = system_to_binary_ext(system))

_build_file_for_stdlib_template = """\
load("@rules_rust//rust:toolchain.bzl", "rust_stdlib_filegroup")

rust_stdlib_filegroup(
    name = "rust_std-{target_triple}",
    srcs = glob(
        [
            "lib/rustlib/{target_triple}/lib/*.rlib",
            "lib/rustlib/{target_triple}/lib/*{dylib_ext}",
            "lib/rustlib/{target_triple}/lib/*{staticlib_ext}",
            "lib/rustlib/{target_triple}/lib/self-contained/**",
        ],
        # Some patterns (e.g. `lib/*.a`) don't match anything, see https://github.com/bazelbuild/rules_rust/pull/245
        allow_empty = True,
    ),
    visibility = ["//visibility:public"],
)

# For legacy support
alias(
    name = "rust_lib-{target_triple}",
    actual = "rust_std-{target_triple}",
    visibility = ["//visibility:public"],
)
"""

def BUILD_for_stdlib(target_triple):
    """Emits a BUILD file the stdlib `.tar.gz`.

    Args:
        target_triple (str): The triple of the target platform

    Returns:
        str: The contents of a BUILD file
    """
    system = triple_to_system(target_triple)
    return _build_file_for_stdlib_template.format(
        binary_ext = system_to_binary_ext(system),
        staticlib_ext = system_to_staticlib_ext(system),
        dylib_ext = system_to_dylib_ext(system),
        target_triple = target_triple,
    )

_build_file_for_rust_toolchain_template = """\
rust_toolchain(
    name = "{toolchain_name}_impl",
    rust_doc = "@{workspace_name}//:rustdoc",
    rust_std = "@{workspace_name}//:rust_std-{target_triple}",
    rustc = "@{workspace_name}//:rustc",
    rustfmt = {rustfmt_label},
    cargo = "@{workspace_name}//:cargo",
    clippy_driver = "@{workspace_name}//:clippy_driver_bin",
    rustc_lib = "@{workspace_name}//:rustc_lib",
    rustc_srcs = {rustc_srcs},
    binary_ext = "{binary_ext}",
    staticlib_ext = "{staticlib_ext}",
    dylib_ext = "{dylib_ext}",
    stdlib_linkflags = [{stdlib_linkflags}],
    os = "{system}",
    default_edition = "{default_edition}",
    exec_triple = "{exec_triple}",
    target_triple = "{target_triple}",
    visibility = ["//visibility:public"],
)
"""

def BUILD_for_rust_toolchain(
        workspace_name,
        name,
        exec_triple,
        target_triple,
        include_rustc_srcs,
        default_edition,
        include_rustfmt,
        stdlib_linkflags = None):
    """Emits a toolchain declaration to match an existing compiler and stdlib.

    Args:
        workspace_name (str): The name of the workspace that this toolchain resides in
        name (str): The name of the toolchain declaration
        exec_triple (str): The rust-style target that this compiler runs on
        target_triple (str): The rust-style target triple of the tool
        include_rustc_srcs (bool, optional): Whether to download rustc's src code. This is required in order to use rust-analyzer support. Defaults to False.
        default_edition (str): Default Rust edition.
        include_rustfmt (bool): Whether rustfmt is present in the toolchain.
        stdlib_linkflags (list, optional): Overriden flags needed for linking to rust
                                           stdlib, akin to BAZEL_LINKLIBS. Defaults to
                                           None.


    Returns:
        str: A rendered template of a `rust_toolchain` declaration
    """
    system = triple_to_system(target_triple)
    if stdlib_linkflags == None:
        stdlib_linkflags = ", ".join(['"%s"' % x for x in system_to_stdlib_linkflags(system)])

    rustc_srcs = "None"
    if include_rustc_srcs:
        rustc_srcs = "\"@{workspace_name}//lib/rustlib/src:rustc_srcs\"".format(workspace_name = workspace_name)
    rustfmt_label = "None"
    if include_rustfmt:
        rustfmt_label = "\"@{workspace_name}//:rustfmt_bin\"".format(workspace_name = workspace_name)

    return _build_file_for_rust_toolchain_template.format(
        toolchain_name = name,
        workspace_name = workspace_name,
        binary_ext = system_to_binary_ext(system),
        staticlib_ext = system_to_staticlib_ext(system),
        dylib_ext = system_to_dylib_ext(system),
        rustc_srcs = rustc_srcs,
        stdlib_linkflags = stdlib_linkflags,
        system = system,
        default_edition = default_edition,
        exec_triple = exec_triple,
        target_triple = target_triple,
        rustfmt_label = rustfmt_label,
    )

_build_file_for_toolchain_template = """\
toolchain(
    name = "{name}",
    exec_compatible_with = {exec_constraint_sets_serialized},
    target_compatible_with = {target_constraint_sets_serialized},
    toolchain = "@{parent_workspace_name}//:{name}_impl",
    toolchain_type = "@rules_rust//rust:toolchain",
)
"""

def BUILD_for_toolchain(name, parent_workspace_name, exec_triple, target_triple):
    return _build_file_for_toolchain_template.format(
        name = name,
        exec_constraint_sets_serialized = serialized_constraint_set_from_triple(exec_triple),
        target_constraint_sets_serialized = serialized_constraint_set_from_triple(target_triple),
        parent_workspace_name = parent_workspace_name,
    )

def load_rustfmt(ctx):
    """Loads a rustfmt binary and yields corresponding BUILD for it

    Args:
        ctx (repository_ctx): The repository rule's context object

    Returns:
        str: The BUILD file contents for this rustfmt binary
    """
    target_triple = ctx.attr.exec_triple

    load_arbitrary_tool(
        ctx,
        iso_date = ctx.attr.iso_date,
        target_triple = target_triple,
        tool_name = "rustfmt",
        tool_subdirectories = ["rustfmt-preview"],
        version = ctx.attr.rustfmt_version,
    )

    return BUILD_for_rustfmt(target_triple)

def load_rust_compiler(ctx):
    """Loads a rust compiler and yields corresponding BUILD for it

    Args:
        ctx (repository_ctx): A repository_ctx.

    Returns:
        str: The BUILD file contents for this compiler and compiler library
    """

    target_triple = ctx.attr.exec_triple
    load_arbitrary_tool(
        ctx,
        iso_date = ctx.attr.iso_date,
        target_triple = target_triple,
        tool_name = "rust",
        tool_subdirectories = ["rustc", "clippy-preview", "cargo"],
        version = ctx.attr.version,
    )

    compiler_build_file = BUILD_for_compiler(target_triple) + BUILD_for_clippy(target_triple) + BUILD_for_cargo(target_triple)

    return compiler_build_file

def should_include_rustc_srcs(repository_ctx):
    """Determing whether or not to include rustc sources in the toolchain.

    Args:
        repository_ctx (repository_ctx): The repository rule's context object

    Returns:
        bool: Whether or not to include rustc source files in a `rustc_toolchain`
    """

    # The environment variable will always take precedence over the attribute.
    include_rustc_srcs_env = repository_ctx.os.environ.get("RULES_RUST_TOOLCHAIN_INCLUDE_RUSTC_SRCS")
    if include_rustc_srcs_env != None:
        return include_rustc_srcs_env.lower() in ["true", "1"]

    return getattr(repository_ctx.attr, "include_rustc_srcs", False)

def load_rust_src(ctx):
    """Loads the rust source code. Used by the rust-analyzer rust-project.json generator.

    Args:
        ctx (ctx): A repository_ctx.
    """
    tool_suburl = produce_tool_suburl("rust-src", None, ctx.attr.version, ctx.attr.iso_date)
    static_rust = ctx.os.environ.get("STATIC_RUST_URL", "https://static.rust-lang.org")
    url = "{}/dist/{}.tar.gz".format(static_rust, tool_suburl)

    tool_path = produce_tool_path("rust-src", None, ctx.attr.version)
    archive_path = tool_path + ".tar.gz"
    ctx.download(
        url,
        output = archive_path,
        sha256 = ctx.attr.sha256s.get(tool_suburl) or FILE_KEY_TO_SHA.get(tool_suburl) or "",
        auth = _make_auth_dict(ctx, [url]),
    )
    ctx.extract(
        archive_path,
        output = "lib/rustlib/src",
        stripPrefix = "{}/rust-src/lib/rustlib/src/rust".format(tool_path),
    )
    ctx.file(
        "lib/rustlib/src/BUILD.bazel",
        """\
filegroup(
    name = "rustc_srcs",
    srcs = glob(["**/*"]),
    visibility = ["//visibility:public"],
)""",
    )

def load_rust_stdlib(ctx, target_triple):
    """Loads a rust standard library and yields corresponding BUILD for it

    Args:
        ctx (repository_ctx): A repository_ctx.
        target_triple (str): The rust-style target triple of the tool

    Returns:
        str: The BUILD file contents for this stdlib, and a toolchain decl to match
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
    stdlib_build_file = BUILD_for_stdlib(target_triple)

    stdlib_linkflags = None
    if "BAZEL_RUST_STDLIB_LINKFLAGS" in ctx.os.environ:
        stdlib_linkflags = ctx.os.environ["BAZEL_RUST_STDLIB_LINKFLAGS"].split(":")

    toolchain_build_file = BUILD_for_rust_toolchain(
        name = "{toolchain_prefix}_{target_triple}".format(
            toolchain_prefix = toolchain_prefix,
            target_triple = target_triple,
        ),
        exec_triple = ctx.attr.exec_triple,
        include_rustc_srcs = should_include_rustc_srcs(ctx),
        target_triple = target_triple,
        stdlib_linkflags = stdlib_linkflags,
        workspace_name = ctx.attr.name,
        default_edition = ctx.attr.edition,
        include_rustfmt = not (not ctx.attr.rustfmt_version),
    )

    return stdlib_build_file + toolchain_build_file

def load_rustc_dev_nightly(ctx, target_triple):
    """Loads the nightly rustc dev component

    Args:
        ctx: A repository_ctx.
        target_triple: The rust-style target triple of the tool
    """

    subdir_name = "rustc-dev"
    if ctx.attr.iso_date < "2020-12-24":
        subdir_name = "rustc-dev-{}".format(target_triple)

    load_arbitrary_tool(
        ctx,
        iso_date = ctx.attr.iso_date,
        target_triple = target_triple,
        tool_name = "rustc-dev",
        tool_subdirectories = [subdir_name],
        version = ctx.attr.version,
    )

def load_llvm_tools(ctx, target_triple):
    """Loads the llvm tools

    Args:
        ctx: A repository_ctx.
        target_triple: The rust-style target triple of the tool
    """
    load_arbitrary_tool(
        ctx,
        iso_date = ctx.attr.iso_date,
        target_triple = target_triple,
        tool_name = "llvm-tools",
        tool_subdirectories = ["llvm-tools-preview"],
        version = ctx.attr.version,
    )

def check_version_valid(version, iso_date, param_prefix = ""):
    """Verifies that the provided rust version and iso_date make sense.

    Args:
        version (str): The rustc version
        iso_date (str): The rustc nightly version's iso date
        param_prefix (str, optional): The name of the tool who's version is being checked.
    """

    if not version and iso_date:
        fail("{param_prefix}iso_date must be paired with a {param_prefix}version".format(param_prefix = param_prefix))

    if version in ("beta", "nightly") and not iso_date:
        fail("{param_prefix}iso_date must be specified if version is 'beta' or 'nightly'".format(param_prefix = param_prefix))

def serialized_constraint_set_from_triple(target_triple):
    """Returns a string representing a set of constraints

    Args:
        target_triple (str): The target triple of the constraint set

    Returns:
        str: Formatted string representing the serialized constraint
    """
    constraint_set = triple_to_constraint_set(target_triple)
    constraint_set_strs = []
    for constraint in constraint_set:
        constraint_set_strs.append("\"{}\"".format(constraint))
    return "[{}]".format(", ".join(constraint_set_strs))

def produce_tool_suburl(tool_name, target_triple, version, iso_date = None):
    """Produces a fully qualified Rust tool name for URL

    Args:
        tool_name: The name of the tool per static.rust-lang.org
        target_triple: The rust-style target triple of the tool
        version: The version of the tool among "nightly", "beta', or an exact version.
        iso_date: The date of the tool (or None, if the version is a specific version).

    Returns:
        str: The fully qualified url path for the specified tool.
    """
    path = produce_tool_path(tool_name, target_triple, version)
    return iso_date + "/" + path if (iso_date and version in ("beta", "nightly")) else path

def produce_tool_path(tool_name, target_triple, version):
    """Produces a qualified Rust tool name

    Args:
        tool_name: The name of the tool per static.rust-lang.org
        target_triple: The rust-style target triple of the tool
        version: The version of the tool among "nightly", "beta', or an exact version.

    Returns:
        str: The qualified path for the specified tool.
    """
    if not tool_name:
        fail("No tool name was provided")
    if not version:
        fail("No tool version was provided")
    return "-".join([e for e in [tool_name, version, target_triple] if e])

def load_arbitrary_tool(ctx, tool_name, tool_subdirectories, version, iso_date, target_triple, sha256 = ""):
    """Loads a Rust tool, downloads, and extracts into the common workspace.

    This function sources the tool from the Rust-lang static file server. The index is available at:
    - https://static.rust-lang.org/dist/channel-rust-stable.toml
    - https://static.rust-lang.org/dist/channel-rust-beta.toml
    - https://static.rust-lang.org/dist/channel-rust-nightly.toml

    The environment variable `STATIC_RUST_URL` can be used to replace the schema and hostname of
    the URLs used for fetching assets. `https://static.rust-lang.org/dist/channel-rust-stable.toml`
    becomes `${STATIC_RUST_URL}/dist/channel-rust-stable.toml`

    Args:
        ctx (repository_ctx): A repository_ctx (no attrs required).
        tool_name (str): The name of the given tool per the archive naming.
        tool_subdirectories (str): The subdirectories of the tool files (at a level below the root directory of
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
        version (str): The version of the tool among "nightly", "beta', or an exact version.
        iso_date (str): The date of the tool (ignored if the version is a specific version).
        target_triple (str): The rust-style target triple of the tool
        sha256 (str, optional): The expected hash of hash of the Rust tool. Defaults to "".
    """
    check_version_valid(version, iso_date, param_prefix = tool_name + "_")

    # View the indices mentioned in the docstring to find the tool_suburl for a given
    # tool.
    tool_suburl = produce_tool_suburl(tool_name, target_triple, version, iso_date)
    urls = []

    static_rust_url_from_env = ctx.os.environ.get("STATIC_RUST_URL")
    if static_rust_url_from_env:
        urls.append("{}/dist/{}.tar.gz".format(static_rust_url_from_env, tool_suburl))

    for url in getattr(ctx.attr, "urls", DEFAULT_STATIC_RUST_URL_TEMPLATES):
        new_url = url.format(tool_suburl)
        if new_url not in urls:
            urls.append(new_url)

    tool_path = produce_tool_path(tool_name, target_triple, version)
    archive_path = "{}.tar.gz".format(tool_path)
    ctx.download(
        urls,
        output = archive_path,
        sha256 = getattr(ctx.attr, "sha256s", dict()).get(tool_suburl) or
                 FILE_KEY_TO_SHA.get(tool_suburl) or
                 sha256,
        auth = _make_auth_dict(ctx, urls),
    )
    for subdirectory in tool_subdirectories:
        ctx.extract(
            archive_path,
            output = "",
            stripPrefix = "{}/{}".format(tool_path, subdirectory),
        )

def _make_auth_dict(ctx, urls):
    auth = getattr(ctx.attr, "auth", {})
    if not auth:
        return {}
    ret = {}
    for url in urls:
        ret[url] = auth
    return ret
