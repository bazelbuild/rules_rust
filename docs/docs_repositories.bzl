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
        name = "rules_rust",
        path = "..",
    )

    maybe(
        http_archive,
        name = "io_bazel_stardoc",
        urls = [
            "https://github.com/bazelbuild/stardoc/archive/d93ee5347e2d9c225ad315094507e018364d5a67.zip",
        ],
        sha256 = "ff10a8b1503f5606fab5aa5bc9ae267272c023af7789f03caef95b5ab3fe0df2",
        strip_prefix = "stardoc-d93ee5347e2d9c225ad315094507e018364d5a67",
    )
