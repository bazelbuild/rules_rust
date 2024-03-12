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

def _find_root(module_ctx):
    root = None
    for mod in module_ctx.modules:
        if mod.is_root:
            root = mod

    return root

def _rust_impl(module_ctx):
    # Toolchain configuration is only allowed in the root module.
    # It would be very confusing (and a security concern) if I was using the
    # default rust toolchains, then when I added a module built on rust, I was
    # suddenly using a custom rustc.
    root = _find_root(module_ctx)

    if not root:
        fail(_TRANSITIVE_DEP_ERR % module_ctx.modules[0].name)

    toolchains = root.tags.toolchain
    if not toolchains:
        fail(_TOOLCHAIN_ERR)

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
        "toolchain": _RUST_TOOLCHAIN_TAG,
    },
)

# This is a separate module extension so that only the host tools are
# marked as reproducible and os and arch dependent
def _rust_host_tools_impl(module_ctx):
    root = _find_root(module_ctx)

    if root != None and len(root.tags.host_tools) == 1:
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
    elif root == None or not root.tags.host_tools:
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

    return module_ctx.extension_metadata(reproducible = True)

rust_host_tools = module_extension(
    implementation = _rust_host_tools_impl,
    tag_classes = {
        "host_tools": _RUST_HOST_TOOLS_TAG,
    },
    os_dependent = True,
    arch_dependent = True,
)
