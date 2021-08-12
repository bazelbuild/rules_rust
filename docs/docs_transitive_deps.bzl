"""Define transitive dependencies for `rules_rust` docs"""

load("@build_bazel_rules_nodejs//:index.bzl", "node_repositories")
load("@rules_rust//proto:transitive_repositories.bzl", "rust_proto_transitive_repositories")

def transitive_deps():
    """Define transitive dependencies for `rules_rust` docs
    """
    rust_proto_transitive_repositories()

    node_repositories()
