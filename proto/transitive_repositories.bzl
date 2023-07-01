"""Definitions for loading transitive `@rules_rust//proto` dependencies"""

load("//proto/protobuf:transitive_repositories.bzl", "rust_proto_protobuf_transitive_repositories")

def rust_proto_transitive_repositories():
    """Load rust_protobuf transitive dependencies.

    Deprecated:
        Instead call `@rules_rust//proto/protobuf:transitive_repositories.bzl%rust_protobuf_transitive_repositories`
    """
    rust_proto_protobuf_transitive_repositories()
