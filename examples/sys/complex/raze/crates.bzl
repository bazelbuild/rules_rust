"""
@generated
cargo-raze generated Bazel file.

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
        sha256 = "cdb031dd78e28731d87d56cc8ffef4a8f36ca26c38fe2de700543e627f8a464a",
        strip_prefix = "autocfg-1.0.1",
        build_file = Label("//sys/complex/raze/remote:BUILD.autocfg-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__bitflags__1_2_1",
        url = "https://crates.io/api/v1/crates/bitflags/1.2.1/download",
        type = "tar.gz",
        sha256 = "cf1de2fe8c75bc145a2f577add951f8134889b4795d47466a54a5c846d691693",
        strip_prefix = "bitflags-1.2.1",
        build_file = Label("//sys/complex/raze/remote:BUILD.bitflags-1.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__cc__1_0_66",
        url = "https://crates.io/api/v1/crates/cc/1.0.66/download",
        type = "tar.gz",
        sha256 = "4c0496836a84f8d0495758516b8621a622beb77c0fed418570e50764093ced48",
        strip_prefix = "cc-1.0.66",
        build_file = Label("//sys/complex/raze/remote:BUILD.cc-1.0.66.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__cfg_if__0_1_10",
        url = "https://crates.io/api/v1/crates/cfg-if/0.1.10/download",
        type = "tar.gz",
        sha256 = "4785bdd1c96b2a846b2bd7cc02e86b6b3dbf14e7e53446c4f54c92a361040822",
        strip_prefix = "cfg-if-0.1.10",
        build_file = Label("//sys/complex/raze/remote:BUILD.cfg-if-0.1.10.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__cfg_if__1_0_0",
        url = "https://crates.io/api/v1/crates/cfg-if/1.0.0/download",
        type = "tar.gz",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("//sys/complex/raze/remote:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__foreign_types__0_3_2",
        url = "https://crates.io/api/v1/crates/foreign-types/0.3.2/download",
        type = "tar.gz",
        sha256 = "f6f339eb8adc052cd2ca78910fda869aefa38d22d5cb648e6485e4d3fc06f3b1",
        strip_prefix = "foreign-types-0.3.2",
        build_file = Label("//sys/complex/raze/remote:BUILD.foreign-types-0.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__foreign_types_shared__0_1_1",
        url = "https://crates.io/api/v1/crates/foreign-types-shared/0.1.1/download",
        type = "tar.gz",
        sha256 = "00b0228411908ca8685dba7fc2cdd70ec9990a6e753e89b6ac91a84c40fbaf4b",
        strip_prefix = "foreign-types-shared-0.1.1",
        build_file = Label("//sys/complex/raze/remote:BUILD.foreign-types-shared-0.1.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__form_urlencoded__1_0_0",
        url = "https://crates.io/api/v1/crates/form_urlencoded/1.0.0/download",
        type = "tar.gz",
        sha256 = "ece68d15c92e84fa4f19d3780f1294e5ca82a78a6d515f1efaabcc144688be00",
        strip_prefix = "form_urlencoded-1.0.0",
        build_file = Label("//sys/complex/raze/remote:BUILD.form_urlencoded-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__git2__0_13_12",
        url = "https://crates.io/api/v1/crates/git2/0.13.12/download",
        type = "tar.gz",
        sha256 = "ca6f1a0238d7f8f8fd5ee642f4ebac4dbc03e03d1f78fbe7a3ede35dcf7e2224",
        strip_prefix = "git2-0.13.12",
        build_file = Label("//sys/complex/raze/remote:BUILD.git2-0.13.12.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__idna__0_2_0",
        url = "https://crates.io/api/v1/crates/idna/0.2.0/download",
        type = "tar.gz",
        sha256 = "02e2673c30ee86b5b96a9cb52ad15718aa1f966f5ab9ad54a8b95d5ca33120a9",
        strip_prefix = "idna-0.2.0",
        build_file = Label("//sys/complex/raze/remote:BUILD.idna-0.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__jobserver__0_1_21",
        url = "https://crates.io/api/v1/crates/jobserver/0.1.21/download",
        type = "tar.gz",
        sha256 = "5c71313ebb9439f74b00d9d2dcec36440beaf57a6aa0623068441dd7cd81a7f2",
        strip_prefix = "jobserver-0.1.21",
        build_file = Label("//sys/complex/raze/remote:BUILD.jobserver-0.1.21.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__lazy_static__1_4_0",
        url = "https://crates.io/api/v1/crates/lazy_static/1.4.0/download",
        type = "tar.gz",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        strip_prefix = "lazy_static-1.4.0",
        build_file = Label("//sys/complex/raze/remote:BUILD.lazy_static-1.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__libc__0_2_82",
        url = "https://crates.io/api/v1/crates/libc/0.2.82/download",
        type = "tar.gz",
        sha256 = "89203f3fba0a3795506acaad8ebce3c80c0af93f994d5a1d7a0b1eeb23271929",
        strip_prefix = "libc-0.2.82",
        build_file = Label("//sys/complex/raze/remote:BUILD.libc-0.2.82.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__libgit2_sys__0_12_18_1_1_0",
        url = "https://crates.io/api/v1/crates/libgit2-sys/0.12.18+1.1.0/download",
        type = "tar.gz",
        sha256 = "3da6a42da88fc37ee1ecda212ffa254c25713532980005d5f7c0b0fbe7e6e885",
        strip_prefix = "libgit2-sys-0.12.18+1.1.0",
        build_file = Label("//sys/complex/raze/remote:BUILD.libgit2-sys-0.12.18+1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__libssh2_sys__0_2_20",
        url = "https://crates.io/api/v1/crates/libssh2-sys/0.2.20/download",
        type = "tar.gz",
        sha256 = "df40b13fe7ea1be9b9dffa365a51273816c345fc1811478b57ed7d964fbfc4ce",
        strip_prefix = "libssh2-sys-0.2.20",
        build_file = Label("//sys/complex/raze/remote:BUILD.libssh2-sys-0.2.20.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__libz_sys__1_1_2",
        url = "https://crates.io/api/v1/crates/libz-sys/1.1.2/download",
        type = "tar.gz",
        sha256 = "602113192b08db8f38796c4e85c39e960c145965140e918018bcde1952429655",
        strip_prefix = "libz-sys-1.1.2",
        build_file = Label("//sys/complex/raze/remote:BUILD.libz-sys-1.1.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__log__0_4_13",
        url = "https://crates.io/api/v1/crates/log/0.4.13/download",
        type = "tar.gz",
        sha256 = "fcf3805d4480bb5b86070dcfeb9e2cb2ebc148adb753c5cca5f884d1d65a42b2",
        strip_prefix = "log-0.4.13",
        build_file = Label("//sys/complex/raze/remote:BUILD.log-0.4.13.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__matches__0_1_8",
        url = "https://crates.io/api/v1/crates/matches/0.1.8/download",
        type = "tar.gz",
        sha256 = "7ffc5c5338469d4d3ea17d269fa8ea3512ad247247c30bd2df69e68309ed0a08",
        strip_prefix = "matches-0.1.8",
        build_file = Label("//sys/complex/raze/remote:BUILD.matches-0.1.8.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__openssl__0_10_32",
        url = "https://crates.io/api/v1/crates/openssl/0.10.32/download",
        type = "tar.gz",
        sha256 = "038d43985d1ddca7a9900630d8cd031b56e4794eecc2e9ea39dd17aa04399a70",
        strip_prefix = "openssl-0.10.32",
        build_file = Label("//sys/complex/raze/remote:BUILD.openssl-0.10.32.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__openssl_probe__0_1_2",
        url = "https://crates.io/api/v1/crates/openssl-probe/0.1.2/download",
        type = "tar.gz",
        sha256 = "77af24da69f9d9341038eba93a073b1fdaaa1b788221b00a69bce9e762cb32de",
        strip_prefix = "openssl-probe-0.1.2",
        build_file = Label("//sys/complex/raze/remote:BUILD.openssl-probe-0.1.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__openssl_sys__0_9_60",
        url = "https://crates.io/api/v1/crates/openssl-sys/0.9.60/download",
        type = "tar.gz",
        sha256 = "921fc71883267538946025deffb622905ecad223c28efbfdef9bb59a0175f3e6",
        strip_prefix = "openssl-sys-0.9.60",
        build_file = Label("//sys/complex/raze/remote:BUILD.openssl-sys-0.9.60.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__percent_encoding__2_1_0",
        url = "https://crates.io/api/v1/crates/percent-encoding/2.1.0/download",
        type = "tar.gz",
        sha256 = "d4fd5641d01c8f18a23da7b6fe29298ff4b55afcccdf78973b24cf3175fee32e",
        strip_prefix = "percent-encoding-2.1.0",
        build_file = Label("//sys/complex/raze/remote:BUILD.percent-encoding-2.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__pkg_config__0_3_19",
        url = "https://crates.io/api/v1/crates/pkg-config/0.3.19/download",
        type = "tar.gz",
        sha256 = "3831453b3449ceb48b6d9c7ad7c96d5ea673e9b470a1dc578c2ce6521230884c",
        strip_prefix = "pkg-config-0.3.19",
        build_file = Label("//sys/complex/raze/remote:BUILD.pkg-config-0.3.19.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__tinyvec__1_1_0",
        url = "https://crates.io/api/v1/crates/tinyvec/1.1.0/download",
        type = "tar.gz",
        sha256 = "ccf8dbc19eb42fba10e8feaaec282fb50e2c14b2726d6301dbfeed0f73306a6f",
        strip_prefix = "tinyvec-1.1.0",
        build_file = Label("//sys/complex/raze/remote:BUILD.tinyvec-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__tinyvec_macros__0_1_0",
        url = "https://crates.io/api/v1/crates/tinyvec_macros/0.1.0/download",
        type = "tar.gz",
        sha256 = "cda74da7e1a664f795bb1f8a87ec406fb89a02522cf6e50620d016add6dbbf5c",
        strip_prefix = "tinyvec_macros-0.1.0",
        build_file = Label("//sys/complex/raze/remote:BUILD.tinyvec_macros-0.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__unicode_bidi__0_3_4",
        url = "https://crates.io/api/v1/crates/unicode-bidi/0.3.4/download",
        type = "tar.gz",
        sha256 = "49f2bd0c6468a8230e1db229cff8029217cf623c767ea5d60bfbd42729ea54d5",
        strip_prefix = "unicode-bidi-0.3.4",
        build_file = Label("//sys/complex/raze/remote:BUILD.unicode-bidi-0.3.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__unicode_normalization__0_1_16",
        url = "https://crates.io/api/v1/crates/unicode-normalization/0.1.16/download",
        type = "tar.gz",
        sha256 = "a13e63ab62dbe32aeee58d1c5408d35c36c392bba5d9d3142287219721afe606",
        strip_prefix = "unicode-normalization-0.1.16",
        build_file = Label("//sys/complex/raze/remote:BUILD.unicode-normalization-0.1.16.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__url__2_2_0",
        url = "https://crates.io/api/v1/crates/url/2.2.0/download",
        type = "tar.gz",
        sha256 = "5909f2b0817350449ed73e8bcd81c8c3c8d9a7a5d8acba4b27db277f1868976e",
        strip_prefix = "url-2.2.0",
        build_file = Label("//sys/complex/raze/remote:BUILD.url-2.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_complex_sys__vcpkg__0_2_11",
        url = "https://crates.io/api/v1/crates/vcpkg/0.2.11/download",
        type = "tar.gz",
        sha256 = "b00bca6106a5e23f3eee943593759b7fcddb00554332e856d990c893966879fb",
        strip_prefix = "vcpkg-0.2.11",
        build_file = Label("//sys/complex/raze/remote:BUILD.vcpkg-0.2.11.bazel"),
    )
