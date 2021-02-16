"""A module defining the third party dependency libgit2"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def libgit2_repositories():
    maybe(
        http_archive,
        name = "libgit2",
        urls = [
            "https://github.com/libgit2/libgit2/releases/download/v1.1.0/libgit2-1.1.0.tar.gz",
        ],
        type = "tar.gz",
        sha256 = "ad73f845965cfd528e70f654e428073121a3fa0dc23caac81a1b1300277d4dba",
        strip_prefix = "libgit2-1.1.0",
        build_file = Label("@cargo_raze//third_party/libgit2:BUILD.libgit2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_foreign_cc",
        sha256 = "3c6445404e9e5d17fa0ecdef61be00dd93b20222c11f45e146a98c0a3f67defa",
        strip_prefix = "rules_foreign_cc-d54c78ab86b40770ee19f0949db9d74a831ab9f0",
        url = "https://github.com/bazelbuild/rules_foreign_cc/archive/d54c78ab86b40770ee19f0949db9d74a831ab9f0.zip",
    )
