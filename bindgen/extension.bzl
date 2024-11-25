"""Module extension for accessing a bindgen toolchain"""

load(":repositories.bzl", "rust_bindgen_dependencies")
load(":transitive_repositories.bzl", "rust_bindgen_transitive_dependencies")

def _bindgen_impl(_):
    rust_bindgen_transitive_dependencies(repo_mapping = None)
    rust_bindgen_dependencies()
    bindgen_toolchains(
        name = "bindgen_toolchains",
        build_file = "//bindgen/toolchain:BUILD.bazel",
    )

bindgen = module_extension(implementation = _bindgen_impl)

def _bindgen_toolchains_impl(rctx):
    if (rctx.attr.build_file == None) == (rctx.attr.build_file_content == "_UNSET"):
        fail("exactly one of `build_file` or `build_file_content` must be specified")

    if rctx.attr.build_file != None:
        rctx.file("BUILD.bazel", rctx.read(rctx.attr.build_file))
    else:
        rctx.file("BUILD.bazel", rctx.attr.build_file_content)

bindgen_toolchains = repository_rule(
    implementation = _bindgen_toolchains_impl,
    attrs = {
        "build_file": attr.label(
            doc =
                "A file to use as a BUILD file for this repo." +
                "<p>Exactly one of <code>build_file</code> or <code>build_file_content</code>" +
                "must be specified.",
        ),
        "build_file_content": attr.string(
            doc =
                "The content of a BUILD file to be created for this repo." +
                "<p>Exactly one of <code>build_file</code> or <code>build_file_content</code>" +
                "must be specified.",
            default = "_UNSET",
        ),
    },
    doc =
        "Creates a local repository containing a provided BUILD file to be used for defining " +
        "bindgen toolchains." +
        "<p>This rule is a replacement for the <code>local_repository</code> rule available " +
        "in later supported versions of Bazel.",
)
