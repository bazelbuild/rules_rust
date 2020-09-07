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
        name = "bazel_skylib",
        sha256 = "1c531376ac7e5a180e0237938a2536de0c54d93f5c278634818e0efc952dd56c",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz",
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "io_bazel_stardoc",
        urls = [
            "https://github.com/bazelbuild/stardoc/archive/1ef781ced3b1443dca3ed05dec1989eca1a4e1cd.zip",
        ],
        sha256 = "5d7191bb0800434a9192d8ac80cba4909e96dbb087c5d51f168fedd7bde7b525",
        strip_prefix = "stardoc-1ef781ced3b1443dca3ed05dec1989eca1a4e1cd",
    )
