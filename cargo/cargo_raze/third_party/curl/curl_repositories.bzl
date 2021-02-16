"""A module defining the third party dependency curl"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def curl_repositories():
    maybe(
        http_archive,
        name = "curl",
        urls = [
            "https://curl.se/download/curl-7.74.0.tar.gz",
            "https://github.com/curl/curl/releases/download/curl-7_74_0/curl-7.74.0.tar.gz",
        ],
        type = "tar.gz",
        sha256 = "e56b3921eeb7a2951959c02db0912b5fcd5fdba5aca071da819e1accf338bbd7",
        strip_prefix = "curl-7.74.0",
        build_file = Label("@cargo_raze//third_party/curl:BUILD.curl.bazel"),
    )

    maybe(
        http_archive,
        name = "boringssl",
        urls = [
            "https://github.com/google/boringssl/archive/bdbe37905216bea8dd4d0fdee93f6ee415d3aa15.zip",
        ],
        type = "zip",
        sha256 = "b2a7d159741008e61a1387ec6d93879539e8d7db055c769e4fefe9a371582e44",
        strip_prefix = "boringssl-bdbe37905216bea8dd4d0fdee93f6ee415d3aa15",
    )

    maybe(
        http_archive,
        name = "rules_foreign_cc",
        sha256 = "3c6445404e9e5d17fa0ecdef61be00dd93b20222c11f45e146a98c0a3f67defa",
        strip_prefix = "rules_foreign_cc-d54c78ab86b40770ee19f0949db9d74a831ab9f0",
        url = "https://github.com/bazelbuild/rules_foreign_cc/archive/d54c78ab86b40770ee19f0949db9d74a831ab9f0.zip",
    )
