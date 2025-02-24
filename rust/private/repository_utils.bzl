"""Utility macros for use in rules_rust repository rules"""

load(
    "@bazel_tools//tools/build_defs/repo:utils.bzl",
    "read_netrc",
    "read_user_netrc",
    "use_netrc",
)
load("//rust:known_shas.bzl", "FILE_KEY_TO_SHA")
load("//rust/platform:triple.bzl", "triple")
load(
    "//rust/platform:triple_mappings.bzl",
    "system_to_binary_ext",
    "system_to_dylib_ext",
    "system_to_staticlib_ext",
    "system_to_stdlib_linkflags",
)
load("//rust/private:common.bzl", "DEFAULT_NIGHTLY_ISO_DATE")

DEFAULT_TOOLCHAIN_NAME_PREFIX = "toolchain_for"
DEFAULT_STATIC_RUST_URL_TEMPLATES = ["https://static.rust-lang.org/dist/{}.tar.xz"]
DEFAULT_NIGHTLY_VERSION = "nightly/{}".format(DEFAULT_NIGHTLY_ISO_DATE)
DEFAULT_EXTRA_TARGET_TRIPLES = ["wasm32-unknown-unknown", "wasm32-wasip1"]

TINYJSON_KWARGS = dict(
    name = "rules_rust_tinyjson",
    sha256 = "9ab95735ea2c8fd51154d01e39cf13912a78071c2d89abc49a7ef102a7dd725a",
    url = "https://static.crates.io/crates/tinyjson/tinyjson-2.5.1.crate",
    strip_prefix = "tinyjson-2.5.1",
    type = "tar.gz",
    build_file = "@rules_rust//util/process_wrapper:BUILD.tinyjson.bazel",
)

_build_file_for_compiler_template = """\
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
            "lib/*{dylib_ext}*",
            "lib/rustlib/{target_triple}/codegen-backends/*{dylib_ext}",
            "lib/rustlib/{target_triple}/bin/rust-lld{binary_ext}",
            "lib/rustlib/{target_triple}/lib/*{dylib_ext}*",
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
    """Emits a BUILD file the compiler archive.

    Args:
        target_triple (str): The triple of the target platform

    Returns:
        str: The contents of a BUILD file
    """
    return _build_file_for_compiler_template.format(
        binary_ext = system_to_binary_ext(target_triple.system),
        staticlib_ext = system_to_staticlib_ext(target_triple.system),
        dylib_ext = system_to_dylib_ext(target_triple.system),
        target_triple = target_triple.str,
    )

_build_file_for_cargo_template = """\
filegroup(
    name = "cargo",
    srcs = ["bin/cargo{binary_ext}"],
    visibility = ["//visibility:public"],
)"""

def BUILD_for_cargo(target_triple):
    """Emits a BUILD file the cargo archive.

    Args:
        target_triple (str): The triple of the target platform

    Returns:
        str: The contents of a BUILD file
    """
    return _build_file_for_cargo_template.format(
        binary_ext = system_to_binary_ext(target_triple.system),
    )

_build_file_for_rustfmt_template = """\
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

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
    """Emits a BUILD file the rustfmt archive.

    Args:
        target_triple (str): The triple of the target platform

    Returns:
        str: The contents of a BUILD file
    """
    return _build_file_for_rustfmt_template.format(
        binary_ext = system_to_binary_ext(target_triple.system),
    )

_build_file_for_rust_analyzer_proc_macro_srv = """\
filegroup(
   name = "rust_analyzer_proc_macro_srv",
   srcs = ["libexec/rust-analyzer-proc-macro-srv{binary_ext}"],
   visibility = ["//visibility:public"],
)
"""

def BUILD_for_rust_analyzer_proc_macro_srv(exec_triple):
    """Emits a BUILD file the rust_analyzer_proc_macro_srv archive.

    Args:
        exec_triple (str): The triple of the exec platform
    Returns:
        str: The contents of a BUILD file
    """
    return _build_file_for_rust_analyzer_proc_macro_srv.format(
        binary_ext = system_to_binary_ext(exec_triple.system),
    )

_build_file_for_clippy_template = """\
filegroup(
    name = "clippy_driver_bin",
    srcs = ["bin/clippy-driver{binary_ext}"],
    visibility = ["//visibility:public"],
)
filegroup(
    name = "cargo_clippy_bin",
    srcs = ["bin/cargo-clippy{binary_ext}"],
    visibility = ["//visibility:public"],
)
"""

def BUILD_for_clippy(target_triple):
    """Emits a BUILD file the clippy archive.

    Args:
        target_triple (str): The triple of the target platform

    Returns:
        str: The contents of a BUILD file
    """
    return _build_file_for_clippy_template.format(
        binary_ext = system_to_binary_ext(target_triple.system),
    )

_build_file_for_llvm_tools = """\
filegroup(
    name = "llvm_cov_bin",
    srcs = ["lib/rustlib/{target_triple}/bin/llvm-cov{binary_ext}"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "llvm_profdata_bin",
    srcs = ["lib/rustlib/{target_triple}/bin/llvm-profdata{binary_ext}"],
    visibility = ["//visibility:public"],
)
"""

