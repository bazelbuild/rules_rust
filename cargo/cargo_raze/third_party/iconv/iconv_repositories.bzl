"""A module defining the third party dependency iconv"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def iconv_repositories():
    maybe(
        http_archive,
        name = "iconv",
        urls = [
            "https://opensource.apple.com/tarballs/libiconv/libiconv-59.tar.gz",
        ],
        type = "tar.gz",
        sha256 = "f7729999a9f2adc8c158012bc4bc8d69bea5dec88c8203cdd62067f91ed60b43",
        strip_prefix = "libiconv-59/libiconv",
        build_file = Label("@cargo_raze//third_party/iconv:BUILD.iconv.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_foreign_cc",
        sha256 = "3c6445404e9e5d17fa0ecdef61be00dd93b20222c11f45e146a98c0a3f67defa",
        strip_prefix = "rules_foreign_cc-d54c78ab86b40770ee19f0949db9d74a831ab9f0",
        url = "https://github.com/bazelbuild/rules_foreign_cc/archive/d54c78ab86b40770ee19f0949db9d74a831ab9f0.zip",
    )
