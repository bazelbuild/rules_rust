"""Define dependencies for `rules_rust` docs"""

load("@io_bazel_stardoc//:setup.bzl", "stardoc_repositories")
load("@rules_rust//rust:repositories.bzl", "rust_repositories")

def deps():
    """Define dependencies for `rules_rust` docs"""
    rust_repositories()

    stardoc_repositories()