def BUILD_for_llvm_tools(target_triple):
    """Emits a BUILD file the llvm-tools binaries.

    Args:
        target_triple (struct): The triple of the target platform

    Returns:
        str: The contents of a BUILD file
    """
    return _build_file_for_llvm_tools.format(
        binary_ext = system_to_binary_ext(target_triple.system),
        target_triple = target_triple.str,
    )

_build_file_for_stdlib_template = """\
load("@rules_rust//rust:toolchain.bzl", "rust_stdlib_filegroup")

rust_stdlib_filegroup(
    name = "rust_std-{target_triple}",
    srcs = glob(
        [
            "lib/rustlib/{target_triple}/lib/*.rlib",
            "lib/rustlib/{target_triple}/lib/*{dylib_ext}*",
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
    """Emits a BUILD file the stdlib archive.

    Args:
        target_triple (triple): The triple of the target platform

    Returns:
        str: The contents of a BUILD file
    """
    return _build_file_for_stdlib_template.format(
        binary_ext = system_to_binary_ext(target_triple.system),
        staticlib_ext = system_to_staticlib_ext(target_triple.system),
        dylib_ext = system_to_dylib_ext(target_triple.system),
        target_triple = target_triple.str,
    )

_build_file_for_rust_toolchain_template = """\
load("@rules_rust//rust:toolchain.bzl", "rust_toolchain")

