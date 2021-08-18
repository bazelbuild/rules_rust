"""A module defining the third party dependency OpenSSL

The code here was picked up from the `rules_foreign_cc` openssl example
https://github.com/bazelbuild/rules_foreign_cc/tree/0.5.1/examples/third_party/openssl
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def openssl_repositories():
    maybe(
        http_archive,
        name = "openssl",
        build_file = Label("//third_party/openssl:BUILD.openssl.bazel"),
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
        name = "nasm_windows",
        build_file = Label("//third_party/openssl:BUILD.nasm.bazel"),
        sha256 = "f5c93c146f52b4f1664fa3ce6579f961a910e869ab0dae431bd871bdd2584ef2",
        strip_prefix = "nasm-2.15.05",
        urls = [
            "https://mirror.bazel.build/www.nasm.us/pub/nasm/releasebuilds/2.15.05/win64/nasm-2.15.05-win64.zip",
            "https://www.nasm.us/pub/nasm/releasebuilds/2.15.05/win64/nasm-2.15.05-win64.zip",
        ],
    )

    maybe(
        http_archive,
        name = "perl_windows",
        build_file = Label("//third_party/openssl:BUILD.perl.bazel"),
        sha256 = "aeb973da474f14210d3e1a1f942dcf779e2ae7e71e4c535e6c53ebabe632cc98",
        urls = [
            "https://mirror.bazel.build/strawberryperl.com/download/5.32.1.1/strawberry-perl-5.32.1.1-64bit.zip",
            "https://strawberryperl.com/download/5.32.1.1/strawberry-perl-5.32.1.1-64bit.zip",
        ],
    )
