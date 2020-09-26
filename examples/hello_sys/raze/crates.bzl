"""
@generated
cargo-raze crate workspace functions

DO NOT EDIT! Replaced on runs of cargo-raze
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

def rules_rust_examples_hello_sys_fetch_remote_crates():
    """This function defines a collection of repos and should be called in a WORKSPACE file"""
    maybe(
        http_archive,
        name = "rules_rust_examples_hello_sys__bzip2__0_3_3",
        url = "https://crates.io/api/v1/crates/bzip2/0.3.3/download",
        type = "tar.gz",
        sha256 = "42b7c3cbf0fa9c1b82308d57191728ca0256cb821220f4e2fd410a72ade26e3b",
        strip_prefix = "bzip2-0.3.3",
        build_file = Label("//hello_sys/raze/remote:bzip2-0.3.3.BUILD.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_hello_sys__bzip2_sys__0_1_9_1_0_8",
        url = "https://crates.io/api/v1/crates/bzip2-sys/0.1.9+1.0.8/download",
        type = "tar.gz",
        sha256 = "ad3b39a260062fca31f7b0b12f207e8f2590a67d32ec7d59c20484b07ea7285e",
        strip_prefix = "bzip2-sys-0.1.9+1.0.8",
        build_file = Label("//hello_sys/raze/remote:bzip2-sys-0.1.9+1.0.8.BUILD.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_hello_sys__cc__1_0_60",
        url = "https://crates.io/api/v1/crates/cc/1.0.60/download",
        type = "tar.gz",
        sha256 = "ef611cc68ff783f18535d77ddd080185275713d852c4f5cbb6122c462a7a825c",
        strip_prefix = "cc-1.0.60",
        build_file = Label("//hello_sys/raze/remote:cc-1.0.60.BUILD.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_hello_sys__libc__0_2_77",
        url = "https://crates.io/api/v1/crates/libc/0.2.77/download",
        type = "tar.gz",
        sha256 = "f2f96b10ec2560088a8e76961b00d47107b3a625fecb76dedb29ee7ccbf98235",
        strip_prefix = "libc-0.2.77",
        build_file = Label("//hello_sys/raze/remote:libc-0.2.77.BUILD.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_hello_sys__pkg_config__0_3_18",
        url = "https://crates.io/api/v1/crates/pkg-config/0.3.18/download",
        type = "tar.gz",
        sha256 = "d36492546b6af1463394d46f0c834346f31548646f6ba10849802c9c9a27ac33",
        strip_prefix = "pkg-config-0.3.18",
        build_file = Label("//hello_sys/raze/remote:pkg-config-0.3.18.BUILD.bazel"),
    )
