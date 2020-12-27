"""
@generated
cargo-raze crate workspace functions

DO NOT EDIT! Replaced on runs of cargo-raze
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

def rules_rust_examples_complex_sys_fetch_remote_crates():
    """This function defines a collection of repos and should be called in a WORKSPACE file"""
    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__autocfg__1_0_1",
        url = "https://crates.io/api/v1/crates/autocfg/1.0.1/download",
        type = "tar.gz",
        strip_prefix = "autocfg-1.0.1",
        build_file = Label("//complex_sys/raze/remote:BUILD.autocfg-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__bitflags__1_2_1",
        url = "https://crates.io/api/v1/crates/bitflags/1.2.1/download",
        type = "tar.gz",
        strip_prefix = "bitflags-1.2.1",
        build_file = Label("//complex_sys/raze/remote:BUILD.bitflags-1.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__cc__1_0_61",
        url = "https://crates.io/api/v1/crates/cc/1.0.61/download",
        type = "tar.gz",
        strip_prefix = "cc-1.0.61",
        build_file = Label("//complex_sys/raze/remote:BUILD.cc-1.0.61.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__cfg_if__0_1_10",
        url = "https://crates.io/api/v1/crates/cfg-if/0.1.10/download",
        type = "tar.gz",
        strip_prefix = "cfg-if-0.1.10",
        build_file = Label("//complex_sys/raze/remote:BUILD.cfg-if-0.1.10.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__git2__0_13_12",
        url = "https://crates.io/api/v1/crates/git2/0.13.12/download",
        type = "tar.gz",
        strip_prefix = "git2-0.13.12",
        build_file = Label("//complex_sys/raze/remote:BUILD.git2-0.13.12.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__idna__0_2_0",
        url = "https://crates.io/api/v1/crates/idna/0.2.0/download",
        type = "tar.gz",
        strip_prefix = "idna-0.2.0",
        build_file = Label("//complex_sys/raze/remote:BUILD.idna-0.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__jobserver__0_1_21",
        url = "https://crates.io/api/v1/crates/jobserver/0.1.21/download",
        type = "tar.gz",
        strip_prefix = "jobserver-0.1.21",
        build_file = Label("//complex_sys/raze/remote:BUILD.jobserver-0.1.21.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__libc__0_2_80",
        url = "https://crates.io/api/v1/crates/libc/0.2.80/download",
        type = "tar.gz",
        strip_prefix = "libc-0.2.80",
        build_file = Label("//complex_sys/raze/remote:BUILD.libc-0.2.80.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__libgit2_sys__0_12_14_1_1_0",
        url = "https://crates.io/api/v1/crates/libgit2-sys/0.12.14+1.1.0/download",
        type = "tar.gz",
        strip_prefix = "libgit2-sys-0.12.14+1.1.0",
        build_file = Label("//complex_sys/raze/remote:BUILD.libgit2-sys-0.12.14+1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__libssh2_sys__0_2_19",
        url = "https://crates.io/api/v1/crates/libssh2-sys/0.2.19/download",
        type = "tar.gz",
        strip_prefix = "libssh2-sys-0.2.19",
        build_file = Label("//complex_sys/raze/remote:BUILD.libssh2-sys-0.2.19.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__libz_sys__1_1_2",
        url = "https://crates.io/api/v1/crates/libz-sys/1.1.2/download",
        type = "tar.gz",
        strip_prefix = "libz-sys-1.1.2",
        build_file = Label("//complex_sys/raze/remote:BUILD.libz-sys-1.1.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__log__0_4_11",
        url = "https://crates.io/api/v1/crates/log/0.4.11/download",
        type = "tar.gz",
        strip_prefix = "log-0.4.11",
        build_file = Label("//complex_sys/raze/remote:BUILD.log-0.4.11.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__matches__0_1_8",
        url = "https://crates.io/api/v1/crates/matches/0.1.8/download",
        type = "tar.gz",
        strip_prefix = "matches-0.1.8",
        build_file = Label("//complex_sys/raze/remote:BUILD.matches-0.1.8.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__openssl_probe__0_1_2",
        url = "https://crates.io/api/v1/crates/openssl-probe/0.1.2/download",
        type = "tar.gz",
        strip_prefix = "openssl-probe-0.1.2",
        build_file = Label("//complex_sys/raze/remote:BUILD.openssl-probe-0.1.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__openssl_sys__0_9_58",
        url = "https://crates.io/api/v1/crates/openssl-sys/0.9.58/download",
        type = "tar.gz",
        strip_prefix = "openssl-sys-0.9.58",
        build_file = Label("//complex_sys/raze/remote:BUILD.openssl-sys-0.9.58.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__percent_encoding__2_1_0",
        url = "https://crates.io/api/v1/crates/percent-encoding/2.1.0/download",
        type = "tar.gz",
        strip_prefix = "percent-encoding-2.1.0",
        build_file = Label("//complex_sys/raze/remote:BUILD.percent-encoding-2.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__pkg_config__0_3_19",
        url = "https://crates.io/api/v1/crates/pkg-config/0.3.19/download",
        type = "tar.gz",
        strip_prefix = "pkg-config-0.3.19",
        build_file = Label("//complex_sys/raze/remote:BUILD.pkg-config-0.3.19.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__tinyvec__0_3_4",
        url = "https://crates.io/api/v1/crates/tinyvec/0.3.4/download",
        type = "tar.gz",
        strip_prefix = "tinyvec-0.3.4",
        build_file = Label("//complex_sys/raze/remote:BUILD.tinyvec-0.3.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__unicode_bidi__0_3_4",
        url = "https://crates.io/api/v1/crates/unicode-bidi/0.3.4/download",
        type = "tar.gz",
        strip_prefix = "unicode-bidi-0.3.4",
        build_file = Label("//complex_sys/raze/remote:BUILD.unicode-bidi-0.3.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__unicode_normalization__0_1_13",
        url = "https://crates.io/api/v1/crates/unicode-normalization/0.1.13/download",
        type = "tar.gz",
        strip_prefix = "unicode-normalization-0.1.13",
        build_file = Label("//complex_sys/raze/remote:BUILD.unicode-normalization-0.1.13.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__url__2_1_1",
        url = "https://crates.io/api/v1/crates/url/2.1.1/download",
        type = "tar.gz",
        strip_prefix = "url-2.1.1",
        build_file = Label("//complex_sys/raze/remote:BUILD.url-2.1.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__vcpkg__0_2_10",
        url = "https://crates.io/api/v1/crates/vcpkg/0.2.10/download",
        type = "tar.gz",
        strip_prefix = "vcpkg-0.2.10",
        build_file = Label("//complex_sys/raze/remote:BUILD.vcpkg-0.2.10.bazel"),
    )
