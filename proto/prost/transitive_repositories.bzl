"""Definitions for loading transitive `@rules_rust//proto` dependencies"""

load("@com_google_protobuf//:protobuf_deps.bzl", "protobuf_deps")
load("@rules_proto//proto:repositories.bzl", "rules_proto_dependencies", "rules_proto_toolchains")

def rust_prost_transitive_repositories():
    """Load transitive dependencies of the `@rules_rust//proto` rules.

    This macro should be called immediately after the `rust_proto_dependencies` macro.
    """
    rules_proto_dependencies()

    rules_proto_toolchains()

    protobuf_deps()
