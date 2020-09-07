"""Define extra dependencies for `rules_rust` examples

There are some transitive dependencies of the dependencies of the examples' 
dependencies. This file contains the required macros to pull these dependencies
"""

load("@npm//:install_bazel_dependencies.bzl", "install_bazel_dependencies")

def extra_deps():
    """Define extra dependencies for `rules_rust` examples"""

    # Install all Bazel dependencies needed for npm packages that supply Bazel rules
    install_bazel_dependencies()
