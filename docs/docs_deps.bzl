"""Define dependencies for `rules_rust` docs"""

load("@io_bazel_rules_rust//rust:repositories.bzl", "rust_repositories")
load("@io_bazel_rules_rust//proto:repositories.bzl", "rust_proto_repositories")
load("@io_bazel_rules_rust//:workspace.bzl", "bazel_version")
load("@io_bazel_stardoc//:setup.bzl", "stardoc_repositories")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def deps(is_top_level = False):
    """Define dependencies for `rules_rust` docs

    Args:
        is_top_level (bool, optional): Indicates wheather or not this is being called
            from the root WORKSPACE file of `rules_rust`. Defaults to False.
    """
    rust_repositories()
    rust_proto_repositories()
    bazel_version(name = "bazel_version")
    stardoc_repositories()

    # Rules proto does not declare a bzl_library, we stub it there for now.
    # TODO: Remove this hack if/when rules_proto adds a bzl_library.
    if is_top_level:
        maybe(
            native.local_repository,
            name = "rules_proto",
            path = "docs/rules_proto_stub",
        )
    else:
        maybe(
            native.local_repository,
            name = "rules_proto",
            path = "rules_proto_stub",
        )
