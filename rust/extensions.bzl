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

_HOST_TOOL_ERR = """When %s, host tools must be explicitly defined. For example:

rust = use_extension("@rules_rust//rust:extensions.bzl", "rust")
rust.host_tools(
    edition = "2021",
    version = "1.70.2",
)
"""

_EXAMPLE_TOOLCHAIN = """
rust = use_extension("@rules_rust//rust:extensions.bzl", "rust")
rust.toolchain(
    edition = "2021",
    versions = ["1.70.2"],
)
use_repo(rust, "rust_toolchains")
register_toolchains("@rust_toolchains//:all")"""

_TRANSITIVE_DEP_ERR = """
Your transitive dependency %s is using rules_rust, so you need to define a rust toolchain.
To do so, you will need to add the following to your root MODULE.bazel. For example:

bazel_dep(name = "rules_rust", version = "<rules_rust version>")
""" + _EXAMPLE_TOOLCHAIN

_TOOLCHAIN_ERR = """
Please add at least one toolchain to your root MODULE.bazel. For example:
""" + _EXAMPLE_TOOLCHAIN

def _rust_impl(module_ctx):
    # Toolchain configuration is only allowed in the root module.
    # It would be very confusing (and a security concern) if I was using the
    # default rust toolchains, then when I added a module built on rust, I was
    # suddenly using a custom rustc.
    root = None
    for mod in module_ctx.modules:
        if mod.is_root:
            root = mod
    if not root:
        fail(_TRANSITIVE_DEP_ERR % module_ctx.modules[0].name)

    toolchains = root.tags.toolchain
    if not toolchains:
        fail(_TOOLCHAIN_ERR)

    if len(root.tags.host_tools) == 1:
        host_tools = root.tags.host_tools[0]
    elif not root.tags.host_tools:
        if len(toolchains) != 1:
            fail(_HOST_TOOL_ERR % "multiple toolchains are provided")
        toolchain = toolchains[0]
        if len(toolchain.versions) == 1:
            version = toolchain.versions[0]
        elif not toolchain.versions:
            version = None
        else:
            fail(_HOST_TOOL_ERR % "multiple toolchain versions are provided")
        host_tools = struct(
            allocator_library = toolchain.allocator_library,
            dev_components = toolchain.dev_components,
            edition = toolchain.edition,
            rustfmt_version = toolchain.rustfmt_version,
            sha256s = toolchain.sha256s,
            urls = toolchain.urls,
            version = version,
        )
    else:
        fail("Multiple host_tools were defined in your root MODULE.bazel")

    host_triple = get_host_triple(module_ctx)

    iso_date = None
    version = host_tools.version or rust_common.default_version

    # Any version containing a slash is expected to be a nightly/beta release with iso date. E.g. `nightly/2024-03-21`
    if "/" in version:
        version, _, iso_date = version.partition("/")

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
        version = version,
        iso_date = iso_date,
    )

    for toolchain in toolchains:
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
                "per channel. E.g. `[\"1.65.0\", \"nightly/2022-11-02\", \"beta/2020-12-30\"]`."
            ),
            default = [],
        ),
        **_COMMON_TAG_KWARGS
    ),
)

_RUST_HOST_TOOLS_TAG = tag_class(
    attrs = dict(
        version = attr.string(
            doc = "The version of Rust to use for tools executed on the Bazel host.",
        ),
        **_COMMON_TAG_KWARGS
    ),
)

rust = module_extension(
    implementation = _rust_impl,
    tag_classes = {
        "host_tools": _RUST_HOST_TOOLS_TAG,
        "toolchain": _RUST_TOOLCHAIN_TAG,
    },
)
