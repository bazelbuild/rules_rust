# buildifier: disable=module-docstring
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//sys/complex/raze:crates.bzl", "rules_rust_examples_complex_sys_fetch_remote_crates")

def rules_rust_examples_complex_sys_repositories():
    """Define repository dependencies for the `complex_sys` example"""

    rules_rust_examples_complex_sys_fetch_remote_crates()

    maybe(
        http_archive,
        name = "openssl",
        strip_prefix = "openssl-OpenSSL_1_1_1d",
        urls = ["https://github.com/openssl/openssl/archive/OpenSSL_1_1_1d.tar.gz"],
        sha256 = "23011a5cc78e53d0dc98dfa608c51e72bcd350aa57df74c5d5574ba4ffb62e74",
        build_file = "@examples//third_party/openssl:BUILD.openssl.bazel",
    )
