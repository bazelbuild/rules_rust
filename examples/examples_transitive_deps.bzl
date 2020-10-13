"""Define transitive dependencies for `rules_rust` examples

There are some transitive dependencies of the dependencies of the examples' 
dependencies. This file contains the required macros to pull these dependencies
"""

load("@io_bazel_rules_rust//:workspace.bzl", "rust_workspace")
load("@npm//:install_bazel_dependencies.bzl", "install_bazel_dependencies")
load("@rules_proto//proto:repositories.bzl", "rules_proto_dependencies", "rules_proto_toolchains")

def transitive_deps():
    """Define transitive dependencies for `rules_rust` examples"""

    rules_proto_dependencies()

    rules_proto_toolchains()

    rust_workspace()

    # Install all Bazel dependencies needed for npm packages that supply Bazel rules
    install_bazel_dependencies()
