# buildifier: disable=module-docstring
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load(
    "//rust/platform:triple_mappings.bzl",
    "system_to_binary_ext",
    "system_to_dylib_ext",
    "system_to_staticlib_ext",
    "system_to_stdlib_linkflags",
    "triple_to_constraint_set",
    "triple_to_system",
)
load(":known_shas.bzl", "FILE_KEY_TO_SHA")

DEFAULT_TOOLCHAIN_NAME_PREFIX = "toolchain_for"
DEFAULT_STATIC_RUST_URL_TEMPLATES = ["https://static.rust-lang.org/dist/{}.tar.gz"]
DEFAULT_TOOLCHAIN_TRIPLES = {
    "aarch64-apple-darwin": "rust_darwin_aarch64",
    "aarch64-unknown-linux-gnu": "rust_linux_aarch64",
    "x86_64-apple-darwin": "rust_darwin_x86_64",
    "x86_64-pc-windows-msvc": "rust_windows_x86_64",
    "x86_64-unknown-freebsd": "rust_freebsd_x86_64",
    "x86_64-unknown-linux-gnu": "rust_linux_x86_64",
}

# Note: Code in `.github/workflows/crate_universe.yaml` looks for this line, if you remove it or change its format, you will also need to update that code.
DEFAULT_RUST_VERSION = "1.52.0"

# buildifier: disable=unnamed-macro
def rust_repositories(
        version = DEFAULT_RUST_VERSION,
        iso_date = None,
        rustfmt_version = None,
        edition = None,
        dev_components = False,
        sha256s = None,
        urls = DEFAULT_STATIC_RUST_URL_TEMPLATES):
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
        version (str, optional): The version of Rust. Either "nightly", "beta", or an exact version. Defaults to a modern version.
        iso_date (str, optional): The date of the nightly or beta release (or None, if the version is a specific version).
        rustfmt_version (str, optional): The version of rustfmt. Either "nightly", "beta", or an exact version. Defaults to `version` if not specified.
        edition (str, optional): The rust edition to be used by default (2015 (default) or 2018)
        dev_components (bool, optional): Whether to download the rustc-dev components (defaults to False). Requires version to be "nightly".
        sha256s (str, optional): A dict associating tool subdirectories to sha256 hashes. Defaults to None.
        urls (list, optional): A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format). Defaults to ['https://static.rust-lang.org/dist/{}.tar.gz']
    """

    if dev_components and version != "nightly":
        fail("Rust version must be set to \"nightly\" to enable rustc-dev components")

    if not rustfmt_version:
        rustfmt_version = version

    maybe(
        http_archive,
        name = "rules_cc",
        url = "https://github.com/bazelbuild/rules_cc/archive/624b5d59dfb45672d4239422fa1e3de1822ee110.zip",
        sha256 = "8c7e8bf24a2bf515713445199a677ee2336e1c487fa1da41037c6026de04bbc3",
        strip_prefix = "rules_cc-624b5d59dfb45672d4239422fa1e3de1822ee110",
        type = "zip",
    )

    maybe(
        http_archive,
        name = "bazel_skylib",
        sha256 = "1c531376ac7e5a180e0237938a2536de0c54d93f5c278634818e0efc952dd56c",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz",
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz",
        ],
    )

    for exec_triple, name in DEFAULT_TOOLCHAIN_TRIPLES.items():
        rust_repository_set(
            name = name,
            exec_triple = exec_triple,
            extra_target_triples = ["wasm32-unknown-unknown", "wasm32-wasi"],
            version = version,
            iso_date = iso_date,
            rustfmt_version = rustfmt_version,
            edition = edition,
            dev_components = dev_components,
            sha256s = sha256s,
            urls = urls,
        )

def _check_version_valid(version, iso_date, param_prefix = ""):
    """Verifies that the provided rust version and iso_date make sense."""

    if not version and iso_date:
        fail("{param_prefix}iso_date must be paired with a {param_prefix}version".format(param_prefix = param_prefix))

    if version in ("beta", "nightly") and not iso_date:
        fail("{param_prefix}iso_date must be specified if version is 'beta' or 'nightly'".format(param_prefix = param_prefix))

    if version not in ("beta", "nightly") and iso_date:
        # buildifier: disable=print
        print("{param_prefix}iso_date is ineffective if an exact version is specified".format(param_prefix = param_prefix))

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
    """Emits a BUILD file the compiler .tar.gz."""

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
    """Emits a BUILD file the cargo .tar.gz."""

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
    """Emits a BUILD file the rustfmt .tar.gz."""

    system = triple_to_system(target_triple)
    return _build_file_for_rustfmt_template.format(
        binary_ext = system_to_binary_ext(system),
    )

_build_file_for_rustc_src = """\
load("@rules_rust//rust:toolchain.bzl", "rust_toolchain")

