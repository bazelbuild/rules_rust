"""Define repository dependencies for `rules_rust` examples"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def repositories():
    """Define repository dependencies for `rules_rust` examples"""
    maybe(
        native.local_repository,
        name = "rules_rust",
        path = "..",
    )

    maybe(
        http_archive,
        name = "rules_foreign_cc",
        strip_prefix = "rules_foreign_cc-d54c78ab86b40770ee19f0949db9d74a831ab9f0",
        url = "https://github.com/bazelbuild/rules_foreign_cc/archive/d54c78ab86b40770ee19f0949db9d74a831ab9f0.zip",
        sha256 = "3c6445404e9e5d17fa0ecdef61be00dd93b20222c11f45e146a98c0a3f67defa",
    )
