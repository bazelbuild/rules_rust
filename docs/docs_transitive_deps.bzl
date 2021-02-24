"""Define transitive dependencies for `rules_rust` docs"""

load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("@build_bazel_rules_nodejs//:index.bzl", "node_repositories")
load("@rules_rust//proto:repositories.bzl", "rust_proto_repositories")

def transitive_deps(is_top_level = False):
    """Define transitive dependencies for `rules_rust` docs

    Args:
        is_top_level (bool, optional): Indicates wheather or not this is being called
            from the root WORKSPACE file of `rules_rust`. Defaults to False.
    """
    rust_proto_repositories()

    node_repositories()

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
