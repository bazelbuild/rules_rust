"""
@generated
cargo-raze generated Bazel file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

def rules_rust_util_import_fetch_remote_crates():
    """This function defines a collection of repos and should be called in a WORKSPACE file"""
    maybe(
        http_archive,
        name = "rules_rust_util_import__aho_corasick__0_7_15",
        url = "https://crates.io/api/v1/crates/aho-corasick/0.7.15/download",
        type = "tar.gz",
        sha256 = "7404febffaa47dac81aa44dba71523c9d069b1bdc50a77db41195149e17f68e5",
        strip_prefix = "aho-corasick-0.7.15",
        build_file = Label("//util/import/raze/remote:BUILD.aho-corasick-0.7.15.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_util_import__cfg_if__1_0_0",
        url = "https://crates.io/api/v1/crates/cfg-if/1.0.0/download",
        type = "tar.gz",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("//util/import/raze/remote:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_util_import__env_logger__0_8_4",
        url = "https://crates.io/api/v1/crates/env_logger/0.8.4/download",
        type = "tar.gz",
        sha256 = "a19187fea3ac7e84da7dacf48de0c45d63c6a76f9490dae389aead16c243fce3",
        strip_prefix = "env_logger-0.8.4",
        build_file = Label("//util/import/raze/remote:BUILD.env_logger-0.8.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_util_import__getrandom__0_2_3",
        url = "https://crates.io/api/v1/crates/getrandom/0.2.3/download",
        type = "tar.gz",
        sha256 = "7fcd999463524c52659517fe2cea98493cfe485d10565e7b0fb07dbba7ad2753",
        strip_prefix = "getrandom-0.2.3",
        build_file = Label("//util/import/raze/remote:BUILD.getrandom-0.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_util_import__lazy_static__1_4_0",
        url = "https://crates.io/api/v1/crates/lazy_static/1.4.0/download",
        type = "tar.gz",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        strip_prefix = "lazy_static-1.4.0",
        build_file = Label("//util/import/raze/remote:BUILD.lazy_static-1.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_util_import__libc__0_2_112",
        url = "https://crates.io/api/v1/crates/libc/0.2.112/download",
        type = "tar.gz",
        sha256 = "1b03d17f364a3a042d5e5d46b053bbbf82c92c9430c592dd4c064dc6ee997125",
        strip_prefix = "libc-0.2.112",
        build_file = Label("//util/import/raze/remote:BUILD.libc-0.2.112.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_util_import__log__0_4_14",
        url = "https://crates.io/api/v1/crates/log/0.4.14/download",
        type = "tar.gz",
        sha256 = "51b9bbe6c47d51fc3e1a9b945965946b4c44142ab8792c50835a980d362c2710",
        strip_prefix = "log-0.4.14",
        build_file = Label("//util/import/raze/remote:BUILD.log-0.4.14.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_util_import__memchr__2_4_1",
        url = "https://crates.io/api/v1/crates/memchr/2.4.1/download",
        type = "tar.gz",
        sha256 = "308cc39be01b73d0d18f82a0e7b2a3df85245f84af96fdddc5d202d27e47b86a",
        strip_prefix = "memchr-2.4.1",
        build_file = Label("//util/import/raze/remote:BUILD.memchr-2.4.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_util_import__proc_macro2__1_0_33",
        url = "https://crates.io/api/v1/crates/proc-macro2/1.0.33/download",
        type = "tar.gz",
        sha256 = "fb37d2df5df740e582f28f8560cf425f52bb267d872fe58358eadb554909f07a",
        strip_prefix = "proc-macro2-1.0.33",
        build_file = Label("//util/import/raze/remote:BUILD.proc-macro2-1.0.33.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_util_import__quickcheck__1_0_3",
        url = "https://crates.io/api/v1/crates/quickcheck/1.0.3/download",
        type = "tar.gz",
        sha256 = "588f6378e4dd99458b60ec275b4477add41ce4fa9f64dcba6f15adccb19b50d6",
        strip_prefix = "quickcheck-1.0.3",
        build_file = Label("//util/import/raze/remote:BUILD.quickcheck-1.0.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_util_import__quote__1_0_10",
        url = "https://crates.io/api/v1/crates/quote/1.0.10/download",
        type = "tar.gz",
        sha256 = "38bc8cc6a5f2e3655e0899c1b848643b2562f853f114bfec7be120678e3ace05",
        strip_prefix = "quote-1.0.10",
        build_file = Label("//util/import/raze/remote:BUILD.quote-1.0.10.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_util_import__rand__0_8_4",
        url = "https://crates.io/api/v1/crates/rand/0.8.4/download",
        type = "tar.gz",
        sha256 = "2e7573632e6454cf6b99d7aac4ccca54be06da05aca2ef7423d22d27d4d4bcd8",
        strip_prefix = "rand-0.8.4",
        build_file = Label("//util/import/raze/remote:BUILD.rand-0.8.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_util_import__rand_core__0_6_3",
        url = "https://crates.io/api/v1/crates/rand_core/0.6.3/download",
        type = "tar.gz",
        sha256 = "d34f1408f55294453790c48b2f1ebbb1c5b4b7563eb1f418bcfcfdbb06ebb4e7",
        strip_prefix = "rand_core-0.6.3",
        build_file = Label("//util/import/raze/remote:BUILD.rand_core-0.6.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_util_import__regex__1_4_6",
        url = "https://crates.io/api/v1/crates/regex/1.4.6/download",
        type = "tar.gz",
        sha256 = "2a26af418b574bd56588335b3a3659a65725d4e636eb1016c2f9e3b38c7cc759",
        strip_prefix = "regex-1.4.6",
        build_file = Label("//util/import/raze/remote:BUILD.regex-1.4.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_util_import__regex_syntax__0_6_25",
        url = "https://crates.io/api/v1/crates/regex-syntax/0.6.25/download",
        type = "tar.gz",
        sha256 = "f497285884f3fcff424ffc933e56d7cbca511def0c9831a7f9b5f6153e3cc89b",
        strip_prefix = "regex-syntax-0.6.25",
        build_file = Label("//util/import/raze/remote:BUILD.regex-syntax-0.6.25.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_util_import__syn__1_0_82",
        url = "https://crates.io/api/v1/crates/syn/1.0.82/download",
        type = "tar.gz",
        sha256 = "8daf5dd0bb60cbd4137b1b587d2fc0ae729bc07cf01cd70b36a1ed5ade3b9d59",
        strip_prefix = "syn-1.0.82",
        build_file = Label("//util/import/raze/remote:BUILD.syn-1.0.82.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_util_import__unicode_xid__0_2_2",
        url = "https://crates.io/api/v1/crates/unicode-xid/0.2.2/download",
        type = "tar.gz",
        sha256 = "8ccb82d61f80a663efe1f787a51b16b5a51e3314d6ac365b08639f52387b33f3",
        strip_prefix = "unicode-xid-0.2.2",
        build_file = Label("//util/import/raze/remote:BUILD.unicode-xid-0.2.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_util_import__wasi__0_10_2_wasi_snapshot_preview1",
        url = "https://crates.io/api/v1/crates/wasi/0.10.2+wasi-snapshot-preview1/download",
        type = "tar.gz",
        sha256 = "fd6fbd9a79829dd1ad0cc20627bf1ed606756a7f77edff7b66b7064f9cb327c6",
        strip_prefix = "wasi-0.10.2+wasi-snapshot-preview1",
        build_file = Label("//util/import/raze/remote:BUILD.wasi-0.10.2+wasi-snapshot-preview1.bazel"),
    )
