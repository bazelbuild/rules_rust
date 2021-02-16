"""A module for defining the transitive dependnecies of cargo-raze. This would be
the dependencies of the thrid party dependencies"""

load("//third_party/curl:curl_deps.bzl", "curl_deps")
load("//third_party/iconv:iconv_deps.bzl", "iconv_deps")
load("//third_party/libgit2:libgit2_deps.bzl", "libgit2_deps")
load("//third_party/libssh2:libssh2_deps.bzl", "libssh2_deps")
load("//third_party/openssl:openssl_deps.bzl", "openssl_deps")
load("//third_party/pcre:pcre_deps.bzl", "pcre_deps")

def third_party_deps():
    """Defines the necessary dependencies of each third party dependenciy"""
    curl_deps()
    iconv_deps()
    libgit2_deps()
    libssh2_deps()
    openssl_deps()
    pcre_deps()
