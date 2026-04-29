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
        integrity = "sha256-c6Sw6ZWWoJ+lkkpPt+S5lahf2g0YosAquc8TS+vOBO4=",
        strip_prefix = "curl-8.10.1",
        type = "tar.xz",
        urls = [
            "https://curl.se/download/curl-8.10.1.tar.xz",
            "https://github.com/curl/curl/releases/download/curl-8_10_1/curl-8.10.1.tar.xz",
        ],
    )
