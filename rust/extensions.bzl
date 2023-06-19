"Module extensions for using rules_rust with bzlmod"

load("//rust:defs.bzl", "rust_common")
load("//rust:repositories.bzl", "rust_register_toolchains", "rust_toolchain_tools_repository")
load("//rust/platform:triple.bzl", "get_host_triple")
load(
    "//rust/private:repository_utils.bzl",
    "DEFAULT_EXTRA_TARGET_TRIPLES",
    "DEFAULT_NIGHTLY_VERSION",
    "DEFAULT_STATIC_RUST_URL_TEMPLATES",
)

def _rust_impl(module_ctx):
    # Allow the root module to define host tools. Otherwise, we'll fall back to
    # the one defined in rules_rust.
    for mod in module_ctx.modules:
        if mod.tags.host_tools:
            host_tools = mod.tags.host_tools[0]
            host_triple = get_host_triple(module_ctx)

            rust_toolchain_tools_repository(
                name = "rust_host_tools",
                exec_triple = host_triple.str,
                target_triple = host_triple.str,
                allocator_library = host_tools.allocator_library,
                dev_components = host_tools.dev_components,
                edition = host_tools.edition,
                rustfmt_version = host_tools.rustfmt_version,
                sha256s = host_tools.sha256s,
                urls = host_tools.urls,
                version = host_tools.version,
            )
            break

    mod = module_ctx.modules[0]
    for toolchain in mod.tags.toolchain:
        rust_register_toolchains(
            dev_components = toolchain.dev_components,
            edition = toolchain.edition,
            allocator_library = toolchain.allocator_library,
            rustfmt_version = toolchain.rustfmt_version,
            rust_analyzer_version = toolchain.rust_analyzer_version,
            sha256s = toolchain.sha256s,
            extra_target_triples = toolchain.extra_target_triples,
            urls = toolchain.urls,
            versions = toolchain.versions,
            register_toolchains = False,
        )

_COMMON_TAG_KWARGS = dict(
    allocator_library = attr.string(default = "@rules_rust//ffi/cc/allocator_library"),
    dev_components = attr.bool(default = False),
    edition = attr.string(),
    rustfmt_version = attr.string(default = DEFAULT_NIGHTLY_VERSION),
    sha256s = attr.string_dict(),
    urls = attr.string_list(default = DEFAULT_STATIC_RUST_URL_TEMPLATES),
)

_RUST_TOOLCHAIN_TAG = tag_class(attrs = dict(
    extra_target_triples = attr.string_list(default = DEFAULT_EXTRA_TARGET_TRIPLES),
    rust_analyzer_version = attr.string(),
    versions = attr.string_list(default = []),
    **_COMMON_TAG_KWARGS
))

_RUST_HOST_TOOLS_TAG = tag_class(attrs = dict(
    version = attr.string(default = rust_common.default_version),
    **_COMMON_TAG_KWARGS
))

rust = module_extension(
    implementation = _rust_impl,
    tag_classes = {
        "host_tools": _RUST_HOST_TOOLS_TAG,
        "toolchain": _RUST_TOOLCHAIN_TAG,
    },
)
