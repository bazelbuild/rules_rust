"""Dependencies for the `@rules_rust_examples//sys` package"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//sys/basic/3rdparty/crates:defs.bzl", basic_crate_repositories = "crate_repositories")
load("//sys/complex/3rdparty/crates:defs.bzl", complex_crate_repositories = "crate_repositories")
load("//third_party/openssl:openssl_repositories.bzl", "openssl_repositories")

def sys_deps():
    """This macro loads dependencies for the `sys` crate examples

    Commonly `*-sys` crates are built on top of some existing library and
    will have a number of dependencies. The examples here use
    [crate_universe](https://bazelbuild.github.io/rules_rust/crate_universe.html)
    to gather these dependencies and make them avaialble in the workspace.
    """

    # Required by `//sys/complex`
    openssl_repositories()

    basic_crate_repositories()
    complex_crate_repositories()

    maybe(
        http_archive,
        name = "zlib",
        build_file = Label("//sys/complex/3rdparty:BUILD.zlib.bazel"),
        sha256 = "c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1",
        strip_prefix = "zlib-1.2.11",
        urls = [
            "https://zlib.net/zlib-1.2.11.tar.gz",
            "https://storage.googleapis.com/mirror.tensorflow.org/zlib.net/zlib-1.2.11.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "libgit2",
        build_file = Label("//sys/complex/3rdparty:BUILD.libgit2.bazel"),
        sha256 = "d25866a4ee275a64f65be2d9a663680a5cf1ed87b7ee4c534997562c828e500d",
        # The version here should match the version used with the Rust crate `libgit2-sys`
        # https://github.com/rust-lang/git2-rs/tree/libgit2-sys-0.15.2+1.6.4/libgit2-sys
        strip_prefix = "libgit2-1.6.4",
        urls = ["https://github.com/libgit2/libgit2/archive/refs/tags/v1.6.4.tar.gz"],
    )
