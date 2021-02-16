"""
@generated
cargo-raze generated Bazel file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

def remote_complicated_cargo_library_fetch_remote_crates():
    """This function defines a collection of repos and should be called in a WORKSPACE file"""
    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__ahash__0_3_8",
        url = "https://crates.io/api/v1/crates/ahash/0.3.8/download",
        type = "tar.gz",
        sha256 = "e8fd72866655d1904d6b0997d0b07ba561047d070fbe29de039031c641b61217",
        strip_prefix = "ahash-0.3.8",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.ahash-0.3.8.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__aho_corasick__0_7_15",
        url = "https://crates.io/api/v1/crates/aho-corasick/0.7.15/download",
        type = "tar.gz",
        sha256 = "7404febffaa47dac81aa44dba71523c9d069b1bdc50a77db41195149e17f68e5",
        strip_prefix = "aho-corasick-0.7.15",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.aho-corasick-0.7.15.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__arrayvec__0_5_2",
        url = "https://crates.io/api/v1/crates/arrayvec/0.5.2/download",
        type = "tar.gz",
        sha256 = "23b62fc65de8e4e7f52534fb52b0f3ed04746ae267519eef2a83941e8085068b",
        strip_prefix = "arrayvec-0.5.2",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.arrayvec-0.5.2.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__atom__0_3_6",
        url = "https://crates.io/api/v1/crates/atom/0.3.6/download",
        type = "tar.gz",
        sha256 = "c9ff149ed9780025acfdb36862d35b28856bb693ceb451259a7164442f22fdc3",
        strip_prefix = "atom-0.3.6",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.atom-0.3.6.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__autocfg__1_0_1",
        url = "https://crates.io/api/v1/crates/autocfg/1.0.1/download",
        type = "tar.gz",
        sha256 = "cdb031dd78e28731d87d56cc8ffef4a8f36ca26c38fe2de700543e627f8a464a",
        strip_prefix = "autocfg-1.0.1",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.autocfg-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__cfg_if__0_1_10",
        url = "https://crates.io/api/v1/crates/cfg-if/0.1.10/download",
        type = "tar.gz",
        sha256 = "4785bdd1c96b2a846b2bd7cc02e86b6b3dbf14e7e53446c4f54c92a361040822",
        strip_prefix = "cfg-if-0.1.10",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.cfg-if-0.1.10.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__cfg_if__1_0_0",
        url = "https://crates.io/api/v1/crates/cfg-if/1.0.0/download",
        type = "tar.gz",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__const_fn__0_4_5",
        url = "https://crates.io/api/v1/crates/const_fn/0.4.5/download",
        type = "tar.gz",
        sha256 = "28b9d6de7f49e22cf97ad17fc4036ece69300032f45f78f30b4a4482cdc3f4a6",
        strip_prefix = "const_fn-0.4.5",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.const_fn-0.4.5.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__core_foundation_sys__0_8_2",
        url = "https://crates.io/api/v1/crates/core-foundation-sys/0.8.2/download",
        type = "tar.gz",
        sha256 = "ea221b5284a47e40033bf9b66f35f984ec0ea2931eb03505246cd27a963f981b",
        strip_prefix = "core-foundation-sys-0.8.2",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.core-foundation-sys-0.8.2.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__crossbeam_channel__0_5_0",
        url = "https://crates.io/api/v1/crates/crossbeam-channel/0.5.0/download",
        type = "tar.gz",
        sha256 = "dca26ee1f8d361640700bde38b2c37d8c22b3ce2d360e1fc1c74ea4b0aa7d775",
        strip_prefix = "crossbeam-channel-0.5.0",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.crossbeam-channel-0.5.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__crossbeam_deque__0_8_0",
        url = "https://crates.io/api/v1/crates/crossbeam-deque/0.8.0/download",
        type = "tar.gz",
        sha256 = "94af6efb46fef72616855b036a624cf27ba656ffc9be1b9a3c931cfc7749a9a9",
        strip_prefix = "crossbeam-deque-0.8.0",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.crossbeam-deque-0.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__crossbeam_epoch__0_9_1",
        url = "https://crates.io/api/v1/crates/crossbeam-epoch/0.9.1/download",
        type = "tar.gz",
        sha256 = "a1aaa739f95311c2c7887a76863f500026092fb1dce0161dab577e559ef3569d",
        strip_prefix = "crossbeam-epoch-0.9.1",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.crossbeam-epoch-0.9.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__crossbeam_queue__0_2_3",
        url = "https://crates.io/api/v1/crates/crossbeam-queue/0.2.3/download",
        type = "tar.gz",
        sha256 = "774ba60a54c213d409d5353bda12d49cd68d14e45036a285234c8d6f91f92570",
        strip_prefix = "crossbeam-queue-0.2.3",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.crossbeam-queue-0.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__crossbeam_utils__0_7_2",
        url = "https://crates.io/api/v1/crates/crossbeam-utils/0.7.2/download",
        type = "tar.gz",
        sha256 = "c3c7c73a2d1e9fc0886a08b93e98eb643461230d5f1925e4036204d5f2e261a8",
        strip_prefix = "crossbeam-utils-0.7.2",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.crossbeam-utils-0.7.2.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__crossbeam_utils__0_8_1",
        url = "https://crates.io/api/v1/crates/crossbeam-utils/0.8.1/download",
        type = "tar.gz",
        sha256 = "02d96d1e189ef58269ebe5b97953da3274d83a93af647c2ddd6f9dab28cedb8d",
        strip_prefix = "crossbeam-utils-0.8.1",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.crossbeam-utils-0.8.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__either__1_6_1",
        url = "https://crates.io/api/v1/crates/either/1.6.1/download",
        type = "tar.gz",
        sha256 = "e78d4f1cc4ae33bbfc157ed5d5a5ef3bc29227303d595861deb238fcec4e9457",
        strip_prefix = "either-1.6.1",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.either-1.6.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__hashbrown__0_7_2",
        url = "https://crates.io/api/v1/crates/hashbrown/0.7.2/download",
        type = "tar.gz",
        sha256 = "96282e96bfcd3da0d3aa9938bedf1e50df3269b6db08b4876d2da0bb1a0841cf",
        strip_prefix = "hashbrown-0.7.2",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.hashbrown-0.7.2.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__hermit_abi__0_1_18",
        url = "https://crates.io/api/v1/crates/hermit-abi/0.1.18/download",
        type = "tar.gz",
        sha256 = "322f4de77956e22ed0e5032c359a0f1273f1f7f0d79bfa3b8ffbc730d7fbcc5c",
        strip_prefix = "hermit-abi-0.1.18",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.hermit-abi-0.1.18.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__hibitset__0_6_3",
        url = "https://crates.io/api/v1/crates/hibitset/0.6.3/download",
        type = "tar.gz",
        sha256 = "93a1bb8316a44459a7d14253c4d28dd7395cbd23cc04a68c46e851b8e46d64b1",
        strip_prefix = "hibitset-0.6.3",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.hibitset-0.6.3.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__lazy_static__1_4_0",
        url = "https://crates.io/api/v1/crates/lazy_static/1.4.0/download",
        type = "tar.gz",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        strip_prefix = "lazy_static-1.4.0",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.lazy_static-1.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__libc__0_2_85",
        url = "https://crates.io/api/v1/crates/libc/0.2.85/download",
        type = "tar.gz",
        sha256 = "7ccac4b00700875e6a07c6cde370d44d32fa01c5a65cdd2fca6858c479d28bb3",
        strip_prefix = "libc-0.2.85",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.libc-0.2.85.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__libloading__0_7_0",
        url = "https://crates.io/api/v1/crates/libloading/0.7.0/download",
        type = "tar.gz",
        sha256 = "6f84d96438c15fcd6c3f244c8fce01d1e2b9c6b5623e9c711dc9286d8fc92d6a",
        strip_prefix = "libloading-0.7.0",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.libloading-0.7.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__log__0_4_14",
        url = "https://crates.io/api/v1/crates/log/0.4.14/download",
        type = "tar.gz",
        sha256 = "51b9bbe6c47d51fc3e1a9b945965946b4c44142ab8792c50835a980d362c2710",
        strip_prefix = "log-0.4.14",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.log-0.4.14.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__maybe_uninit__2_0_0",
        url = "https://crates.io/api/v1/crates/maybe-uninit/2.0.0/download",
        type = "tar.gz",
        sha256 = "60302e4db3a61da70c0cb7991976248362f30319e88850c487b9b95bbf059e00",
        strip_prefix = "maybe-uninit-2.0.0",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.maybe-uninit-2.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__memchr__2_3_4",
        url = "https://crates.io/api/v1/crates/memchr/2.3.4/download",
        type = "tar.gz",
        sha256 = "0ee1c47aaa256ecabcaea351eae4a9b01ef39ed810004e298d2511ed284b1525",
        strip_prefix = "memchr-2.3.4",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.memchr-2.3.4.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__memoffset__0_6_1",
        url = "https://crates.io/api/v1/crates/memoffset/0.6.1/download",
        type = "tar.gz",
        sha256 = "157b4208e3059a8f9e78d559edc658e13df41410cb3ae03979c83130067fdd87",
        strip_prefix = "memoffset-0.6.1",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.memoffset-0.6.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__mopa__0_2_2",
        url = "https://crates.io/api/v1/crates/mopa/0.2.2/download",
        type = "tar.gz",
        sha256 = "a785740271256c230f57462d3b83e52f998433a7062fc18f96d5999474a9f915",
        strip_prefix = "mopa-0.2.2",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.mopa-0.2.2.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__nom__5_1_2",
        url = "https://crates.io/api/v1/crates/nom/5.1.2/download",
        type = "tar.gz",
        sha256 = "ffb4262d26ed83a1c0a33a38fe2bb15797329c85770da05e6b828ddb782627af",
        strip_prefix = "nom-5.1.2",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.nom-5.1.2.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__num_cpus__1_13_0",
        url = "https://crates.io/api/v1/crates/num_cpus/1.13.0/download",
        type = "tar.gz",
        sha256 = "05499f3756671c15885fee9034446956fff3f243d6077b91e5767df161f766b3",
        strip_prefix = "num_cpus-1.13.0",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.num_cpus-1.13.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__once_cell__1_5_2",
        url = "https://crates.io/api/v1/crates/once_cell/1.5.2/download",
        type = "tar.gz",
        sha256 = "13bd41f508810a131401606d54ac32a467c97172d74ba7662562ebba5ad07fa0",
        strip_prefix = "once_cell-1.5.2",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.once_cell-1.5.2.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__rayon__1_5_0",
        url = "https://crates.io/api/v1/crates/rayon/1.5.0/download",
        type = "tar.gz",
        sha256 = "8b0d8e0819fadc20c74ea8373106ead0600e3a67ef1fe8da56e39b9ae7275674",
        strip_prefix = "rayon-1.5.0",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.rayon-1.5.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__rayon_core__1_9_0",
        url = "https://crates.io/api/v1/crates/rayon-core/1.9.0/download",
        type = "tar.gz",
        sha256 = "9ab346ac5921dc62ffa9f89b7a773907511cdfa5490c572ae9be1be33e8afa4a",
        strip_prefix = "rayon-core-1.9.0",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.rayon-core-1.9.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__regex__1_4_3",
        url = "https://crates.io/api/v1/crates/regex/1.4.3/download",
        type = "tar.gz",
        sha256 = "d9251239e129e16308e70d853559389de218ac275b515068abc96829d05b948a",
        strip_prefix = "regex-1.4.3",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.regex-1.4.3.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__regex_syntax__0_6_22",
        url = "https://crates.io/api/v1/crates/regex-syntax/0.6.22/download",
        type = "tar.gz",
        sha256 = "b5eb417147ba9860a96cfe72a0b93bf88fee1744b5636ec99ab20c1aa9376581",
        strip_prefix = "regex-syntax-0.6.22",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.regex-syntax-0.6.22.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__scopeguard__1_1_0",
        url = "https://crates.io/api/v1/crates/scopeguard/1.1.0/download",
        type = "tar.gz",
        sha256 = "d29ab0c6d3fc0ee92fe66e2d99f700eab17a8d57d1c1d3b748380fb20baa78cd",
        strip_prefix = "scopeguard-1.1.0",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.scopeguard-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__security_framework_sys__2_0_0",
        url = "https://crates.io/api/v1/crates/security-framework-sys/2.0.0/download",
        type = "tar.gz",
        sha256 = "f99b9d5e26d2a71633cc4f2ebae7cc9f874044e0c351a27e17892d76dce5678b",
        strip_prefix = "security-framework-sys-2.0.0",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.security-framework-sys-2.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__shred__0_10_2",
        url = "https://crates.io/api/v1/crates/shred/0.10.2/download",
        type = "tar.gz",
        sha256 = "c5f08237e667ac94ad20f8878b5943d91a93ccb231428446c57c21c57779016d",
        strip_prefix = "shred-0.10.2",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.shred-0.10.2.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__shrev__1_1_1",
        url = "https://crates.io/api/v1/crates/shrev/1.1.1/download",
        type = "tar.gz",
        sha256 = "b5752e017e03af9d735b4b069f53b7a7fd90fefafa04d8bd0c25581b0bff437f",
        strip_prefix = "shrev-1.1.1",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.shrev-1.1.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__smallvec__1_6_1",
        url = "https://crates.io/api/v1/crates/smallvec/1.6.1/download",
        type = "tar.gz",
        sha256 = "fe0f37c9e8f3c5a4a66ad655a93c74daac4ad00c441533bf5c6e7990bb42604e",
        strip_prefix = "smallvec-1.6.1",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.smallvec-1.6.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__specs__0_16_1",
        url = "https://crates.io/api/v1/crates/specs/0.16.1/download",
        type = "tar.gz",
        sha256 = "fff28a29366aff703d5da8a7e2c8875dc8453ac1118f842cbc0fa70c7db51240",
        strip_prefix = "specs-0.16.1",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.specs-0.16.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__thread_local__1_1_3",
        url = "https://crates.io/api/v1/crates/thread_local/1.1.3/download",
        type = "tar.gz",
        sha256 = "8018d24e04c95ac8790716a5987d0fec4f8b27249ffa0f7d33f1369bdfb88cbd",
        strip_prefix = "thread_local-1.1.3",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.thread_local-1.1.3.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__tuple_utils__0_3_0",
        url = "https://crates.io/api/v1/crates/tuple_utils/0.3.0/download",
        type = "tar.gz",
        sha256 = "44834418e2c5b16f47bedf35c28e148db099187dd5feee6367fb2525863af4f1",
        strip_prefix = "tuple_utils-0.3.0",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.tuple_utils-0.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__tynm__0_1_6",
        url = "https://crates.io/api/v1/crates/tynm/0.1.6/download",
        type = "tar.gz",
        sha256 = "a4df2caa2dc9c3d1f7641ba981f4cd40ab229775aa7aeb834c9ab2850d50623d",
        strip_prefix = "tynm-0.1.6",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.tynm-0.1.6.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__version_check__0_9_2",
        url = "https://crates.io/api/v1/crates/version_check/0.9.2/download",
        type = "tar.gz",
        sha256 = "b5a972e5669d67ba988ce3dc826706fb0a8b01471c088cb0b6110b805cc36aed",
        strip_prefix = "version_check-0.9.2",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.version_check-0.9.2.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__winapi__0_3_9",
        url = "https://crates.io/api/v1/crates/winapi/0.3.9/download",
        type = "tar.gz",
        sha256 = "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419",
        strip_prefix = "winapi-0.3.9",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.winapi-0.3.9.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__winapi_i686_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-i686-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.winapi-i686-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_complicated_cargo_library__winapi_x86_64_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-x86_64-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("//remote/complicated_cargo_library/cargo/remote:BUILD.winapi-x86_64-pc-windows-gnu-0.4.0.bazel"),
    )
