load(":known_shas.bzl", "FILE_KEY_TO_SHA")
load(":triple_mappings.bzl", "triple_to_system", "triple_to_constraint_set", "system_to_binary_ext", "system_to_dylib_ext", "system_to_staticlib_ext")

def _sanitize_for_name(some_string):
    """Cleans a tool name for use as a bazel workspace name"""

    return some_string.replace("-", "_").replace(".", "p")

def BUILD_for_compiler(target_triple):
    """Emits a BUILD file suitable to the provided target_triple."""

    system = triple_to_system(target_triple)
    return """load("@io_bazel_rules_rust//rust:toolchain.bzl", "rust_toolchain")

filegroup(
    name = "rustc",
    srcs = ["bin/rustc{binary_ext}"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "rustc_lib",
    srcs = glob(["lib/*{dylib_ext}"]),
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
    )

def BUILD_for_stdlib(target_triple):
    system = triple_to_system(target_triple)
    return """filegroup(
    name = "rust_lib-{target_triple}",
    srcs = glob([
        "lib/rustlib/{target_triple}/lib/*.rlib",
        "lib/rustlib/{target_triple}/lib/*{dylib_ext}",
        "lib/rustlib/{target_triple}/lib/*{staticlib_ext}",
    ]),
    visibility = ["//visibility:public"],
)
""".format(
        binary_ext = system_to_binary_ext(system),
        staticlib_ext = system_to_staticlib_ext(system),
        dylib_ext = system_to_dylib_ext(system),
        target_triple = target_triple,
    )

def BUILD_for_toolchain(workspace_name, name, exec_triple, target_triple):
    """Emits a toolchain declaration for an existing toolchain workspace."""

    system = triple_to_system(target_triple)

    exec_constraint_set = triple_to_constraint_set(exec_triple)
    exec_constraint_set_strs = []
    for constraint in exec_constraint_set:
        exec_constraint_set_strs.append("\"{}\"".format(constraint))
    exec_constraint_sets_serialized = "[{}]".format(", ".join(exec_constraint_set_strs))

    target_constraint_set = triple_to_constraint_set(target_triple)
    target_constraint_set_strs = []
    for constraint in target_constraint_set:
        target_constraint_set_strs.append("\"{}\"".format(constraint))
    target_constraint_sets_serialized = "[{}]".format(", ".join(target_constraint_set_strs))

    return """
toolchain(
    name = "{toolchain_name}",
    exec_compatible_with = {exec_constraint_sets_serialized},
    target_compatible_with = {target_constraint_sets_serialized},
    toolchain = ":toolchain_for_{target_triple}_impl",
    toolchain_type = "@io_bazel_rules_rust//rust:toolchain",
)

rust_toolchain(
    name = "{toolchain_name}_impl",
    rust_doc = "@{workspace_name}//:rustdoc",
    rust_lib = ["@{workspace_name}//:rust_lib-{target_triple}"],
    rustc = "@{workspace_name}//:rustc",
    rustc_lib = ["@{workspace_name}//:rustc_lib"],
    staticlib_ext = "{staticlib_ext}",
    dylib_ext = "{dylib_ext}",
    os = "{system}",
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
        exec_triple = exec_triple,
        target_triple = target_triple,
        exec_constraint_sets_serialized = exec_constraint_sets_serialized,
        target_constraint_sets_serialized = target_constraint_sets_serialized,
    )

def _check_version_valid(version, iso_date, param_prefix = ""):
    """Verifies that the provided rust version and iso_date make sense."""

    if not version and iso_date:
        fail("{param_prefix}iso_date must be paired with a {param_prefix}version".format(param_prefix = param_prefix))

    if version in ("beta", "nightly") and not iso_date:
        fail("{param_prefix}iso_date must be specified if version is 'beta' or 'nightly'".format(param_prefix = param_prefix))

    if version not in ("beta", "nightly") and iso_date:
        print("{param_prefix}iso_date is ineffective if an exact version is specified".format(param_prefix = param_prefix))

def produce_tool_suburl(tool_name, target_triple, version, iso_date):
    """Produces a fully qualified Rust tool name for URL"""

    if iso_date:
        return "{}/{}-{}-{}".format(iso_date, tool_name, version, target_triple)
    else:
        return "{}-{}-{}".format(tool_name, version, target_triple)

def produce_tool_path(tool_name, target_triple, version):
    """Produces a qualified Rust tool name"""

    return "{}-{}-{}".format(tool_name, version, target_triple)

