"""A module defining the third party dependency iconv"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def iconv_repositories():
    maybe(
        http_archive,
        name = "cargo_raze__iconv",
        urls = [
            "https://opensource.apple.com/tarballs/libiconv/libiconv-59.tar.gz",
        ],
        type = "tar.gz",
        sha256 = "f7729999a9f2adc8c158012bc4bc8d69bea5dec88c8203cdd62067f91ed60b43",
        strip_prefix = "libiconv-59/libiconv",
        build_file = Label("//third_party/iconv:BUILD.iconv.bazel"),
    )
