"""A module defining the third party dependency libgit2"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def libgit2_repositories():
    maybe(
        http_archive,
        name = "cargo_raze__libgit2",
        urls = [
            "https://github.com/libgit2/libgit2/releases/download/v1.1.0/libgit2-1.1.0.tar.gz",
        ],
        type = "tar.gz",
        sha256 = "ad73f845965cfd528e70f654e428073121a3fa0dc23caac81a1b1300277d4dba",
        strip_prefix = "libgit2-1.1.0",
        build_file = Label("//third_party/libgit2:BUILD.libgit2.bazel"),
    )
