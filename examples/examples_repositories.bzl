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
        sha256 = "379b1cd5cd13da154ba99df3aeb91f9cbb81910641fc520bb90f2a95e324353d",
        strip_prefix = "rules_foreign_cc-689c96aaa7337eb129235e5388f4ebc88fa14e87",
        urls = [
            "https://github.com/bazelbuild/rules_foreign_cc/archive/689c96aaa7337eb129235e5388f4ebc88fa14e87.zip",
        ],
    )
