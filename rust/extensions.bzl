"Module extensions for using rules_rust with bzlmod"

load("@bazel_features//:features.bzl", "bazel_features")
load("//rust:defs.bzl", "rust_common")
load("//rust:repositories.bzl", "rust_register_toolchains", "rust_toolchain_tools_repository")
load("//rust/platform:triple.bzl", "get_host_triple")
load(
    "//rust/private:repository_utils.bzl",
    "DEFAULT_EXTRA_TARGET_TRIPLES",
    "DEFAULT_NIGHTLY_VERSION",
    "DEFAULT_STATIC_RUST_URL_TEMPLATES",
)

_RUST_TOOLCHAIN_VERSIONS = [
    rust_common.default_version,
    DEFAULT_NIGHTLY_VERSION,
]

def _find_modules(module_ctx):
    root = None
    our_module = None
    for mod in module_ctx.modules:
        if mod.is_root:
            root = mod
        if mod.name == "rules_rust":
            our_module = mod
    if root == None:
        root = our_module
    if our_module == None:
        fail("Unable to find rules_rust module")

    return root, our_module

def _empty_repository_impl(repository_ctx):
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))
    repository_ctx.file("BUILD.bazel", "")

_empty_repository = repository_rule(
    doc = ("Declare an empty repository."),
    implementation = _empty_repository_impl,
)

def _rust_impl(module_ctx):
    # Toolchain configuration is only allowed in the root module, or in
    # rules_rust.
    # See https://github.com/bazelbuild/bazel/discussions/22024 for discussion.
    root, rules_rust = _find_modules(module_ctx)

    toolchains = root.tags.toolchain or rules_rust.tags.toolchain

    for toolchain in toolchains:
        if len(toolchain.versions) == 0:
            # If the root module has asked for rules_rust to not register default
            # toolchains, an empty repository named `rust_toolchains` is created
            # so that the `register_toolchains()` in MODULES.bazel is still
            # valid.
            _empty_repository(name = "rust_toolchains")
        else:
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
    allocator_library = attr.string(
        doc = "Target that provides allocator functions when rust_library targets are embedded in a cc_binary.",
        default = "@rules_rust//ffi/cc/allocator_library",
    ),
    dev_components = attr.bool(
        doc = "Whether to download the rustc-dev components (defaults to False). Requires version to be \"nightly\".",
        default = False,
    ),
    edition = attr.string(
        doc = (
            "The rust edition to be used by default (2015, 2018, or 2021). " +
            "If absent, every rule is required to specify its `edition` attribute."
        ),
    ),
    rustfmt_version = attr.string(
        doc = "The version of the tool among \"nightly\", \"beta\", or an exact version.",
        default = DEFAULT_NIGHTLY_VERSION,
    ),
    sha256s = attr.string_dict(
        doc = "A dict associating tool subdirectories to sha256 hashes. See [rust_repositories](#rust_repositories) for more details.",
    ),
    urls = attr.string_list(
        doc = "A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format).",
        default = DEFAULT_STATIC_RUST_URL_TEMPLATES,
    ),
)

_RUST_TOOLCHAIN_TAG = tag_class(
    attrs = dict(
        extra_target_triples = attr.string_list(
            default = DEFAULT_EXTRA_TARGET_TRIPLES,
        ),
        rust_analyzer_version = attr.string(
            doc = "The version of Rustc to pair with rust-analyzer.",
        ),
        versions = attr.string_list(
            doc = (
                "A list of toolchain versions to download. This paramter only accepts one versions " +
                "per channel. E.g. `[\"1.65.0\", \"nightly/2022-11-02\", \"beta/2020-12-30\"]`. " +
                "May be set to an empty list (`[]`) to inhibit `rules_rust` from registering toolchains."
            ),
            default = _RUST_TOOLCHAIN_VERSIONS,
        ),
        **_COMMON_TAG_KWARGS
    ),
)

_RUST_HOST_TOOLS_TAG = tag_class(
    attrs = dict(
        version = attr.string(
            default = rust_common.default_version,
            doc = "The version of Rust to use for tools executed on the Bazel host.",
        ),
        **_COMMON_TAG_KWARGS
    ),
)

rust = module_extension(
    implementation = _rust_impl,
    tag_classes = {
        "toolchain": _RUST_TOOLCHAIN_TAG,
    },
)

# This is a separate module extension so that only the host tools are
# marked as reproducible and os and arch dependent
def _rust_host_tools_impl(module_ctx):
    root, _ = _find_modules(module_ctx)

    if len(root.tags.host_tools) == 1:
        attrs = root.tags.host_tools[0]

        host_tools = {
            "allocator_library": attrs.allocator_library,
            "dev_components": attrs.dev_components,
            "edition": attrs.edition,
            "rustfmt_version": attrs.rustfmt_version,
            "sha256s": attrs.sha256s,
            "urls": attrs.urls,
            "version": attrs.version,
        }
    elif not root.tags.host_tools:
        host_tools = {
            "version": rust_common.default_version,
        }
    else:
        fail("Multiple host_tools were defined in your root MODULE.bazel")

    host_triple = get_host_triple(module_ctx)
    rust_toolchain_tools_repository(
        name = "rust_host_tools",
        exec_triple = host_triple.str,
        target_triple = host_triple.str,
        **host_tools
    )

    metadata_kwargs = {}
    if bazel_features.external_deps.extension_metadata_has_reproducible:
        metadata_kwargs["reproducible"] = True
    return module_ctx.extension_metadata(**metadata_kwargs)

_conditional_rust_host_tools_args = {
    "arch_dependent": True,
    "os_dependent": True,
} if bazel_features.external_deps.module_extension_has_os_arch_dependent else {}

rust_host_tools = module_extension(
    implementation = _rust_host_tools_impl,
    tag_classes = {
        "host_tools": _RUST_HOST_TOOLS_TAG,
    },
    **_conditional_rust_host_tools_args
)
