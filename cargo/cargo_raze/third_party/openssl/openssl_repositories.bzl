"""A module defining the third party dependency OpenSSL"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def openssl_repositories():
    maybe(
        http_archive,
        name = "cargo_raze__openssl",
        build_file = Label("//third_party/openssl:BUILD.openssl.bazel"),
        sha256 = "5c9ca8774bd7b03e5784f26ae9e9e6d749c9da2438545077e6b3d755a06595d9",
        strip_prefix = "openssl-1.1.1h",
        urls = [
            "https://www.openssl.org/source/openssl-1.1.1h.tar.gz",
            "https://github.com/openssl/openssl/archive/OpenSSL_1_1_1h.tar.gz",
        ],
    )
