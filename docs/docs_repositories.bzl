"""Define repository dependencies for `rules_rust` docs"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def repositories(is_top_level = False):
    """Define repository dependencies for `rules_rust` docs

    Args:
        is_top_level (bool, optional): Indicates wheather or not this is being called
            from the root WORKSPACE file of `rules_rust`. Defaults to False.
    """
    maybe(
        native.local_repository,
        name = "io_bazel_rules_rust",
        path = "..",
    )

    maybe(
        http_archive,
        name = "io_bazel_stardoc",
        urls = [
            "https://github.com/bazelbuild/stardoc/archive/a0f330bcbae44ffc59d50a86a830a661b8d18acc.zip",
        ],
        sha256 = "e12831c6c414325c99325726dd26dabd8ed4c9efa7b4f27b4d1d9594ec7dfc40",
        strip_prefix = "stardoc-a0f330bcbae44ffc59d50a86a830a661b8d18acc",
    )