rust_toolchain(
    name = "{toolchain_name}",
    rust_doc = "//:rustdoc",
    rust_std = "//:rust_std-{target_triple}",
    rustc = "//:rustc",
    rustfmt = {rustfmt_label},
    cargo = "//:cargo",
    clippy_driver = "//:clippy_driver_bin",
    cargo_clippy = "//:cargo_clippy_bin",
    llvm_cov = {llvm_cov_label},
    llvm_profdata = {llvm_profdata_label},
    rustc_lib = "//:rustc_lib",
    allocator_library = {allocator_library},
    global_allocator_library = {global_allocator_library},
    binary_ext = "{binary_ext}",
    staticlib_ext = "{staticlib_ext}",
    dylib_ext = "{dylib_ext}",
    stdlib_linkflags = [{stdlib_linkflags}],
    default_edition = "{default_edition}",
    exec_triple = "{exec_triple}",
    target_triple = "{target_triple}",
    visibility = ["//visibility:public"],
    extra_rustc_flags = {extra_rustc_flags},
    extra_exec_rustc_flags = {extra_exec_rustc_flags},
    opt_level = {opt_level},
    tags = ["rust_version={version}"],
)
"""

def BUILD_for_rust_toolchain(
        name,
        exec_triple,
        target_triple,
        version,
        allocator_library,
        global_allocator_library,
        default_edition,
        include_rustfmt,
        include_llvm_tools,
        stdlib_linkflags = None,
        extra_rustc_flags = None,
        extra_exec_rustc_flags = None,
        opt_level = None):
    """Emits a toolchain declaration to match an existing compiler and stdlib.

    Args:
        name (str): The name of the toolchain declaration
        exec_triple (triple): The rust-style target that this compiler runs on
        target_triple (triple): The rust-style target triple of the tool
        version (str): The Rust version for the toolchain.
        allocator_library (str, optional): Target that provides allocator functions when rust_library targets are embedded in a cc_binary.
        global_allocator_library (str, optional): Target that provides allocator functions when a global allocator is used with cc_common_link.
                                                  This target is only used in the target configuration; exec builds still use the symbols provided
                                                  by the `allocator_library` target.
        default_edition (str): Default Rust edition.
        include_rustfmt (bool): Whether rustfmt is present in the toolchain.
        include_llvm_tools (bool): Whether llvm-tools are present in the toolchain.
        stdlib_linkflags (list, optional): Overriden flags needed for linking to rust
                                           stdlib, akin to BAZEL_LINKLIBS. Defaults to
                                           None.
        extra_rustc_flags (list, optional): Extra flags to pass to rustc in non-exec configuration.
        extra_exec_rustc_flags (list, optional): Extra flags to pass to rustc in exec configuration.
        opt_level (dict, optional): Optimization level config for this toolchain.

    Returns:
        str: A rendered template of a `rust_toolchain` declaration
    """
    if stdlib_linkflags == None:
        stdlib_linkflags = ", ".join(['"%s"' % x for x in system_to_stdlib_linkflags(target_triple.system)])

    rustfmt_label = "None"
    if include_rustfmt:
        rustfmt_label = "\"//:rustfmt_bin\""
    llvm_cov_label = "None"
    llvm_profdata_label = "None"
    if include_llvm_tools:
        llvm_cov_label = "\"//:llvm_cov_bin\""
        llvm_profdata_label = "\"//:llvm_profdata_bin\""
    allocator_library_label = "None"
    if allocator_library:
        allocator_library_label = "\"{allocator_library}\"".format(allocator_library = allocator_library)
    global_allocator_library_label = "None"
    if global_allocator_library:
        global_allocator_library_label = "\"{global_allocator_library}\"".format(global_allocator_library = global_allocator_library)

    return _build_file_for_rust_toolchain_template.format(
        toolchain_name = name,
        binary_ext = system_to_binary_ext(target_triple.system),
        staticlib_ext = system_to_staticlib_ext(target_triple.system),
        dylib_ext = system_to_dylib_ext(target_triple.system),
        allocator_library = allocator_library_label,
        global_allocator_library = global_allocator_library_label,
        stdlib_linkflags = stdlib_linkflags,
        default_edition = default_edition,
        exec_triple = exec_triple.str,
        target_triple = target_triple.str,
        rustfmt_label = rustfmt_label,
        llvm_cov_label = llvm_cov_label,
        llvm_profdata_label = llvm_profdata_label,
        extra_rustc_flags = extra_rustc_flags,
        extra_exec_rustc_flags = extra_exec_rustc_flags,
        opt_level = opt_level,
        version = version,
    )

_build_file_for_toolchain_template = """\
toolchain(
    name = "{name}",
    exec_compatible_with = {exec_constraint_sets_serialized},
    target_compatible_with = {target_constraint_sets_serialized},
    toolchain = "{toolchain}",
    toolchain_type = "{toolchain_type}",
    {target_settings}
)
"""

def BUILD_for_toolchain(
        name,
        toolchain,
        toolchain_type,
        target_settings,
        target_compatible_with,
        exec_compatible_with):
    target_settings_value = "target_settings = {},".format(json.encode(target_settings)) if target_settings else "# target_settings = []"

    return _build_file_for_toolchain_template.format(
        name = name,
        exec_constraint_sets_serialized = json.encode(exec_compatible_with),
        target_constraint_sets_serialized = json.encode(target_compatible_with),
        toolchain = toolchain,
        toolchain_type = toolchain_type,
        target_settings = target_settings_value,
    )

def load_rustfmt(*, ctx, attrs, target_triple, version, iso_date, output = None):
    """Loads a rustfmt binary and yields corresponding BUILD for it

    Args:
        ctx (repository_ctx): The repository rule's context object.
        attrs (struct): The rule's attributes struct.
        target_triple (struct): The platform triple to download rustfmt for.
        version (str): The version or channel of rustfmt.
        iso_date (str): The date of the tool (or None, if the version is a specific version).
        output (str, optional): The output location for extracted archives.

    Returns:
        Tuple[str, Dict[str, str]]: The BUILD file contents for this rustfmt binary and sha256 of it's artifact.
    """

    sha256 = load_arbitrary_tool(
        ctx = ctx,
        attrs = attrs,
        output = output,
        iso_date = iso_date,
        target_triple = target_triple,
        tool_name = "rustfmt",
        tool_subdirectories = ["rustfmt-preview"],
        version = version,
    )

    return BUILD_for_rustfmt(target_triple), sha256

def load_rust_compiler(*, ctx, attrs, iso_date, target_triple, version, output = None):
    """Loads a rust compiler and yields corresponding BUILD for it

    Args:
        ctx (repository_ctx): A repository_ctx.
        attrs (struct): The rule's attributes struct.
        iso_date (str): The date of the tool (or None, if the version is a specific version).
        target_triple (struct): The Rust-style target that this compiler runs on.
        version (str): The version of the tool among \"nightly\", \"beta\", or an exact version.
        output (str, optional): The output location for extracted archives.

    Returns:
        Tuple[str, Dict[str, str]]: The BUILD file contents for this compiler and compiler library
            and sha256 of it's artifact.
    """

    sha256 = load_arbitrary_tool(
        ctx = ctx,
        attrs = attrs,
        output = output,
        iso_date = iso_date,
        target_triple = target_triple,
        tool_name = "rustc",
        tool_subdirectories = ["rustc"],
        version = version,
    )

    return BUILD_for_compiler(target_triple), sha256

def load_clippy(*, ctx, attrs, iso_date, target_triple, version, output = None):
    """Loads Clippy and yields corresponding BUILD for it

    Args:
        ctx (repository_ctx): A repository_ctx.
        attrs (struct): The rule's attributes struct.
        iso_date (str): The date of the tool (or None, if the version is a specific version).
        target_triple (struct): The Rust-style target that this compiler runs on.
        version (str): The version of the tool among \"nightly\", \"beta\", or an exact version.
        output (str, optional): The output location for extracted archives.

    Returns:
        Tuple[str, str]: The BUILD file contents for Clippy and the sha256 of it's artifact
    """
    sha256 = load_arbitrary_tool(
        ctx = ctx,
        attrs = attrs,
        output = output,
        iso_date = iso_date,
        target_triple = target_triple,
        tool_name = "clippy",
        tool_subdirectories = ["clippy-preview"],
        version = version,
    )

    return BUILD_for_clippy(target_triple), sha256

def load_cargo(*, ctx, attrs, iso_date, target_triple, version, output = None):
    """Loads Cargo and yields corresponding BUILD for it

    Args:
        ctx (repository_ctx): A repository_ctx.
        attrs (struct): The rule's attributes struct.
        iso_date (str): The date of the tool (or None, if the version is a specific version).
        target_triple (struct): The Rust-style target that this compiler runs on.
        version (str): The version of the tool among \"nightly\", \"beta\", or an exact version.
        output (str, optional): The output location for extracted archives.

    Returns:
        Tuple[str, Dict[str, str]]: The BUILD file contents for Cargo and the sha256 of its artifact.
    """

    sha256 = load_arbitrary_tool(
        ctx = ctx,
        attrs = attrs,
        output = output,
        iso_date = iso_date,
        target_triple = target_triple,
        tool_name = "cargo",
        tool_subdirectories = ["cargo"],
        version = version,
    )

    return BUILD_for_cargo(target_triple), sha256

def includes_rust_analyzer_proc_macro_srv(version, iso_date):
    """Determine whether or not the rust_analyzer_proc_macro_srv binary in available in the given version of Rust.

    Args:
        version (str): The version of the tool among \"nightly\", \"beta\", or an exact version.
        iso_date (str): The date of the tool (or None, if the version is a specific version).

    Returns:
        bool: Whether or not the binary is expected to be included
    """

    if version == "nightly":
        return iso_date >= "2022-09-21"
    elif version == "beta":
        return False
    elif version >= "1.64.0":
        return True

    return False

def load_rust_src(*, ctx, attrs, iso_date, version, sha256 = None, output = None):
    """Loads the rust source code. Used by the rust-analyzer rust-project.json generator.

    Args:
        ctx (ctx): A repository_ctx.
        attrs (struct): The rule's attributes struct.
        version (str): The version of the tool among "nightly", "beta', or an exact version.
        iso_date (str): The date of the tool (or None, if the version is a specific version).
        sha256 (str): The sha256 value for the `rust-src` artifact
        output (str, optional): The output location for extracted archives.

    Returns:
        Dict[str, str]: A mapping of the artifact name to sha256
    """
    if output == None:
        output = ""

    tool_suburl = produce_tool_suburl("rust-src", None, version, iso_date)
    url = attrs.urls[0].format(tool_suburl)

    tool_path = produce_tool_path("rust-src", version, None)
    archive_path = tool_path + _get_tool_extension(getattr(attrs, "urls", None))

    is_reproducible = True
    if sha256 == None:
        sha256s = getattr(attrs, "sha256s", {})
        sha256 = sha256s.get(archive_path, None) or FILE_KEY_TO_SHA.get(archive_path, None)
        if not sha256:
            sha256 = ""
            is_reproducible = False

    output_dir = "{}/lib/rustlib/src".format(output).lstrip("/")
    result = ctx.download_and_extract(
        url,
        output = output_dir,
        sha256 = sha256,
        auth = _make_auth_dict(ctx, attrs, [url]),
        stripPrefix = "{}/rust-src/lib/rustlib/src/rust".format(tool_path),
    )
    ctx.file(
        "{}/BUILD.bazel".format(output_dir),
        """\
