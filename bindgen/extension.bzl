"""Module extension for accessing a bindgen toolchain"""

load(":repositories.bzl", "rust_bindgen_dependencies")
load(":transitive_repositories.bzl", "rust_bindgen_transitive_dependencies")

def _bindgen_impl(_):
    rust_bindgen_transitive_dependencies()
    rust_bindgen_dependencies()
    bindgen_toolchains(
        name = "bindgen_toolchains",
        build = "//bindgen/toolchain:BUILD.bazel",
    )

bindgen = module_extension(implementation = _bindgen_impl)

def _bindgen_toolchains_impl(ctx):
    ctx.file("BUILD.bazel", ctx.read(ctx.attr.build))

bindgen_toolchains = repository_rule(
    implementation = _bindgen_toolchains_impl,
    attrs = {
        "build": attr.label(mandatory = True),
    },
)
