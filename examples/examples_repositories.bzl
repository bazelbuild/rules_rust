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
        name = "rules_proto",
        sha256 = "602e7161d9195e50246177e7c55b2f39950a9cf7366f74ed5f22fd45750cd208",
        strip_prefix = "rules_proto-97d8af4dc474595af3900dd85cb3a29ad28cc313",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_proto/archive/97d8af4dc474595af3900dd85cb3a29ad28cc313.tar.gz",
            "https://github.com/bazelbuild/rules_proto/archive/97d8af4dc474595af3900dd85cb3a29ad28cc313.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "rules_foreign_cc",
        strip_prefix = "rules_foreign_cc-d54c78ab86b40770ee19f0949db9d74a831ab9f0",
        url = "https://github.com/bazelbuild/rules_foreign_cc/archive/d54c78ab86b40770ee19f0949db9d74a831ab9f0.zip",
        sha256 = "3c6445404e9e5d17fa0ecdef61be00dd93b20222c11f45e146a98c0a3f67defa",
    )
