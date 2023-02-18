"Module extensions for using rules_rust with bzlmod"

load("//rust:repositories.bzl", "rust_register_toolchains")
load(
    "//rust/private:repository_utils.bzl",
    "DEFAULT_EXTRA_TARGET_TRIPLES",
    "DEFAULT_NIGHTLY_VERSION",
    "DEFAULT_STATIC_RUST_URL_TEMPLATES",
)

def _toolchains_impl(ctx):
    mod = ctx.modules[0]
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

toolchains_toolchain = tag_class(attrs = {
    "dev_components": attr.bool(default = False),
    "edition": attr.string(),
    "allocator_library": attr.string(),
    "rustfmt_version": attr.string(default = DEFAULT_NIGHTLY_VERSION),
    "rust_analyzer_version": attr.string(),
    "sha256s": attr.string_dict(),
    "extra_target_triples": attr.string_list(default = DEFAULT_EXTRA_TARGET_TRIPLES),
    "urls": attr.string_list(default = DEFAULT_STATIC_RUST_URL_TEMPLATES),
    "versions": attr.string_list(default = []),
})
toolchains = module_extension(
    implementation = _toolchains_impl,
    tag_classes = {"toolchain": toolchains_toolchain},
)
