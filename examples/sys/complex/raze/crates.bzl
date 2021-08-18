"""
@generated
cargo-raze generated Bazel file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

def complex_sys_fetch_remote_crates():
    """This function defines a collection of repos and should be called in a WORKSPACE file"""
    maybe(
        http_archive,
        name = "complex_sys__autocfg__1_0_1",
        url = "https://crates.io/api/v1/crates/autocfg/1.0.1/download",
        type = "tar.gz",
        sha256 = "cdb031dd78e28731d87d56cc8ffef4a8f36ca26c38fe2de700543e627f8a464a",
        strip_prefix = "autocfg-1.0.1",
        build_file = Label("//sys/complex/raze/remote:BUILD.autocfg-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__bitflags__1_2_1",
        url = "https://crates.io/api/v1/crates/bitflags/1.2.1/download",
        type = "tar.gz",
        sha256 = "cf1de2fe8c75bc145a2f577add951f8134889b4795d47466a54a5c846d691693",
        strip_prefix = "bitflags-1.2.1",
        build_file = Label("//sys/complex/raze/remote:BUILD.bitflags-1.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__cc__1_0_69",
        url = "https://crates.io/api/v1/crates/cc/1.0.69/download",
        type = "tar.gz",
        sha256 = "e70cc2f62c6ce1868963827bd677764c62d07c3d9a3e1fb1177ee1a9ab199eb2",
        strip_prefix = "cc-1.0.69",
        build_file = Label("//sys/complex/raze/remote:BUILD.cc-1.0.69.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__cfg_if__1_0_0",
        url = "https://crates.io/api/v1/crates/cfg-if/1.0.0/download",
        type = "tar.gz",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("//sys/complex/raze/remote:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__foreign_types__0_3_2",
        url = "https://crates.io/api/v1/crates/foreign-types/0.3.2/download",
        type = "tar.gz",
        sha256 = "f6f339eb8adc052cd2ca78910fda869aefa38d22d5cb648e6485e4d3fc06f3b1",
        strip_prefix = "foreign-types-0.3.2",
        build_file = Label("//sys/complex/raze/remote:BUILD.foreign-types-0.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__foreign_types_shared__0_1_1",
        url = "https://crates.io/api/v1/crates/foreign-types-shared/0.1.1/download",
        type = "tar.gz",
        sha256 = "00b0228411908ca8685dba7fc2cdd70ec9990a6e753e89b6ac91a84c40fbaf4b",
        strip_prefix = "foreign-types-shared-0.1.1",
        build_file = Label("//sys/complex/raze/remote:BUILD.foreign-types-shared-0.1.1.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__form_urlencoded__1_0_1",
        url = "https://crates.io/api/v1/crates/form_urlencoded/1.0.1/download",
        type = "tar.gz",
        sha256 = "5fc25a87fa4fd2094bffb06925852034d90a17f0d1e05197d4956d3555752191",
        strip_prefix = "form_urlencoded-1.0.1",
        build_file = Label("//sys/complex/raze/remote:BUILD.form_urlencoded-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__git2__0_13_12",
        url = "https://crates.io/api/v1/crates/git2/0.13.12/download",
        type = "tar.gz",
        sha256 = "ca6f1a0238d7f8f8fd5ee642f4ebac4dbc03e03d1f78fbe7a3ede35dcf7e2224",
        strip_prefix = "git2-0.13.12",
        build_file = Label("//sys/complex/raze/remote:BUILD.git2-0.13.12.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__idna__0_2_3",
        url = "https://crates.io/api/v1/crates/idna/0.2.3/download",
        type = "tar.gz",
        sha256 = "418a0a6fab821475f634efe3ccc45c013f742efe03d853e8d3355d5cb850ecf8",
        strip_prefix = "idna-0.2.3",
        build_file = Label("//sys/complex/raze/remote:BUILD.idna-0.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__jobserver__0_1_23",
        url = "https://crates.io/api/v1/crates/jobserver/0.1.23/download",
        type = "tar.gz",
        sha256 = "f5ca711fd837261e14ec9e674f092cbb931d3fa1482b017ae59328ddc6f3212b",
        strip_prefix = "jobserver-0.1.23",
        build_file = Label("//sys/complex/raze/remote:BUILD.jobserver-0.1.23.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__lazy_static__1_4_0",
        url = "https://crates.io/api/v1/crates/lazy_static/1.4.0/download",
        type = "tar.gz",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        strip_prefix = "lazy_static-1.4.0",
        build_file = Label("//sys/complex/raze/remote:BUILD.lazy_static-1.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__libc__0_2_98",
        url = "https://crates.io/api/v1/crates/libc/0.2.98/download",
        type = "tar.gz",
        sha256 = "320cfe77175da3a483efed4bc0adc1968ca050b098ce4f2f1c13a56626128790",
        strip_prefix = "libc-0.2.98",
        build_file = Label("//sys/complex/raze/remote:BUILD.libc-0.2.98.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__libgit2_sys__0_12_21_1_1_0",
        url = "https://crates.io/api/v1/crates/libgit2-sys/0.12.21+1.1.0/download",
        type = "tar.gz",
        sha256 = "86271bacd72b2b9e854c3dcfb82efd538f15f870e4c11af66900effb462f6825",
        strip_prefix = "libgit2-sys-0.12.21+1.1.0",
        build_file = Label("//sys/complex/raze/remote:BUILD.libgit2-sys-0.12.21+1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__libssh2_sys__0_2_21",
        url = "https://crates.io/api/v1/crates/libssh2-sys/0.2.21/download",
        type = "tar.gz",
        sha256 = "e0186af0d8f171ae6b9c4c90ec51898bad5d08a2d5e470903a50d9ad8959cbee",
        strip_prefix = "libssh2-sys-0.2.21",
        build_file = Label("//sys/complex/raze/remote:BUILD.libssh2-sys-0.2.21.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__libz_sys__1_1_3",
        url = "https://crates.io/api/v1/crates/libz-sys/1.1.3/download",
        type = "tar.gz",
        sha256 = "de5435b8549c16d423ed0c03dbaafe57cf6c3344744f1242520d59c9d8ecec66",
        strip_prefix = "libz-sys-1.1.3",
        build_file = Label("//sys/complex/raze/remote:BUILD.libz-sys-1.1.3.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__log__0_4_14",
        url = "https://crates.io/api/v1/crates/log/0.4.14/download",
        type = "tar.gz",
        sha256 = "51b9bbe6c47d51fc3e1a9b945965946b4c44142ab8792c50835a980d362c2710",
        strip_prefix = "log-0.4.14",
        build_file = Label("//sys/complex/raze/remote:BUILD.log-0.4.14.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__matches__0_1_8",
        url = "https://crates.io/api/v1/crates/matches/0.1.8/download",
        type = "tar.gz",
        sha256 = "7ffc5c5338469d4d3ea17d269fa8ea3512ad247247c30bd2df69e68309ed0a08",
        strip_prefix = "matches-0.1.8",
        build_file = Label("//sys/complex/raze/remote:BUILD.matches-0.1.8.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__openssl__0_10_32",
        url = "https://crates.io/api/v1/crates/openssl/0.10.32/download",
        type = "tar.gz",
        sha256 = "038d43985d1ddca7a9900630d8cd031b56e4794eecc2e9ea39dd17aa04399a70",
        strip_prefix = "openssl-0.10.32",
        build_file = Label("//sys/complex/raze/remote:BUILD.openssl-0.10.32.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__openssl_probe__0_1_4",
        url = "https://crates.io/api/v1/crates/openssl-probe/0.1.4/download",
        type = "tar.gz",
        sha256 = "28988d872ab76095a6e6ac88d99b54fd267702734fd7ffe610ca27f533ddb95a",
        strip_prefix = "openssl-probe-0.1.4",
        build_file = Label("//sys/complex/raze/remote:BUILD.openssl-probe-0.1.4.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__openssl_sys__0_9_60",
        url = "https://crates.io/api/v1/crates/openssl-sys/0.9.60/download",
        type = "tar.gz",
        sha256 = "921fc71883267538946025deffb622905ecad223c28efbfdef9bb59a0175f3e6",
        strip_prefix = "openssl-sys-0.9.60",
        build_file = Label("//sys/complex/raze/remote:BUILD.openssl-sys-0.9.60.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__percent_encoding__2_1_0",
        url = "https://crates.io/api/v1/crates/percent-encoding/2.1.0/download",
        type = "tar.gz",
        sha256 = "d4fd5641d01c8f18a23da7b6fe29298ff4b55afcccdf78973b24cf3175fee32e",
        strip_prefix = "percent-encoding-2.1.0",
        build_file = Label("//sys/complex/raze/remote:BUILD.percent-encoding-2.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__pkg_config__0_3_19",
        url = "https://crates.io/api/v1/crates/pkg-config/0.3.19/download",
        type = "tar.gz",
        sha256 = "3831453b3449ceb48b6d9c7ad7c96d5ea673e9b470a1dc578c2ce6521230884c",
        strip_prefix = "pkg-config-0.3.19",
        build_file = Label("//sys/complex/raze/remote:BUILD.pkg-config-0.3.19.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__tinyvec__1_3_1",
        url = "https://crates.io/api/v1/crates/tinyvec/1.3.1/download",
        type = "tar.gz",
        sha256 = "848a1e1181b9f6753b5e96a092749e29b11d19ede67dfbbd6c7dc7e0f49b5338",
        strip_prefix = "tinyvec-1.3.1",
        build_file = Label("//sys/complex/raze/remote:BUILD.tinyvec-1.3.1.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__tinyvec_macros__0_1_0",
        url = "https://crates.io/api/v1/crates/tinyvec_macros/0.1.0/download",
        type = "tar.gz",
        sha256 = "cda74da7e1a664f795bb1f8a87ec406fb89a02522cf6e50620d016add6dbbf5c",
        strip_prefix = "tinyvec_macros-0.1.0",
        build_file = Label("//sys/complex/raze/remote:BUILD.tinyvec_macros-0.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__unicode_bidi__0_3_5",
        url = "https://crates.io/api/v1/crates/unicode-bidi/0.3.5/download",
        type = "tar.gz",
        sha256 = "eeb8be209bb1c96b7c177c7420d26e04eccacb0eeae6b980e35fcb74678107e0",
        strip_prefix = "unicode-bidi-0.3.5",
        build_file = Label("//sys/complex/raze/remote:BUILD.unicode-bidi-0.3.5.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__unicode_normalization__0_1_19",
        url = "https://crates.io/api/v1/crates/unicode-normalization/0.1.19/download",
        type = "tar.gz",
        sha256 = "d54590932941a9e9266f0832deed84ebe1bf2e4c9e4a3554d393d18f5e854bf9",
        strip_prefix = "unicode-normalization-0.1.19",
        build_file = Label("//sys/complex/raze/remote:BUILD.unicode-normalization-0.1.19.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__url__2_2_2",
        url = "https://crates.io/api/v1/crates/url/2.2.2/download",
        type = "tar.gz",
        sha256 = "a507c383b2d33b5fc35d1861e77e6b383d158b2da5e14fe51b83dfedf6fd578c",
        strip_prefix = "url-2.2.2",
        build_file = Label("//sys/complex/raze/remote:BUILD.url-2.2.2.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__vcpkg__0_2_15",
        url = "https://crates.io/api/v1/crates/vcpkg/0.2.15/download",
        type = "tar.gz",
        sha256 = "accd4ea62f7bb7a82fe23066fb0957d48ef677f6eeb8215f372f52e48bb32426",
        strip_prefix = "vcpkg-0.2.15",
        build_file = Label("//sys/complex/raze/remote:BUILD.vcpkg-0.2.15.bazel"),
    )
