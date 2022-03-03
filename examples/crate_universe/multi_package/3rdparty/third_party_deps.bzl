"""A helper module for loading 3rd party dependencies
The sources here originate from: https://github.com/bazelbuild/rules_foreign_cc/tree/0.6.0/examples/third_party/openssl
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def third_party_deps(prefix = ""):
    """Definitions for 3rd party dependencies

    Args:
        prefix (str, optional): An optional prefix for all dependencies
    """
    maybe(
        http_archive,
        name = (prefix + "__" + "openssl").lstrip("_"),
        build_file = Label("//multi_package/3rdparty:BUILD.openssl.bazel"),
        sha256 = "892a0875b9872acd04a9fde79b1f943075d5ea162415de3047c327df33fbaee5",
        strip_prefix = "openssl-1.1.1k",
        urls = [
            "https://mirror.bazel.build/www.openssl.org/source/openssl-1.1.1k.tar.gz",
            "https://www.openssl.org/source/openssl-1.1.1k.tar.gz",
            "https://github.com/openssl/openssl/archive/OpenSSL_1_1_1k.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = (prefix + "__" + "nasm").lstrip("_"),
        build_file = Label("//multi_package/3rdparty:BUILD.nasm.bazel"),
        sha256 = "f5c93c146f52b4f1664fa3ce6579f961a910e869ab0dae431bd871bdd2584ef2",
        strip_prefix = "nasm-2.15.05",
        urls = [
            "https://mirror.bazel.build/www.nasm.us/pub/nasm/releasebuilds/2.15.05/win64/nasm-2.15.05-win64.zip",
            "https://www.nasm.us/pub/nasm/releasebuilds/2.15.05/win64/nasm-2.15.05-win64.zip",
        ],
    )

    maybe(
        http_archive,
        name = (prefix + "__" + "perl").lstrip("_"),
        build_file = Label("//multi_package/3rdparty:BUILD.perl.bazel"),
        sha256 = "aeb973da474f14210d3e1a1f942dcf779e2ae7e71e4c535e6c53ebabe632cc98",
        urls = [
            "https://mirror.bazel.build/strawberryperl.com/download/5.32.1.1/strawberry-perl-5.32.1.1-64bit.zip",
            "https://strawberryperl.com/download/5.32.1.1/strawberry-perl-5.32.1.1-64bit.zip",
        ],
    )

    maybe(
        http_archive,
        name = (prefix + "__" + "curl").lstrip("_"),
        build_file = Label("//multi_package/3rdparty:BUILD.curl.bazel"),
        sha256 = "e56b3921eeb7a2951959c02db0912b5fcd5fdba5aca071da819e1accf338bbd7",
        strip_prefix = "curl-7.74.0",
        type = "tar.gz",
        urls = [
            "https://curl.se/download/curl-7.74.0.tar.gz",
            "https://github.com/curl/curl/releases/download/curl-7_74_0/curl-7.74.0.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = (prefix + "__" + "zlib").lstrip("_"),
        build_file = Label("@cargo_bazel//3rdparty:BUILD.zlib.bazel"),
        sha256 = "c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1",
        strip_prefix = "zlib-1.2.11",
        urls = [
            "https://zlib.net/zlib-1.2.11.tar.gz",
            "https://storage.googleapis.com/mirror.tensorflow.org/zlib.net/zlib-1.2.11.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = (prefix + "__" + "libssh2").lstrip("_"),
        build_file = Label("//multi_package/3rdparty:BUILD.libssh2.bazel"),
        sha256 = "d5fb8bd563305fd1074dda90bd053fb2d29fc4bce048d182f96eaa466dfadafd",
        strip_prefix = "libssh2-1.9.0",
        type = "tar.gz",
        urls = [
            "https://github.com/libssh2/libssh2/releases/download/libssh2-1.9.0/libssh2-1.9.0.tar.gz",
        ],
    )