filegroup(
    name = "rustc_src",
    srcs = glob(
        [
            "lib/rustlib/src/**/*.rs",
        ],
    ),
    visibility = ["//visibility:public"],
)
"""

def BUILD_for_rustc_src():
    """Emits a BUILD file for the rustc src extracted files."""

    return _build_file_for_rustc_src

_build_file_for_clippy_template = """\
load("@rules_rust//rust:toolchain.bzl", "rust_toolchain")

filegroup(
    name = "clippy_driver_bin",
    srcs = ["bin/clippy-driver{binary_ext}"],
    visibility = ["//visibility:public"],
)
"""

def BUILD_for_clippy(target_triple):
    """Emits a BUILD file the clippy's extracted files."""

    system = triple_to_system(target_triple)
    return _build_file_for_clippy_template.format(binary_ext = system_to_binary_ext(system))

_build_file_for_stdlib_template = """\
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
"""

def BUILD_for_stdlib(target_triple):
    """Emits a BUILD file the stdlib .tar.gz."""

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
    rust_lib = "@{workspace_name}//:rust_lib-{target_triple}",
    rustc = "@{workspace_name}//:rustc",
    rustfmt = "@{workspace_name}//:rustfmt_bin",
    cargo = "@{workspace_name}//:cargo",
    clippy_driver = "@{workspace_name}//:clippy_driver_bin",
    rustc_lib = "@{workspace_name}//:rustc_lib",
    rustc_src  = "@{workspace_name}//:rustc_src",
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
        stdlib_linkflags = None,
        default_edition = "2015"):
    """Emits a toolchain declaration to match an existing compiler and stdlib.

    Args:
        workspace_name (str): The name of the workspace that this toolchain resides in
        name (str): The name of the toolchain declaration
        exec_triple (str): The rust-style target that this compiler runs on
        target_triple (str): The rust-style target triple of the tool
        stdlib_linkflags (list, optional): Overriden flags needed for linking to rust
                                           stdlib, akin to BAZEL_LINKLIBS. Defaults to
                                           None.
        default_edition (str, optional): Default Rust edition. Defaults to "2015".

    Returns:
        str: A rendered template of a `rust_toolchain` declaration
    """
    system = triple_to_system(target_triple)
    if stdlib_linkflags == None:
        stdlib_linkflags = ", ".join(['"%s"' % x for x in system_to_stdlib_linkflags(system)])

    return _build_file_for_rust_toolchain_template.format(
        toolchain_name = name,
        workspace_name = workspace_name,
        binary_ext = system_to_binary_ext(system),
        staticlib_ext = system_to_staticlib_ext(system),
        dylib_ext = system_to_dylib_ext(system),
        stdlib_linkflags = stdlib_linkflags,
        system = system,
        default_edition = default_edition,
        exec_triple = exec_triple,
        target_triple = target_triple,
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
    "${STATIC_RUST_URL}/dist/index.html" if the STATIC_RUST_URL envinronment variable is set).

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
        iso_date (str): The date of the tool (or None, if the version is a specific version).
        target_triple (str): The rust-style target triple of the tool
        sha256 (str, optional): The expected hash of hash of the Rust tool. Defaults to "".
    """

    _check_version_valid(version, iso_date, param_prefix = tool_name + "_")

    # N.B. See https://static.rust-lang.org/dist/index.html to find the tool_suburl for a given
    # tool.
    tool_suburl = produce_tool_suburl(tool_name, target_triple, version, iso_date)
    static_rust = ctx.os.environ.get("STATIC_RUST_URL", "https://static.rust-lang.org")
    urls = ["{}/dist/{}.tar.gz".format(static_rust, tool_suburl)]

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
        tool_subdirectories = ["rustc", "clippy-preview", "cargo"],
        version = ctx.attr.version,
    )

    compiler_build_file = BUILD_for_compiler(target_triple) + BUILD_for_clippy(target_triple) + BUILD_for_cargo(target_triple)

    return compiler_build_file

def _load_rust_src(ctx):
    """Loads the rust source code. Used by the rust-analyzer rust-project.json generator.

    Args:
        ctx (ctx): A repository_ctx.
    Returns:
        string: The BUILD file contents for the rust source code
    """
    tool_suburl = produce_tool_suburl("rustc", "src", ctx.attr.version, ctx.attr.iso_date)
    static_rust = ctx.os.environ.get("STATIC_RUST_URL", "https://static.rust-lang.org")
    url = "{}/dist/{}.tar.gz".format(static_rust, tool_suburl)

    tool_path = produce_tool_path("rustc", "src", ctx.attr.version)
    archive_path = tool_path + ".tar.gz"
    ctx.download(
        url,
        output = archive_path,
        sha256 = ctx.attr.sha256s.get(tool_suburl) or FILE_KEY_TO_SHA.get(tool_suburl) or "",
    )
    ctx.extract(
        archive_path,
        output = "lib/rustlib/src",
        stripPrefix = tool_path,
    )
    return BUILD_for_rustc_src()

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
        target_triple = target_triple,
        stdlib_linkflags = stdlib_linkflags,
        workspace_name = ctx.attr.name,
        default_edition = ctx.attr.edition,
    )

    return stdlib_build_file + toolchain_build_file

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

def _load_llvm_tools(ctx, target_triple):
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

    return

def _rust_toolchain_repository_impl(ctx):
    """The implementation of the rust toolchain repository rule."""

    _check_version_valid(ctx.attr.version, ctx.attr.iso_date)

    build_components = [_load_rust_compiler(ctx), _load_rust_src(ctx)]

    if ctx.attr.rustfmt_version:
        build_components.append(_load_rustfmt(ctx))

    # Rust 1.45.0 and nightly builds after 2020-05-22 need the llvm-tools gzip to get the libLLVM dylib
    if ctx.attr.version >= "1.45.0" or (ctx.attr.version == "nightly" and ctx.attr.iso_date > "2020-05-22"):
        _load_llvm_tools(ctx, ctx.attr.exec_triple)

    for target_triple in [ctx.attr.exec_triple] + ctx.attr.extra_target_triples:
        build_components.append(_load_rust_stdlib(ctx, target_triple))

        # extra_target_triples contains targets such as wasm, which don't have rustc_dev components
        if ctx.attr.dev_components and target_triple not in ctx.attr.extra_target_triples:
            _load_rustc_dev_nightly(ctx, target_triple)

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
        "dev_components": attr.bool(
            doc = "Whether to download the rustc-dev components (defaults to False). Requires version to be \"nightly\".",
            default = False,
        ),
        "edition": attr.string(
            doc = "The rust edition to be used by default.",
            default = "2015",
        ),
        "exec_triple": attr.string(
            doc = "The Rust-style target that this compiler runs on",
            mandatory = True,
        ),
        "extra_target_triples": attr.string_list(
            doc = "Additional rust-style targets that this set of toolchains should support.",
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
        extra_target_triples = [],
        iso_date = None,
        rustfmt_version = None,
        edition = None,
        dev_components = False,
        sha256s = None,
        urls = DEFAULT_STATIC_RUST_URL_TEMPLATES):
    """Assembles a remote repository for the given toolchain params, produces a proxy repository \
    to contain the toolchain declaration, and registers the toolchains.

    N.B. A "proxy repository" is needed to allow for registering the toolchain (with constraints) \
    without actually downloading the toolchain.

    Args:
        name (str): The name of the generated repository
        version (str): The version of the tool among "nightly", "beta', or an exact version.
        exec_triple (str): The Rust-style target that this compiler runs on
        extra_target_triples (list, optional): Additional rust-style targets that this set of
            toolchains should support. Defaults to [].
        iso_date (str, optional): The date of the tool. Defaults to None.
        rustfmt_version (str, optional):  The version of rustfmt to be associated with the
            toolchain. Defaults to None.
        edition (str, optional): The rust edition to be used by default (2015 (if None) or 2018).
        dev_components (bool, optional): Whether to download the rustc-dev components.
            Requires version to be "nightly". Defaults to False.
        sha256s (str, optional): A dict associating tool subdirectories to sha256 hashes. See
            [rust_repositories](#rust_repositories) for more details.
        urls (list, optional): A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format). Defaults to ['https://static.rust-lang.org/dist/{}.tar.gz']
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
        sha256s = sha256s,
        urls = urls,
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
