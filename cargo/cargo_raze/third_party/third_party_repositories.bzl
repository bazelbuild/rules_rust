"""A module for defining repositories cargo-raze depends on"""

load("@cargo_raze//third_party/cargo:crates.bzl", "cargo_raze_fetch_remote_crates")
load("@cargo_raze//third_party/curl:curl_repositories.bzl", "curl_repositories")
load("@cargo_raze//third_party/iconv:iconv_repositories.bzl", "iconv_repositories")
load("@cargo_raze//third_party/libgit2:libgit2_repositories.bzl", "libgit2_repositories")
load("@cargo_raze//third_party/libssh2:libssh2_repositories.bzl", "libssh2_repositories")
load("@cargo_raze//third_party/openssl:openssl_repositories.bzl", "openssl_repositories")
load("@cargo_raze//third_party/pcre:pcre_repositories.bzl", "pcre_repositories")
load("@cargo_raze//third_party/zlib:zlib_repositories.bzl", "zlib_repositories")

def third_party_repositories():
    """Creates repository definitions for all cargo-raze third party dependencies"""
    curl_repositories()
    iconv_repositories()
    libgit2_repositories()
    libssh2_repositories()
    openssl_repositories()
    pcre_repositories()
    zlib_repositories()

    cargo_raze_fetch_remote_crates()
