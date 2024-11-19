"""Definitions for loading transitive `@rules_rust//proto` dependencies"""

load("@rules_proto//proto:repositories.bzl", "rules_proto_dependencies")

def rust_prost_transitive_repositories():
    """Load transitive dependencies of the `@rules_rust//proto` rules.

    This macro should be called immediately after the `rust_proto_dependencies` macro.
    """
    rules_proto_dependencies()
