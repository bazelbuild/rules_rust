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
            "https://github.com/bazelbuild/stardoc/archive/1ef781ced3b1443dca3ed05dec1989eca1a4e1cd.zip",
        ],
        sha256 = "5d7191bb0800434a9192d8ac80cba4909e96dbb087c5d51f168fedd7bde7b525",
        strip_prefix = "stardoc-1ef781ced3b1443dca3ed05dec1989eca1a4e1cd",
    )

    maybe(
        http_archive,
        name = "rules_python",
        url = "https://github.com/bazelbuild/rules_python/releases/download/0.1.0/rules_python-0.1.0.tar.gz",
        sha256 = "b6d46438523a3ec0f3cead544190ee13223a52f6a6765a29eae7b7cc24cc83a0",
    )