filegroup(
    name = "rustc_srcs",
    srcs = glob(["**/*"]),
    visibility = ["//visibility:public"],
)""",
    )

    if is_reproducible:
        return {}

    return {archive_path: result.sha256}

_build_file_for_rust_analyzer_toolchain_template = """\
load("@rules_rust//rust:toolchain.bzl", "rust_analyzer_toolchain")

rust_analyzer_toolchain(
    name = "{name}",
    proc_macro_srv = {proc_macro_srv},
    rustc = "{rustc}",
    rustc_srcs = "//lib/rustlib/src:rustc_srcs",
    visibility = ["//visibility:public"],
)
"""

def BUILD_for_rust_analyzer_toolchain(name, rustc, proc_macro_srv):
    return _build_file_for_rust_analyzer_toolchain_template.format(
        name = name,
        rustc = rustc,
        proc_macro_srv = repr(proc_macro_srv),
    )

_build_file_for_rustfmt_toolchain_template = """\
load("@rules_rust//rust:toolchain.bzl", "rustfmt_toolchain")

rustfmt_toolchain(
    name = "{name}",
    rustfmt = "{rustfmt}",
    rustc = "{rustc}",
    rustc_lib = "{rustc_lib}",
    visibility = ["//visibility:public"],
)
"""

def BUILD_for_rustfmt_toolchain(name, rustfmt, rustc, rustc_lib):
    return _build_file_for_rustfmt_toolchain_template.format(
        name = name,
        rustfmt = rustfmt,
        rustc = rustc,
        rustc_lib = rustc_lib,
    )

def load_rust_stdlib(*, ctx, attrs, target_triple, version, iso_date = None, output = None):
    """Loads a rust standard library and yields corresponding BUILD for it

    Args:
        ctx (repository_ctx): A repository_ctx.
        attrs (struct): The rule's attributes.
        target_triple (struct): The rust-style target triple of the tool
        version (str): The version of the tool among \"nightly\", \"beta\", or an exact version.
        iso_date (str): The iso_date to use with \"nightly\" or \"beta\" versions.
        output (str): The output location for extracted archives.

    Returns:
        Tuple[str, Dict[str, str]]: The BUILD file contents for this stdlib and the sha256 of the artifact.
    """

    sha256 = load_arbitrary_tool(
        ctx = ctx,
        attrs = attrs,
        output = output,
        iso_date = iso_date,
        target_triple = target_triple,
        tool_name = "rust-std",
        tool_subdirectories = ["rust-std-{}".format(target_triple.str)],
        version = version,
    )

    return BUILD_for_stdlib(target_triple), sha256

def load_rustc_dev_nightly(*, ctx, attrs, target_triple, version, iso_date = None, output = None):
    """Loads the nightly rustc dev component

    Args:
        ctx: A repository_ctx.
        attrs (struct): The rule's attributes.
        target_triple: The rust-style target triple of the tool
        version (str): The version of the tool among \"nightly\", \"beta\", or an exact version.
        iso_date (str): The iso_date to use with \"nightly\" or \"beta\" versions.
        output (str): The output location for extracted archives.

    Returns:
        Dict[str, str]: The sha256 value of the rustc-dev artifact.
    """

    subdir_name = "rustc-dev"
    if iso_date and iso_date < "2020-12-24":
        subdir_name = "rustc-dev-{}".format(target_triple)

    sha256 = load_arbitrary_tool(
        ctx = ctx,
        attrs = attrs,
        output = output,
        iso_date = iso_date,
        target_triple = target_triple,
        tool_name = "rustc-dev",
        tool_subdirectories = [subdir_name],
        version = version,
    )

    return sha256

def load_llvm_tools(*, ctx, attrs, target_triple, version, iso_date = None, output = None):
    """Loads the llvm tools

    Args:
        ctx (repository_ctx): A repository_ctx.
        attrs (struct): The rule's attributes.
        target_triple (struct): The rust-style target triple of the tool
        version (str): The version of the tool among \"nightly\", \"beta\", or an exact version.
        iso_date (str): The iso_date to use with \"nightly\" or \"beta\" versions.
        output (str): The output location for extracted archives.

    Returns:
        Tuple[str, Dict[str, str]]: The BUILD.bazel content and sha256 value of the llvm tools artifact.
    """
    sha256 = load_arbitrary_tool(
        ctx = ctx,
        attrs = attrs,
        output = output,
        iso_date = iso_date,
        target_triple = target_triple,
        tool_name = "llvm-tools",
        tool_subdirectories = ["llvm-tools-preview"],
        version = version,
    )

    return BUILD_for_llvm_tools(target_triple), sha256

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

def produce_tool_suburl(tool_name, target_triple, version, iso_date = None):
    """Produces a fully qualified Rust tool name for URL

    Args:
        tool_name (str): The name of the tool per `static.rust-lang.org`.
        target_triple (struct): The rust-style target triple of the tool.
        version (str): The version of the tool among "nightly", "beta', or an exact version.
        iso_date (str): The date of the tool (or None, if the version is a specific version).

    Returns:
        str: The fully qualified url path for the specified tool.
    """
    path = produce_tool_path(tool_name, version, target_triple)
    return iso_date + "/" + path if (iso_date and version in ("beta", "nightly")) else path

def produce_tool_path(tool_name, version, target_triple = None):
    """Produces a qualified Rust tool name

    Args:
        tool_name (str): The name of the tool per static.rust-lang.org
        version (str): The version of the tool among "nightly", "beta', or an exact version.
        target_triple (struct, optional): The rust-style target triple of the tool

    Returns:
        str: The qualified path for the specified tool.
    """
    if not tool_name:
        fail("No tool name was provided")
    if not version:
        fail("No tool version was provided")

    # Not all tools require a triple. E.g. `rustc_src` (Rust source files for rust-analyzer).
    platform_triple = None
    if target_triple:
        platform_triple = target_triple.str

    return "-".join([e for e in [tool_name, version, platform_triple] if e])

def lookup_tool_sha256(
        attrs,
        tool_name,
        target_triple,
        version,
        iso_date):
    """Looks up the sha256 hash of a specific tool archive.

    The lookup order is:

    1. The sha256s dict in the context attributes;
    2. The list of sha256 hashes populated in `//rust:known_shas.bzl`;

    Args:
        attrs (struct): The rule's attributes.
        tool_name (str): The name of the given tool per the archive naming.
        target_triple (struct): The rust-style target triple of the tool.
        version (str): The version of the tool among "nightly", "beta', or an exact version.
        iso_date (str): The date of the tool (ignored if the version is a specific version).

    Returns:
        str: The sha256 of the tool archive, or an empty string if the hash could not be found.
    """
    tool_suburl = produce_tool_suburl(tool_name, target_triple, version, iso_date)
    urls = getattr(attrs, "urls", None)
    archive_path = tool_suburl + _get_tool_extension(urls)
    sha256s = getattr(attrs, "sha256s", dict())

    from_attr = sha256s.get(archive_path, None)
    if from_attr:
        return archive_path, from_attr

    from_builtin = FILE_KEY_TO_SHA.get(archive_path, None)
    if from_builtin:
        return archive_path, from_builtin

    return archive_path, ""

def load_arbitrary_tool(
        *,
        ctx,
        attrs,
        tool_name,
        tool_subdirectories,
        version,
        iso_date,
        target_triple,
        sha256 = None,
        output = None):
    """Loads a Rust tool, downloads, and extracts into the common workspace.

    This function sources the tool from the Rust-lang static file server. The index is available at:
    - https://static.rust-lang.org/dist/channel-rust-stable.toml
    - https://static.rust-lang.org/dist/channel-rust-beta.toml
    - https://static.rust-lang.org/dist/channel-rust-nightly.toml

    For `tool_subdirectories`, the root directory of the archive is expected to
    match ${TOOL_NAME-$VERSION-$TARGET_TRIPLE}. Example:

    ```text
    tool_name
    |    version
    |    |      target_triple
    v    v      v
    rust-1.39.0-x86_64-unknown-linux-gnu/clippy-preview
                                        .../rustc
                                        .../etc
    tool_subdirectories = ["clippy-preview", "rustc"]
    ```

    Args:
        ctx (repository_ctx): A repository_ctx (no attrs required).
        attrs (struct): The rule's attributes struct.
        tool_name (str): The name of the given tool per the archive naming.
        tool_subdirectories (str): The subdirectories of the tool files (at a level below
            the root directory of the archive).
        version (str): The version of the tool among "nightly", "beta', or an exact version.
        iso_date (str): The date of the tool (ignored if the version is a specific version).
        target_triple (struct): The rust-style target triple of the tool.
        sha256 (str, optional): The expected hash of hash of the Rust tool. Defaults to "".
        output (str, optional): The output location for extracted archives.

    Returns:
        Dict[str, str]: A mapping of the tool name to it's sha256 value if the requested tool does not have
            enough information in the repository_ctx to be reproducible.
    """
    check_version_valid(version, iso_date, param_prefix = tool_name + "_")

    # View the indices mentioned in the docstring to find the tool_suburl for a given
    # tool.
    tool_suburl = produce_tool_suburl(tool_name, target_triple, version, iso_date)
    urls = []

    for url in getattr(attrs, "urls", DEFAULT_STATIC_RUST_URL_TEMPLATES):
        new_url = url.format(tool_suburl)
        if new_url not in urls:
            urls.append(new_url)

    tool_path = produce_tool_path(tool_name, version, target_triple)

    archive_path, ctx_sha256 = lookup_tool_sha256(attrs, tool_name, target_triple, version, iso_date)

    is_reproducible = True
    if sha256 == None:
        sha256 = ctx_sha256
        is_reproducible = bool(ctx_sha256)

    for subdirectory in tool_subdirectories:
        # As long as the sha256 value is consistent accross calls here the
        # cost of downloading an artifact is negated as by Bazel's caching.
        result = ctx.download_and_extract(
            urls,
            sha256 = sha256,
            auth = _make_auth_dict(ctx, attrs, urls),
            stripPrefix = "{}/{}".format(tool_path, subdirectory),
            output = output if output else "",
        )

        # In the event no sha256 was provided, set it to the value of the first
        # downloaded item so subsequent downloads use a cached artifact.
        if not sha256:
            sha256 = result.sha256

    # If the artifact is reproducibly downloadable then return an
    # empty dict to inform consumers no attributes require updating.
    if is_reproducible:
        return {}

    return {archive_path: sha256}

# The function is copied from the main branch of bazel_tools.
# It should become available there from version 7.1.0,
# We should remove this function when we upgrade minimum supported
# version to 7.1.0.
# https://github.com/bazelbuild/bazel/blob/d37762b494a4e122d46a5a71e3a8cc77fa15aa25/tools/build_defs/repo/utils.bzl#L424-L446
def _get_auth(ctx, attrs, urls):
    """Utility function to obtain the correct auth dict for a list of urls from .netrc file.

    Support optional netrc and auth_patterns attributes if available.

    Args:
        ctx (repository_ctx): The rule's context object.
        attrs (struct): The rule's attributes
        urls (list[str]): the list of urls to read

    Returns:
        the auth dict which can be passed to repository_ctx.download
    """
    if hasattr(attrs, "netrc") and attrs.netrc:
        netrc = read_netrc(ctx, attrs.netrc)
    elif "NETRC" in ctx.os.environ:
        netrc = read_netrc(ctx, ctx.os.environ["NETRC"])
    else:
        netrc = read_user_netrc(ctx)
    auth_patterns = {}
    if hasattr(attrs, "auth_patterns") and attrs.auth_patterns:
        auth_patterns = attrs.auth_patterns
    return use_netrc(netrc, urls, auth_patterns)

def _make_auth_dict(ctx, attrs, urls):
    auth = getattr(attrs, "auth", {})
    if not auth:
        return _get_auth(ctx, attrs, urls)
    ret = {}
    for url in urls:
        ret[url] = auth
    return ret

def _get_tool_extension(urls = None):
    if urls == None:
        urls = DEFAULT_STATIC_RUST_URL_TEMPLATES
    if urls[0][-7:] == ".tar.gz":
        return ".tar.gz"
    elif urls[0][-7:] == ".tar.xz":
        return ".tar.xz"
    else:
        return ""

def select_rust_version(versions):
    """Select the highest priorty version for a list of Rust versions

    Priority order: `stable > nightly > beta`

    Note that duplicate channels are unexpected in `versions`.

    Args:
        versions (list): A list of Rust versions. E.g. [`1.66.0`, `nightly/2022-12-15`]

    Returns:
        str: The highest ranking value from `versions`
    """
    if not versions:
        fail("No versions were provided")

    current = versions[0]

    for ver in versions:
        if ver.startswith("beta"):
            if current[0].isdigit() or current.startswith("nightly"):
                continue
            if current.startswith("beta") and ver > current:
                current = ver
                continue

            current = ver
        elif ver.startswith("nightly"):
            if current[0].isdigit():
                continue
            if current.startswith("nightly") and ver > current:
                current = ver
                continue

            current = ver

        else:
            current = ver

    return current

_build_file_for_toolchain_hub_template = """
toolchain(
    name = "{name}",
    exec_compatible_with = {exec_constraint_sets_serialized},
    target_compatible_with = {target_constraint_sets_serialized},
    target_settings = {target_settings_serialized},
    toolchain = "{toolchain}",
    toolchain_type = "{toolchain_type}",
    visibility = ["//visibility:public"],
)
"""

def BUILD_for_toolchain_hub(
        toolchain_names,
        toolchain_labels,
        toolchain_types,
        target_settings,
        target_compatible_with,
        exec_compatible_with):
    return "\n".join([_build_file_for_toolchain_hub_template.format(
        name = toolchain_name,
        exec_constraint_sets_serialized = json.encode(exec_compatible_with[toolchain_name]),
        target_constraint_sets_serialized = json.encode(target_compatible_with[toolchain_name]),
        target_settings_serialized = json.encode(target_settings[toolchain_name]) if toolchain_name in target_settings else "None",
        toolchain = toolchain_labels[toolchain_name],
        toolchain_type = toolchain_types[toolchain_name],
    ) for toolchain_name in toolchain_names])

def _toolchain_repository_hub_impl(repository_ctx):
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    repository_ctx.file("BUILD.bazel", BUILD_for_toolchain_hub(
        toolchain_names = repository_ctx.attr.toolchain_names,
        toolchain_labels = repository_ctx.attr.toolchain_labels,
        toolchain_types = repository_ctx.attr.toolchain_types,
        target_settings = repository_ctx.attr.target_settings,
        target_compatible_with = repository_ctx.attr.target_compatible_with,
        exec_compatible_with = repository_ctx.attr.exec_compatible_with,
    ))

toolchain_repository_hub = repository_rule(
    doc = (
        "Generates a toolchain-bearing repository that declares a set of other toolchains from other " +
        "repositories. This exists to allow registering a set of toolchains in one go with the `:all` target."
    ),
    attrs = {
        "exec_compatible_with": attr.string_list_dict(
            doc = "A list of constraints for the execution platform for this toolchain, keyed by toolchain name.",
            mandatory = True,
        ),
        "target_compatible_with": attr.string_list_dict(
            doc = "A list of constraints for the target platform for this toolchain, keyed by toolchain name.",
            mandatory = True,
        ),
        "target_settings": attr.string_list_dict(
            doc = "A list of config_settings that must be satisfied by the target configuration in order for this toolchain to be selected during toolchain resolution.",
            mandatory = True,
        ),
        "toolchain_labels": attr.string_dict(
            doc = "The name of the toolchain implementation target, keyed by toolchain name.",
            mandatory = True,
        ),
        "toolchain_names": attr.string_list(
            mandatory = True,
        ),
        "toolchain_types": attr.string_dict(
            doc = "The toolchain type of the toolchain to declare, keyed by toolchain name.",
            mandatory = True,
        ),
    },
    implementation = _toolchain_repository_hub_impl,
)

RUST_TOOLCHAIN_REPOSITORY_ATTRS = {
    "allocator_library": attr.string(
        doc = "Target that provides allocator functions when rust_library targets are embedded in a cc_binary.",
        default = "@rules_rust//ffi/cc/allocator_library",
    ),
    "auth": attr.string_dict(
        doc = (
            "Auth object compatible with repository_ctx.download to use when downloading files. " +
            "See [repository_ctx.download](https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download) for more details."
        ),
    ),
    "auth_patterns": attr.string_list(
        doc = "A list of patterns to match against urls for which the auth object should be used.",
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
        default = "@rules_rust//ffi/cc/global_allocator_library",
    ),
    "netrc": attr.string(
        doc = ".netrc file to use for authentication; mirrors the eponymous attribute from http_archive",
    ),
    "opt_level": attr.string_dict(
        doc = "Rustc optimization levels. For more details see the documentation for `rust_toolchain.opt_level`.",
    ),
    "rustfmt_version": attr.string(
        doc = "The version of the tool among \"nightly\", \"beta\", or an exact version.",
    ),
    "sha256s": attr.string_dict(
        doc = "A dict associating tool subdirectories to sha256 hashes. See [rust_register_toolchains](#rust_register_toolchains) for more details.",
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
}

def rust_toolchain_tools_repository_impl(repository_ctx, attrs = None, output = None):
    """The implementation of the rust toolchain tools repository rule.

    Args:
        repository_ctx (repository_ctx or module_ctx): The rule's context object.
        attrs (struct): The attributes struct for the rule.
        output (string): The output location for downloaded archives.

    Returns:
        dict: Reproducibility mappings for the repository rule.
    """

    if attrs == None:
        attrs = repository_ctx.attr

    sha256s = dict(attrs.sha256s)
    iso_date = None
    version = attrs.version
    version_array = version.split("/")
    if len(version_array) > 1:
        version = version_array[0]
        iso_date = version_array[1]

    check_version_valid(attrs.version, iso_date)

    exec_triple = triple(attrs.exec_triple)

    rustc_content, rustc_sha256 = load_rust_compiler(
        ctx = repository_ctx,
        attrs = attrs,
        output = output,
        iso_date = iso_date,
        target_triple = exec_triple,
        version = version,
    )
    clippy_content, clippy_sha256 = load_clippy(
        ctx = repository_ctx,
        attrs = attrs,
        output = output,
        iso_date = iso_date,
        target_triple = exec_triple,
        version = version,
    )
    cargo_content, cargo_sha256 = load_cargo(
        ctx = repository_ctx,
        attrs = attrs,
        output = output,
        iso_date = iso_date,
        target_triple = exec_triple,
        version = version,
    )

    build_components = [
        rustc_content,
        clippy_content,
        cargo_content,
    ]
    sha256s.update(rustc_sha256 | clippy_sha256 | cargo_sha256)

    if attrs.rustfmt_version:
        rustfmt_version = attrs.rustfmt_version
        rustfmt_iso_date = None
        if rustfmt_version in ("nightly", "beta"):
            if iso_date:
                rustfmt_iso_date = iso_date
            else:
                fail("`rustfmt_version` does not include an iso_date. The following reposiotry should either set `iso_date` or update `rustfmt_version` to include an iso_date suffix: {}".format(
                    attrs.name,
                ))
        elif rustfmt_version.startswith(("nightly", "beta")):
            rustfmt_version, _, rustfmt_iso_date = rustfmt_version.partition("/")
        rustfmt_content, rustfmt_sha256 = load_rustfmt(
            ctx = repository_ctx,
            attrs = attrs,
            output = output,
            target_triple = triple(attrs.exec_triple),
            version = rustfmt_version,
            iso_date = rustfmt_iso_date,
        )
        build_components.append(rustfmt_content)
        sha256s.update(rustfmt_sha256)

    # Rust 1.45.0 and nightly builds after 2020-05-22 need the llvm-tools gzip to get the libLLVM dylib
    include_llvm_tools = version >= "1.45.0" or (version == "nightly" and iso_date > "2020-05-22")
    if include_llvm_tools:
        llvm_tools_content, llvm_tools_sha256 = load_llvm_tools(
            ctx = repository_ctx,
            attrs = attrs,
            output = output,
            target_triple = exec_triple,
            version = version,
            iso_date = iso_date,
        )
        build_components.append(llvm_tools_content)
        sha256s.update(llvm_tools_sha256)

    target_triple = triple(attrs.target_triple)
    rust_stdlib_content, rust_stdlib_sha256 = load_rust_stdlib(
        ctx = repository_ctx,
        attrs = attrs,
        output = output,
        target_triple = target_triple,
        version = version,
        iso_date = iso_date,
    )
    build_components.append(rust_stdlib_content)
    sha256s.update(rust_stdlib_sha256)

    stdlib_linkflags = None
    if "BAZEL_RUST_STDLIB_LINKFLAGS" in repository_ctx.os.environ:
        stdlib_linkflags = repository_ctx.os.environ["BAZEL_RUST_STDLIB_LINKFLAGS"].split(":")

    build_components.append(BUILD_for_rust_toolchain(
        name = "rust_toolchain",
        exec_triple = exec_triple,
        allocator_library = attrs.allocator_library,
        global_allocator_library = attrs.global_allocator_library,
        target_triple = target_triple,
        stdlib_linkflags = stdlib_linkflags,
        default_edition = attrs.edition,
        include_rustfmt = not (not attrs.rustfmt_version),
        include_llvm_tools = include_llvm_tools,
        extra_rustc_flags = attrs.extra_rustc_flags,
        extra_exec_rustc_flags = attrs.extra_exec_rustc_flags,
        opt_level = attrs.opt_level if attrs.opt_level else None,
        version = attrs.version,
    ))

    # Not all target triples are expected to have dev components
    if attrs.dev_components:
        rustc_dev_sha256 = load_rustc_dev_nightly(
            ctx = repository_ctx,
            attrs = attrs,
            output = output,
            target_triple = target_triple,
            version = version,
            iso_date = iso_date,
        )
        sha256s.update(rustc_dev_sha256)

    repository_ctx.file("WORKSPACE.bazel", "")
    repository_ctx.file("BUILD.bazel", "\n".join(build_components))

    repro = {"name": attrs.name}
    for key in RUST_TOOLCHAIN_REPOSITORY_ATTRS:
        repro[key] = getattr(attrs, key)
    repro["sha256s"] = sha256s

    return repro

rust_toolchain_tools_repository = repository_rule(
    doc = (
        "Composes a single workspace containing the toolchain components for compiling on a given " +
        "platform to a series of target platforms.\n" +
        "\n" +
        "A given instance of this rule should be accompanied by a toolchain_repository_proxy " +
        "invocation to declare its toolchains to Bazel; the indirection allows separating toolchain " +
        "selection from toolchain fetching."
    ),
    attrs = RUST_TOOLCHAIN_REPOSITORY_ATTRS,
    implementation = rust_toolchain_tools_repository_impl,
)
