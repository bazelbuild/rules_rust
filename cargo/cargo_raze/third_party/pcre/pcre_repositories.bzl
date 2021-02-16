"""A module defining the third party dependency PCRE"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def pcre_repositories():
    maybe(
        http_archive,
        name = "pcre",
        build_file = Label("//third_party/pcre:BUILD.pcre.bazel"),
        strip_prefix = "pcre-8.43",
        urls = [
            "https://mirror.bazel.build/ftp.pcre.org/pub/pcre/pcre-8.43.tar.gz",
            "https://ftp.pcre.org/pub/pcre/pcre-8.43.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "rules_foreign_cc",
        sha256 = "3c6445404e9e5d17fa0ecdef61be00dd93b20222c11f45e146a98c0a3f67defa",
        strip_prefix = "rules_foreign_cc-d54c78ab86b40770ee19f0949db9d74a831ab9f0",
        url = "https://github.com/bazelbuild/rules_foreign_cc/archive/d54c78ab86b40770ee19f0949db9d74a831ab9f0.zip",
    )
