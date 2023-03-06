"""A helper module for loading 3rd party dependencies of
the "multi package" Crate Universe examples.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def third_party_deps(prefix):
    maybe(
        http_archive,
        name = "{}__curl".format(prefix),
        build_file = Label("//multi_package/3rdparty:BUILD.curl.bazel"),
        sha256 = "cdb38b72e36bc5d33d5b8810f8018ece1baa29a8f215b4495e495ded82bbf3c7",
        strip_prefix = "curl-7.88.1",
        type = "tar.gz",
        urls = [
            "https://curl.se/download/curl-7.88.1.tar.gz",
            "https://github.com/curl/curl/releases/download/curl-7_88_1/curl-7.88.1.tar.gz",
        ],
    )