def load_arbitrary_tool(ctx, tool_name, param_prefix, tool_subdirectory, version, iso_date, target_triple):
    """Loads a Rust tool, downloads, and extracts into the common workspace.
    Args:
      ctx: A repository_ctx.
      tool_name: The name of the given tool per the archive naming.
      param_prefix: The name of the versioning param if the repository rule supports multiple tools.
      tool_subdirectory: The subdirectory of the tool files (wo level below the root directory of
                         the archive. The root directory of the archive is expected to match
                         $TOOL_NAME-$VERSION-$TARGET_TRIPLE.
      version: The version of the tool among "nightly", "beta', or an exact version.
      iso_date: The date of the tool (or None, if the version is a specific version).
      target_triple: The rust-style target triple of the tool
    """

    _check_version_valid(version, iso_date, param_prefix)

    tool_suburl = produce_tool_suburl(tool_name, target_triple, version, iso_date)
    url = "https://static.rust-lang.org/dist/{}.tar.gz".format(tool_suburl)

    tool_path = produce_tool_path(tool_name, target_triple, version)
    ctx.download_and_extract(
        url,
        output = "",
        sha256 = FILE_KEY_TO_SHA.get(tool_suburl) or "",
        type = "tar.gz",
        stripPrefix = "{}/{}".format(tool_path, tool_subdirectory),
    )

def load_rust_compiler(ctx):
    target_triple = ctx.attr.exec_triple
    load_arbitrary_tool(
        ctx,
        iso_date = ctx.attr.iso_date,
        param_prefix = "rustc_",
        target_triple = target_triple,
        tool_name = "rustc",
        tool_subdirectory = "rustc",
        version = ctx.attr.version,
    )

    compiler_BUILD = BUILD_for_compiler(target_triple)

    return compiler_BUILD

def load_rust_stdlib(ctx, target_triple):
    load_arbitrary_tool(
        ctx,
        iso_date = ctx.attr.iso_date,
        param_prefix = "rust-std_",
        target_triple = target_triple,
        tool_name = "rust-std",
        tool_subdirectory = "rust-std-{}".format(target_triple),
        version = ctx.attr.version,
    )

    stdlib_BUILD = BUILD_for_stdlib(target_triple)
    toolchain_BUILD = BUILD_for_toolchain(
        name = "toolchain_for_{}".format(target_triple),
        exec_triple = ctx.attr.exec_triple,
        target_triple = target_triple,
        workspace_name = ctx.attr.name,
    )

    return stdlib_BUILD + toolchain_BUILD

def _rust_toolchain_repository_impl(ctx):
    _check_version_valid(ctx.attr.version, ctx.attr.iso_date)

    BUILD_components = [
        load_rust_compiler(ctx),
        load_rust_stdlib(ctx, ctx.attr.exec_triple),
    ]

    for extra_stdlib_triple in ctx.attr.extra_stdlib_triples:
        BUILD_components.append(load_rust_stdlib(ctx, extra_stdlib_triple))

    ctx.file("WORKSPACE", "")
    ctx.file("BUILD", "\n".join(BUILD_components))

rust_toolchain_repositories = repository_rule(
    attrs = {
        "version": attr.string(mandatory = True),
        "iso_date": attr.string(),
        "exec_triple": attr.string(mandatory = True),
        "extra_stdlib_triples": attr.string_list(),
    },
    implementation = _rust_toolchain_repository_impl,
)

def rust_repository_set(name, version, exec_triple, extra_stdlib_triples, iso_date = None):
    rust_toolchain_repositories(
        name = name,
        exec_triple = exec_triple,
        extra_stdlib_triples = extra_stdlib_triples,
        iso_date = iso_date,
        version = version,
    )

    toolchain_name_tmpl = "@{name}//:toolchain_for_{triple}"
    toolchain_names = [
        toolchain_name_tmpl.format(
            name = name,
            triple = exec_triple,
        ),
    ]
    for triple in extra_stdlib_triples:
        toolchain_names.append(toolchain_name_tmpl.format(
            name = name,
            triple = triple,
        ))

    return toolchain_names

# Eventually with better toolchain hosting options we could load only one of these, not both.
def rust_repositories():
    all_toolchain_names = []
    all_toolchain_names.extend(rust_repository_set(
        name = "rust_linux_x86_64",
        exec_triple = "x86_64-unknown-linux-gnu",
        extra_stdlib_triples = [],
        version = "1.26.1",
    ))

    all_toolchain_names.extend(rust_repository_set(
        name = "rust_darwin_x86_64",
        exec_triple = "x86_64-apple-darwin",
        extra_stdlib_triples = [],
        version = "1.26.1",
    ))

    all_toolchain_names.extend(rust_repository_set(
        name = "rust_freebsd_x86_64",
        exec_triple = "x86_64-unknown-freebsd",
        extra_stdlib_triples = [],
        version = "1.26.1",
    ))

    # Register toolchains
    native.register_toolchains(*all_toolchain_names)
