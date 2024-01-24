"""
The dependencies for running the gen_rust_project binary.
"""

load("//tools/runfiles/3rdparty/crates:defs.bzl", "crate_repositories")

def runfiles_dependencies():
    """Define dependencies of the `runfiles` Bazel tools"""
    return crate_repositories()

runfiles_deps = runfiles_dependencies
