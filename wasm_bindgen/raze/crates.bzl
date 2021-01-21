"""
@generated
cargo-raze generated Bazel file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

def rules_rust_wasm_bindgen_fetch_remote_crates():
    """This function defines a collection of repos and should be called in a WORKSPACE file"""
    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__aho_corasick__0_7_15",
        url = "https://crates.io/api/v1/crates/aho-corasick/0.7.15/download",
        type = "tar.gz",
        sha256 = "7404febffaa47dac81aa44dba71523c9d069b1bdc50a77db41195149e17f68e5",
        strip_prefix = "aho-corasick-0.7.15",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.aho-corasick-0.7.15.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__anyhow__1_0_36",
        url = "https://crates.io/api/v1/crates/anyhow/1.0.36/download",
        type = "tar.gz",
        sha256 = "68803225a7b13e47191bab76f2687382b60d259e8cf37f6e1893658b84bb9479",
        strip_prefix = "anyhow-1.0.36",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.anyhow-1.0.36.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__arrayref__0_3_6",
        url = "https://crates.io/api/v1/crates/arrayref/0.3.6/download",
        type = "tar.gz",
        sha256 = "a4c527152e37cf757a3f78aae5a06fbeefdb07ccc535c980a3208ee3060dd544",
        strip_prefix = "arrayref-0.3.6",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.arrayref-0.3.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__arrayvec__0_5_2",
        url = "https://crates.io/api/v1/crates/arrayvec/0.5.2/download",
        type = "tar.gz",
        sha256 = "23b62fc65de8e4e7f52534fb52b0f3ed04746ae267519eef2a83941e8085068b",
        strip_prefix = "arrayvec-0.5.2",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.arrayvec-0.5.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__ascii__0_8_7",
        url = "https://crates.io/api/v1/crates/ascii/0.8.7/download",
        type = "tar.gz",
        sha256 = "97be891acc47ca214468e09425d02cef3af2c94d0d82081cd02061f996802f14",
        strip_prefix = "ascii-0.8.7",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.ascii-0.8.7.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__assert_cmd__1_0_2",
        url = "https://crates.io/api/v1/crates/assert_cmd/1.0.2/download",
        type = "tar.gz",
        sha256 = "3dc1679af9a1ab4bea16f228b05d18f8363f8327b1fa8db00d2760cfafc6b61e",
        strip_prefix = "assert_cmd-1.0.2",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.assert_cmd-1.0.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__atty__0_2_14",
        url = "https://crates.io/api/v1/crates/atty/0.2.14/download",
        type = "tar.gz",
        sha256 = "d9b39be18770d11421cdb1b9947a45dd3f37e93092cbf377614828a319d5fee8",
        strip_prefix = "atty-0.2.14",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.atty-0.2.14.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__autocfg__0_1_7",
        url = "https://crates.io/api/v1/crates/autocfg/0.1.7/download",
        type = "tar.gz",
        sha256 = "1d49d90015b3c36167a20fe2810c5cd875ad504b39cff3d4eae7977e6b7c1cb2",
        strip_prefix = "autocfg-0.1.7",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.autocfg-0.1.7.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__autocfg__1_0_1",
        url = "https://crates.io/api/v1/crates/autocfg/1.0.1/download",
        type = "tar.gz",
        sha256 = "cdb031dd78e28731d87d56cc8ffef4a8f36ca26c38fe2de700543e627f8a464a",
        strip_prefix = "autocfg-1.0.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.autocfg-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__base64__0_13_0",
        url = "https://crates.io/api/v1/crates/base64/0.13.0/download",
        type = "tar.gz",
        sha256 = "904dfeac50f3cdaba28fc6f57fdcddb75f49ed61346676a78c4ffe55877802fd",
        strip_prefix = "base64-0.13.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.base64-0.13.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__base64__0_9_3",
        url = "https://crates.io/api/v1/crates/base64/0.9.3/download",
        type = "tar.gz",
        sha256 = "489d6c0ed21b11d038c31b6ceccca973e65d73ba3bd8ecb9a2babf5546164643",
        strip_prefix = "base64-0.9.3",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.base64-0.9.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__bitflags__1_2_1",
        url = "https://crates.io/api/v1/crates/bitflags/1.2.1/download",
        type = "tar.gz",
        sha256 = "cf1de2fe8c75bc145a2f577add951f8134889b4795d47466a54a5c846d691693",
        strip_prefix = "bitflags-1.2.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.bitflags-1.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__blake2b_simd__0_5_11",
        url = "https://crates.io/api/v1/crates/blake2b_simd/0.5.11/download",
        type = "tar.gz",
        sha256 = "afa748e348ad3be8263be728124b24a24f268266f6f5d58af9d75f6a40b5c587",
        strip_prefix = "blake2b_simd-0.5.11",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.blake2b_simd-0.5.11.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__buf_redux__0_8_4",
        url = "https://crates.io/api/v1/crates/buf_redux/0.8.4/download",
        type = "tar.gz",
        sha256 = "b953a6887648bb07a535631f2bc00fbdb2a2216f135552cb3f534ed136b9c07f",
        strip_prefix = "buf_redux-0.8.4",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.buf_redux-0.8.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__bumpalo__3_4_0",
        url = "https://crates.io/api/v1/crates/bumpalo/3.4.0/download",
        type = "tar.gz",
        sha256 = "2e8c087f005730276d1096a652e92a8bacee2e2472bcc9715a74d2bec38b5820",
        strip_prefix = "bumpalo-3.4.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.bumpalo-3.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__byteorder__1_3_4",
        url = "https://crates.io/api/v1/crates/byteorder/1.3.4/download",
        type = "tar.gz",
        sha256 = "08c48aae112d48ed9f069b33538ea9e3e90aa263cfa3d1c24309612b1f7472de",
        strip_prefix = "byteorder-1.3.4",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.byteorder-1.3.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__cc__1_0_66",
        url = "https://crates.io/api/v1/crates/cc/1.0.66/download",
        type = "tar.gz",
        sha256 = "4c0496836a84f8d0495758516b8621a622beb77c0fed418570e50764093ced48",
        strip_prefix = "cc-1.0.66",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.cc-1.0.66.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__cfg_if__0_1_10",
        url = "https://crates.io/api/v1/crates/cfg-if/0.1.10/download",
        type = "tar.gz",
        sha256 = "4785bdd1c96b2a846b2bd7cc02e86b6b3dbf14e7e53446c4f54c92a361040822",
        strip_prefix = "cfg-if-0.1.10",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.cfg-if-0.1.10.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__cfg_if__1_0_0",
        url = "https://crates.io/api/v1/crates/cfg-if/1.0.0/download",
        type = "tar.gz",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__chrono__0_4_19",
        url = "https://crates.io/api/v1/crates/chrono/0.4.19/download",
        type = "tar.gz",
        sha256 = "670ad68c9088c2a963aaa298cb369688cf3f9465ce5e2d4ca10e6e0098a1ce73",
        strip_prefix = "chrono-0.4.19",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.chrono-0.4.19.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__chunked_transfer__0_3_1",
        url = "https://crates.io/api/v1/crates/chunked_transfer/0.3.1/download",
        type = "tar.gz",
        sha256 = "498d20a7aaf62625b9bf26e637cf7736417cde1d0c99f1d04d1170229a85cf87",
        strip_prefix = "chunked_transfer-0.3.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.chunked_transfer-0.3.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__cloudabi__0_0_3",
        url = "https://crates.io/api/v1/crates/cloudabi/0.0.3/download",
        type = "tar.gz",
        sha256 = "ddfc5b9aa5d4507acaf872de71051dfd0e309860e88966e1051e462a077aac4f",
        strip_prefix = "cloudabi-0.0.3",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.cloudabi-0.0.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__const_fn__0_4_4",
        url = "https://crates.io/api/v1/crates/const_fn/0.4.4/download",
        type = "tar.gz",
        sha256 = "cd51eab21ab4fd6a3bf889e2d0958c0a6e3a61ad04260325e919e652a2a62826",
        strip_prefix = "const_fn-0.4.4",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.const_fn-0.4.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__constant_time_eq__0_1_5",
        url = "https://crates.io/api/v1/crates/constant_time_eq/0.1.5/download",
        type = "tar.gz",
        sha256 = "245097e9a4535ee1e3e3931fcfcd55a796a44c643e8596ff6566d68f09b87bbc",
        strip_prefix = "constant_time_eq-0.1.5",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.constant_time_eq-0.1.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__crossbeam_channel__0_5_0",
        url = "https://crates.io/api/v1/crates/crossbeam-channel/0.5.0/download",
        type = "tar.gz",
        sha256 = "dca26ee1f8d361640700bde38b2c37d8c22b3ce2d360e1fc1c74ea4b0aa7d775",
        strip_prefix = "crossbeam-channel-0.5.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.crossbeam-channel-0.5.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__crossbeam_deque__0_8_0",
        url = "https://crates.io/api/v1/crates/crossbeam-deque/0.8.0/download",
        type = "tar.gz",
        sha256 = "94af6efb46fef72616855b036a624cf27ba656ffc9be1b9a3c931cfc7749a9a9",
        strip_prefix = "crossbeam-deque-0.8.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.crossbeam-deque-0.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__crossbeam_epoch__0_9_1",
        url = "https://crates.io/api/v1/crates/crossbeam-epoch/0.9.1/download",
        type = "tar.gz",
        sha256 = "a1aaa739f95311c2c7887a76863f500026092fb1dce0161dab577e559ef3569d",
        strip_prefix = "crossbeam-epoch-0.9.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.crossbeam-epoch-0.9.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__crossbeam_utils__0_8_1",
        url = "https://crates.io/api/v1/crates/crossbeam-utils/0.8.1/download",
        type = "tar.gz",
        sha256 = "02d96d1e189ef58269ebe5b97953da3274d83a93af647c2ddd6f9dab28cedb8d",
        strip_prefix = "crossbeam-utils-0.8.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.crossbeam-utils-0.8.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__curl__0_4_34",
        url = "https://crates.io/api/v1/crates/curl/0.4.34/download",
        type = "tar.gz",
        sha256 = "e268162af1a5fe89917ae25ba3b0a77c8da752bdc58e7dbb4f15b91fbd33756e",
        strip_prefix = "curl-0.4.34",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.curl-0.4.34.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__curl_sys__0_4_39_curl_7_74_0",
        url = "https://crates.io/api/v1/crates/curl-sys/0.4.39+curl-7.74.0/download",
        type = "tar.gz",
        sha256 = "07a8ce861e7b68a0b394e814d7ee9f1b2750ff8bd10372c6ad3bacc10e86f874",
        strip_prefix = "curl-sys-0.4.39+curl-7.74.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.curl-sys-0.4.39+curl-7.74.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__diff__0_1_12",
        url = "https://crates.io/api/v1/crates/diff/0.1.12/download",
        type = "tar.gz",
        sha256 = "0e25ea47919b1560c4e3b7fe0aaab9becf5b84a10325ddf7db0f0ba5e1026499",
        strip_prefix = "diff-0.1.12",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.diff-0.1.12.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__difference__2_0_0",
        url = "https://crates.io/api/v1/crates/difference/2.0.0/download",
        type = "tar.gz",
        sha256 = "524cbf6897b527295dff137cec09ecf3a05f4fddffd7dfcd1585403449e74198",
        strip_prefix = "difference-2.0.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.difference-2.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__dirs__1_0_5",
        url = "https://crates.io/api/v1/crates/dirs/1.0.5/download",
        type = "tar.gz",
        sha256 = "3fd78930633bd1c6e35c4b42b1df7b0cbc6bc191146e512bb3bedf243fcc3901",
        strip_prefix = "dirs-1.0.5",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.dirs-1.0.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__doc_comment__0_3_3",
        url = "https://crates.io/api/v1/crates/doc-comment/0.3.3/download",
        type = "tar.gz",
        sha256 = "fea41bba32d969b513997752735605054bc0dfa92b4c56bf1189f2e174be7a10",
        strip_prefix = "doc-comment-0.3.3",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.doc-comment-0.3.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__docopt__1_1_0",
        url = "https://crates.io/api/v1/crates/docopt/1.1.0/download",
        type = "tar.gz",
        sha256 = "7f525a586d310c87df72ebcd98009e57f1cc030c8c268305287a476beb653969",
        strip_prefix = "docopt-1.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.docopt-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__either__1_6_1",
        url = "https://crates.io/api/v1/crates/either/1.6.1/download",
        type = "tar.gz",
        sha256 = "e78d4f1cc4ae33bbfc157ed5d5a5ef3bc29227303d595861deb238fcec4e9457",
        strip_prefix = "either-1.6.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.either-1.6.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__env_logger__0_7_1",
        url = "https://crates.io/api/v1/crates/env_logger/0.7.1/download",
        type = "tar.gz",
        sha256 = "44533bbbb3bb3c1fa17d9f2e4e38bbbaf8396ba82193c4cb1b6445d711445d36",
        strip_prefix = "env_logger-0.7.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.env_logger-0.7.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__filetime__0_2_13",
        url = "https://crates.io/api/v1/crates/filetime/0.2.13/download",
        type = "tar.gz",
        sha256 = "0c122a393ea57648015bf06fbd3d372378992e86b9ff5a7a497b076a28c79efe",
        strip_prefix = "filetime-0.2.13",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.filetime-0.2.13.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__float_cmp__0_8_0",
        url = "https://crates.io/api/v1/crates/float-cmp/0.8.0/download",
        type = "tar.gz",
        sha256 = "e1267f4ac4f343772758f7b1bdcbe767c218bbab93bb432acbf5162bbf85a6c4",
        strip_prefix = "float-cmp-0.8.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.float-cmp-0.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__fuchsia_cprng__0_1_1",
        url = "https://crates.io/api/v1/crates/fuchsia-cprng/0.1.1/download",
        type = "tar.gz",
        sha256 = "a06f77d526c1a601b7c4cdd98f54b5eaabffc14d5f2f0296febdc7f357c6d3ba",
        strip_prefix = "fuchsia-cprng-0.1.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.fuchsia-cprng-0.1.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__getrandom__0_1_15",
        url = "https://crates.io/api/v1/crates/getrandom/0.1.15/download",
        type = "tar.gz",
        sha256 = "fc587bc0ec293155d5bfa6b9891ec18a1e330c234f896ea47fbada4cadbe47e6",
        strip_prefix = "getrandom-0.1.15",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.getrandom-0.1.15.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__heck__0_3_2",
        url = "https://crates.io/api/v1/crates/heck/0.3.2/download",
        type = "tar.gz",
        sha256 = "87cbf45460356b7deeb5e3415b5563308c0a9b057c85e12b06ad551f98d0a6ac",
        strip_prefix = "heck-0.3.2",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.heck-0.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__hermit_abi__0_1_17",
        url = "https://crates.io/api/v1/crates/hermit-abi/0.1.17/download",
        type = "tar.gz",
        sha256 = "5aca5565f760fb5b220e499d72710ed156fdb74e631659e99377d9ebfbd13ae8",
        strip_prefix = "hermit-abi-0.1.17",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.hermit-abi-0.1.17.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__httparse__1_3_4",
        url = "https://crates.io/api/v1/crates/httparse/1.3.4/download",
        type = "tar.gz",
        sha256 = "cd179ae861f0c2e53da70d892f5f3029f9594be0c41dc5269cd371691b1dc2f9",
        strip_prefix = "httparse-1.3.4",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.httparse-1.3.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__humantime__1_3_0",
        url = "https://crates.io/api/v1/crates/humantime/1.3.0/download",
        type = "tar.gz",
        sha256 = "df004cfca50ef23c36850aaaa59ad52cc70d0e90243c3c7737a4dd32dc7a3c4f",
        strip_prefix = "humantime-1.3.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.humantime-1.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__id_arena__2_2_1",
        url = "https://crates.io/api/v1/crates/id-arena/2.2.1/download",
        type = "tar.gz",
        sha256 = "25a2bc672d1148e28034f176e01fffebb08b35768468cc954630da77a1449005",
        strip_prefix = "id-arena-2.2.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.id-arena-2.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__idna__0_1_5",
        url = "https://crates.io/api/v1/crates/idna/0.1.5/download",
        type = "tar.gz",
        sha256 = "38f09e0f0b1fb55fdee1f17470ad800da77af5186a1a76c026b679358b7e844e",
        strip_prefix = "idna-0.1.5",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.idna-0.1.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__itoa__0_4_6",
        url = "https://crates.io/api/v1/crates/itoa/0.4.6/download",
        type = "tar.gz",
        sha256 = "dc6f3ad7b9d11a0c00842ff8de1b60ee58661048eb8049ed33c73594f359d7e6",
        strip_prefix = "itoa-0.4.6",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.itoa-0.4.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__lazy_static__1_4_0",
        url = "https://crates.io/api/v1/crates/lazy_static/1.4.0/download",
        type = "tar.gz",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        strip_prefix = "lazy_static-1.4.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.lazy_static-1.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__leb128__0_2_4",
        url = "https://crates.io/api/v1/crates/leb128/0.2.4/download",
        type = "tar.gz",
        sha256 = "3576a87f2ba00f6f106fdfcd16db1d698d648a26ad8e0573cad8537c3c362d2a",
        strip_prefix = "leb128-0.2.4",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.leb128-0.2.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__libc__0_2_81",
        url = "https://crates.io/api/v1/crates/libc/0.2.81/download",
        type = "tar.gz",
        sha256 = "1482821306169ec4d07f6aca392a4681f66c75c9918aa49641a2595db64053cb",
        strip_prefix = "libc-0.2.81",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.libc-0.2.81.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__libz_sys__1_1_2",
        url = "https://crates.io/api/v1/crates/libz-sys/1.1.2/download",
        type = "tar.gz",
        sha256 = "602113192b08db8f38796c4e85c39e960c145965140e918018bcde1952429655",
        strip_prefix = "libz-sys-1.1.2",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.libz-sys-1.1.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__log__0_3_9",
        url = "https://crates.io/api/v1/crates/log/0.3.9/download",
        type = "tar.gz",
        sha256 = "e19e8d5c34a3e0e2223db8e060f9e8264aeeb5c5fc64a4ee9965c062211c024b",
        strip_prefix = "log-0.3.9",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.log-0.3.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__log__0_4_11",
        url = "https://crates.io/api/v1/crates/log/0.4.11/download",
        type = "tar.gz",
        sha256 = "4fabed175da42fed1fa0746b0ea71f412aa9d35e76e95e59b192c64b9dc2bf8b",
        strip_prefix = "log-0.4.11",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.log-0.4.11.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__matches__0_1_8",
        url = "https://crates.io/api/v1/crates/matches/0.1.8/download",
        type = "tar.gz",
        sha256 = "7ffc5c5338469d4d3ea17d269fa8ea3512ad247247c30bd2df69e68309ed0a08",
        strip_prefix = "matches-0.1.8",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.matches-0.1.8.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__memchr__2_3_4",
        url = "https://crates.io/api/v1/crates/memchr/2.3.4/download",
        type = "tar.gz",
        sha256 = "0ee1c47aaa256ecabcaea351eae4a9b01ef39ed810004e298d2511ed284b1525",
        strip_prefix = "memchr-2.3.4",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.memchr-2.3.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__memoffset__0_6_1",
        url = "https://crates.io/api/v1/crates/memoffset/0.6.1/download",
        type = "tar.gz",
        sha256 = "157b4208e3059a8f9e78d559edc658e13df41410cb3ae03979c83130067fdd87",
        strip_prefix = "memoffset-0.6.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.memoffset-0.6.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__mime__0_2_6",
        url = "https://crates.io/api/v1/crates/mime/0.2.6/download",
        type = "tar.gz",
        sha256 = "ba626b8a6de5da682e1caa06bdb42a335aee5a84db8e5046a3e8ab17ba0a3ae0",
        strip_prefix = "mime-0.2.6",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.mime-0.2.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__mime_guess__1_8_8",
        url = "https://crates.io/api/v1/crates/mime_guess/1.8.8/download",
        type = "tar.gz",
        sha256 = "216929a5ee4dd316b1702eedf5e74548c123d370f47841ceaac38ca154690ca3",
        strip_prefix = "mime_guess-1.8.8",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.mime_guess-1.8.8.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__multipart__0_15_4",
        url = "https://crates.io/api/v1/crates/multipart/0.15.4/download",
        type = "tar.gz",
        sha256 = "adba94490a79baf2d6a23eac897157047008272fa3eecb3373ae6377b91eca28",
        strip_prefix = "multipart-0.15.4",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.multipart-0.15.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__normalize_line_endings__0_3_0",
        url = "https://crates.io/api/v1/crates/normalize-line-endings/0.3.0/download",
        type = "tar.gz",
        sha256 = "61807f77802ff30975e01f4f071c8ba10c022052f98b3294119f3e615d13e5be",
        strip_prefix = "normalize-line-endings-0.3.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.normalize-line-endings-0.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__num_integer__0_1_44",
        url = "https://crates.io/api/v1/crates/num-integer/0.1.44/download",
        type = "tar.gz",
        sha256 = "d2cc698a63b549a70bc047073d2949cce27cd1c7b0a4a862d08a8031bc2801db",
        strip_prefix = "num-integer-0.1.44",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.num-integer-0.1.44.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__num_traits__0_2_14",
        url = "https://crates.io/api/v1/crates/num-traits/0.2.14/download",
        type = "tar.gz",
        sha256 = "9a64b1ec5cda2586e284722486d802acf1f7dbdc623e2bfc57e65ca1cd099290",
        strip_prefix = "num-traits-0.2.14",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.num-traits-0.2.14.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__num_cpus__1_13_0",
        url = "https://crates.io/api/v1/crates/num_cpus/1.13.0/download",
        type = "tar.gz",
        sha256 = "05499f3756671c15885fee9034446956fff3f243d6077b91e5767df161f766b3",
        strip_prefix = "num_cpus-1.13.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.num_cpus-1.13.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__openssl_probe__0_1_2",
        url = "https://crates.io/api/v1/crates/openssl-probe/0.1.2/download",
        type = "tar.gz",
        sha256 = "77af24da69f9d9341038eba93a073b1fdaaa1b788221b00a69bce9e762cb32de",
        strip_prefix = "openssl-probe-0.1.2",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.openssl-probe-0.1.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__openssl_sys__0_9_60",
        url = "https://crates.io/api/v1/crates/openssl-sys/0.9.60/download",
        type = "tar.gz",
        sha256 = "921fc71883267538946025deffb622905ecad223c28efbfdef9bb59a0175f3e6",
        strip_prefix = "openssl-sys-0.9.60",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.openssl-sys-0.9.60.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__percent_encoding__1_0_1",
        url = "https://crates.io/api/v1/crates/percent-encoding/1.0.1/download",
        type = "tar.gz",
        sha256 = "31010dd2e1ac33d5b46a5b413495239882813e0369f8ed8a5e266f173602f831",
        strip_prefix = "percent-encoding-1.0.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.percent-encoding-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__phf__0_7_24",
        url = "https://crates.io/api/v1/crates/phf/0.7.24/download",
        type = "tar.gz",
        sha256 = "b3da44b85f8e8dfaec21adae67f95d93244b2ecf6ad2a692320598dcc8e6dd18",
        strip_prefix = "phf-0.7.24",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.phf-0.7.24.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__phf_codegen__0_7_24",
        url = "https://crates.io/api/v1/crates/phf_codegen/0.7.24/download",
        type = "tar.gz",
        sha256 = "b03e85129e324ad4166b06b2c7491ae27fe3ec353af72e72cd1654c7225d517e",
        strip_prefix = "phf_codegen-0.7.24",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.phf_codegen-0.7.24.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__phf_generator__0_7_24",
        url = "https://crates.io/api/v1/crates/phf_generator/0.7.24/download",
        type = "tar.gz",
        sha256 = "09364cc93c159b8b06b1f4dd8a4398984503483891b0c26b867cf431fb132662",
        strip_prefix = "phf_generator-0.7.24",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.phf_generator-0.7.24.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__phf_shared__0_7_24",
        url = "https://crates.io/api/v1/crates/phf_shared/0.7.24/download",
        type = "tar.gz",
        sha256 = "234f71a15de2288bcb7e3b6515828d22af7ec8598ee6d24c3b526fa0a80b67a0",
        strip_prefix = "phf_shared-0.7.24",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.phf_shared-0.7.24.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__pkg_config__0_3_19",
        url = "https://crates.io/api/v1/crates/pkg-config/0.3.19/download",
        type = "tar.gz",
        sha256 = "3831453b3449ceb48b6d9c7ad7c96d5ea673e9b470a1dc578c2ce6521230884c",
        strip_prefix = "pkg-config-0.3.19",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.pkg-config-0.3.19.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__ppv_lite86__0_2_10",
        url = "https://crates.io/api/v1/crates/ppv-lite86/0.2.10/download",
        type = "tar.gz",
        sha256 = "ac74c624d6b2d21f425f752262f42188365d7b8ff1aff74c82e45136510a4857",
        strip_prefix = "ppv-lite86-0.2.10",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.ppv-lite86-0.2.10.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__predicates__1_0_5",
        url = "https://crates.io/api/v1/crates/predicates/1.0.5/download",
        type = "tar.gz",
        sha256 = "96bfead12e90dccead362d62bb2c90a5f6fc4584963645bc7f71a735e0b0735a",
        strip_prefix = "predicates-1.0.5",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.predicates-1.0.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__predicates_core__1_0_0",
        url = "https://crates.io/api/v1/crates/predicates-core/1.0.0/download",
        type = "tar.gz",
        sha256 = "06075c3a3e92559ff8929e7a280684489ea27fe44805174c3ebd9328dcb37178",
        strip_prefix = "predicates-core-1.0.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.predicates-core-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__predicates_tree__1_0_0",
        url = "https://crates.io/api/v1/crates/predicates-tree/1.0.0/download",
        type = "tar.gz",
        sha256 = "8e63c4859013b38a76eca2414c64911fba30def9e3202ac461a2d22831220124",
        strip_prefix = "predicates-tree-1.0.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.predicates-tree-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__proc_macro2__1_0_24",
        url = "https://crates.io/api/v1/crates/proc-macro2/1.0.24/download",
        type = "tar.gz",
        sha256 = "1e0704ee1a7e00d7bb417d0770ea303c1bccbabf0ef1667dae92b5967f5f8a71",
        strip_prefix = "proc-macro2-1.0.24",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.proc-macro2-1.0.24.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__quick_error__1_2_3",
        url = "https://crates.io/api/v1/crates/quick-error/1.2.3/download",
        type = "tar.gz",
        sha256 = "a1d01941d82fa2ab50be1e79e6714289dd7cde78eba4c074bc5a4374f650dfe0",
        strip_prefix = "quick-error-1.2.3",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.quick-error-1.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__quote__1_0_8",
        url = "https://crates.io/api/v1/crates/quote/1.0.8/download",
        type = "tar.gz",
        sha256 = "991431c3519a3f36861882da93630ce66b52918dcf1b8e2fd66b397fc96f28df",
        strip_prefix = "quote-1.0.8",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.quote-1.0.8.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand__0_4_6",
        url = "https://crates.io/api/v1/crates/rand/0.4.6/download",
        type = "tar.gz",
        sha256 = "552840b97013b1a26992c11eac34bdd778e464601a4c2054b5f0bff7c6761293",
        strip_prefix = "rand-0.4.6",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rand-0.4.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand__0_5_6",
        url = "https://crates.io/api/v1/crates/rand/0.5.6/download",
        type = "tar.gz",
        sha256 = "c618c47cd3ebd209790115ab837de41425723956ad3ce2e6a7f09890947cacb9",
        strip_prefix = "rand-0.5.6",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rand-0.5.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand__0_6_5",
        url = "https://crates.io/api/v1/crates/rand/0.6.5/download",
        type = "tar.gz",
        sha256 = "6d71dacdc3c88c1fde3885a3be3fbab9f35724e6ce99467f7d9c5026132184ca",
        strip_prefix = "rand-0.6.5",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rand-0.6.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand__0_7_3",
        url = "https://crates.io/api/v1/crates/rand/0.7.3/download",
        type = "tar.gz",
        sha256 = "6a6b1679d49b24bbfe0c803429aa1874472f50d9b363131f0e89fc356b544d03",
        strip_prefix = "rand-0.7.3",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rand-0.7.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_chacha__0_1_1",
        url = "https://crates.io/api/v1/crates/rand_chacha/0.1.1/download",
        type = "tar.gz",
        sha256 = "556d3a1ca6600bfcbab7c7c91ccb085ac7fbbcd70e008a98742e7847f4f7bcef",
        strip_prefix = "rand_chacha-0.1.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rand_chacha-0.1.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_chacha__0_2_2",
        url = "https://crates.io/api/v1/crates/rand_chacha/0.2.2/download",
        type = "tar.gz",
        sha256 = "f4c8ed856279c9737206bf725bf36935d8666ead7aa69b52be55af369d193402",
        strip_prefix = "rand_chacha-0.2.2",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rand_chacha-0.2.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_core__0_3_1",
        url = "https://crates.io/api/v1/crates/rand_core/0.3.1/download",
        type = "tar.gz",
        sha256 = "7a6fdeb83b075e8266dcc8762c22776f6877a63111121f5f8c7411e5be7eed4b",
        strip_prefix = "rand_core-0.3.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rand_core-0.3.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_core__0_4_2",
        url = "https://crates.io/api/v1/crates/rand_core/0.4.2/download",
        type = "tar.gz",
        sha256 = "9c33a3c44ca05fa6f1807d8e6743f3824e8509beca625669633be0acbdf509dc",
        strip_prefix = "rand_core-0.4.2",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rand_core-0.4.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_core__0_5_1",
        url = "https://crates.io/api/v1/crates/rand_core/0.5.1/download",
        type = "tar.gz",
        sha256 = "90bde5296fc891b0cef12a6d03ddccc162ce7b2aff54160af9338f8d40df6d19",
        strip_prefix = "rand_core-0.5.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rand_core-0.5.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_hc__0_1_0",
        url = "https://crates.io/api/v1/crates/rand_hc/0.1.0/download",
        type = "tar.gz",
        sha256 = "7b40677c7be09ae76218dc623efbf7b18e34bced3f38883af07bb75630a21bc4",
        strip_prefix = "rand_hc-0.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rand_hc-0.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_hc__0_2_0",
        url = "https://crates.io/api/v1/crates/rand_hc/0.2.0/download",
        type = "tar.gz",
        sha256 = "ca3129af7b92a17112d59ad498c6f81eaf463253766b90396d39ea7a39d6613c",
        strip_prefix = "rand_hc-0.2.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rand_hc-0.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_isaac__0_1_1",
        url = "https://crates.io/api/v1/crates/rand_isaac/0.1.1/download",
        type = "tar.gz",
        sha256 = "ded997c9d5f13925be2a6fd7e66bf1872597f759fd9dd93513dd7e92e5a5ee08",
        strip_prefix = "rand_isaac-0.1.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rand_isaac-0.1.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_jitter__0_1_4",
        url = "https://crates.io/api/v1/crates/rand_jitter/0.1.4/download",
        type = "tar.gz",
        sha256 = "1166d5c91dc97b88d1decc3285bb0a99ed84b05cfd0bc2341bdf2d43fc41e39b",
        strip_prefix = "rand_jitter-0.1.4",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rand_jitter-0.1.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_os__0_1_3",
        url = "https://crates.io/api/v1/crates/rand_os/0.1.3/download",
        type = "tar.gz",
        sha256 = "7b75f676a1e053fc562eafbb47838d67c84801e38fc1ba459e8f180deabd5071",
        strip_prefix = "rand_os-0.1.3",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rand_os-0.1.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_pcg__0_1_2",
        url = "https://crates.io/api/v1/crates/rand_pcg/0.1.2/download",
        type = "tar.gz",
        sha256 = "abf9b09b01790cfe0364f52bf32995ea3c39f4d2dd011eac241d2914146d0b44",
        strip_prefix = "rand_pcg-0.1.2",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rand_pcg-0.1.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_xorshift__0_1_1",
        url = "https://crates.io/api/v1/crates/rand_xorshift/0.1.1/download",
        type = "tar.gz",
        sha256 = "cbf7e9e623549b0e21f6e97cf8ecf247c1a8fd2e8a992ae265314300b2455d5c",
        strip_prefix = "rand_xorshift-0.1.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rand_xorshift-0.1.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rayon__1_5_0",
        url = "https://crates.io/api/v1/crates/rayon/1.5.0/download",
        type = "tar.gz",
        sha256 = "8b0d8e0819fadc20c74ea8373106ead0600e3a67ef1fe8da56e39b9ae7275674",
        strip_prefix = "rayon-1.5.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rayon-1.5.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rayon_core__1_9_0",
        url = "https://crates.io/api/v1/crates/rayon-core/1.9.0/download",
        type = "tar.gz",
        sha256 = "9ab346ac5921dc62ffa9f89b7a773907511cdfa5490c572ae9be1be33e8afa4a",
        strip_prefix = "rayon-core-1.9.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rayon-core-1.9.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rdrand__0_4_0",
        url = "https://crates.io/api/v1/crates/rdrand/0.4.0/download",
        type = "tar.gz",
        sha256 = "678054eb77286b51581ba43620cc911abf02758c91f93f479767aed0f90458b2",
        strip_prefix = "rdrand-0.4.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rdrand-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__redox_syscall__0_1_57",
        url = "https://crates.io/api/v1/crates/redox_syscall/0.1.57/download",
        type = "tar.gz",
        sha256 = "41cc0f7e4d5d4544e8861606a285bb08d3e70712ccc7d2b84d7c0ccfaf4b05ce",
        strip_prefix = "redox_syscall-0.1.57",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.redox_syscall-0.1.57.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__redox_users__0_3_5",
        url = "https://crates.io/api/v1/crates/redox_users/0.3.5/download",
        type = "tar.gz",
        sha256 = "de0737333e7a9502c789a36d7c7fa6092a49895d4faa31ca5df163857ded2e9d",
        strip_prefix = "redox_users-0.3.5",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.redox_users-0.3.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__regex__1_4_2",
        url = "https://crates.io/api/v1/crates/regex/1.4.2/download",
        type = "tar.gz",
        sha256 = "38cf2c13ed4745de91a5eb834e11c00bcc3709e773173b2ce4c56c9fbde04b9c",
        strip_prefix = "regex-1.4.2",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.regex-1.4.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__regex_syntax__0_6_21",
        url = "https://crates.io/api/v1/crates/regex-syntax/0.6.21/download",
        type = "tar.gz",
        sha256 = "3b181ba2dcf07aaccad5448e8ead58db5b742cf85dfe035e2227f137a539a189",
        strip_prefix = "regex-syntax-0.6.21",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.regex-syntax-0.6.21.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__remove_dir_all__0_5_3",
        url = "https://crates.io/api/v1/crates/remove_dir_all/0.5.3/download",
        type = "tar.gz",
        sha256 = "3acd125665422973a33ac9d3dd2df85edad0f4ae9b00dafb1a05e43a9f5ef8e7",
        strip_prefix = "remove_dir_all-0.5.3",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.remove_dir_all-0.5.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rouille__3_0_0",
        url = "https://crates.io/api/v1/crates/rouille/3.0.0/download",
        type = "tar.gz",
        sha256 = "112568052ec17fa26c6c11c40acbb30d3ad244bf3d6da0be181f5e7e42e5004f",
        strip_prefix = "rouille-3.0.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rouille-3.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rust_argon2__0_8_3",
        url = "https://crates.io/api/v1/crates/rust-argon2/0.8.3/download",
        type = "tar.gz",
        sha256 = "4b18820d944b33caa75a71378964ac46f58517c92b6ae5f762636247c09e78fb",
        strip_prefix = "rust-argon2-0.8.3",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rust-argon2-0.8.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rustc_demangle__0_1_18",
        url = "https://crates.io/api/v1/crates/rustc-demangle/0.1.18/download",
        type = "tar.gz",
        sha256 = "6e3bad0ee36814ca07d7968269dd4b7ec89ec2da10c4bb613928d3077083c232",
        strip_prefix = "rustc-demangle-0.1.18",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rustc-demangle-0.1.18.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__ryu__1_0_5",
        url = "https://crates.io/api/v1/crates/ryu/1.0.5/download",
        type = "tar.gz",
        sha256 = "71d301d4193d031abdd79ff7e3dd721168a9572ef3fe51a1517aba235bd8f86e",
        strip_prefix = "ryu-1.0.5",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.ryu-1.0.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__safemem__0_3_3",
        url = "https://crates.io/api/v1/crates/safemem/0.3.3/download",
        type = "tar.gz",
        sha256 = "ef703b7cb59335eae2eb93ceb664c0eb7ea6bf567079d843e09420219668e072",
        strip_prefix = "safemem-0.3.3",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.safemem-0.3.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__schannel__0_1_19",
        url = "https://crates.io/api/v1/crates/schannel/0.1.19/download",
        type = "tar.gz",
        sha256 = "8f05ba609c234e60bee0d547fe94a4c7e9da733d1c962cf6e59efa4cd9c8bc75",
        strip_prefix = "schannel-0.1.19",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.schannel-0.1.19.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__scopeguard__1_1_0",
        url = "https://crates.io/api/v1/crates/scopeguard/1.1.0/download",
        type = "tar.gz",
        sha256 = "d29ab0c6d3fc0ee92fe66e2d99f700eab17a8d57d1c1d3b748380fb20baa78cd",
        strip_prefix = "scopeguard-1.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.scopeguard-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__serde__1_0_118",
        url = "https://crates.io/api/v1/crates/serde/1.0.118/download",
        type = "tar.gz",
        sha256 = "06c64263859d87aa2eb554587e2d23183398d617427327cf2b3d0ed8c69e4800",
        strip_prefix = "serde-1.0.118",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.serde-1.0.118.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__serde_derive__1_0_118",
        url = "https://crates.io/api/v1/crates/serde_derive/1.0.118/download",
        type = "tar.gz",
        sha256 = "c84d3526699cd55261af4b941e4e725444df67aa4f9e6a3564f18030d12672df",
        strip_prefix = "serde_derive-1.0.118",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.serde_derive-1.0.118.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__serde_json__1_0_60",
        url = "https://crates.io/api/v1/crates/serde_json/1.0.60/download",
        type = "tar.gz",
        sha256 = "1500e84d27fe482ed1dc791a56eddc2f230046a040fa908c08bda1d9fb615779",
        strip_prefix = "serde_json-1.0.60",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.serde_json-1.0.60.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__sha1__0_6_0",
        url = "https://crates.io/api/v1/crates/sha1/0.6.0/download",
        type = "tar.gz",
        sha256 = "2579985fda508104f7587689507983eadd6a6e84dd35d6d115361f530916fa0d",
        strip_prefix = "sha1-0.6.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.sha1-0.6.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__siphasher__0_2_3",
        url = "https://crates.io/api/v1/crates/siphasher/0.2.3/download",
        type = "tar.gz",
        sha256 = "0b8de496cf83d4ed58b6be86c3a275b8602f6ffe98d3024a869e124147a9a3ac",
        strip_prefix = "siphasher-0.2.3",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.siphasher-0.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__socket2__0_3_19",
        url = "https://crates.io/api/v1/crates/socket2/0.3.19/download",
        type = "tar.gz",
        sha256 = "122e570113d28d773067fab24266b66753f6ea915758651696b6e35e49f88d6e",
        strip_prefix = "socket2-0.3.19",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.socket2-0.3.19.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__strsim__0_9_3",
        url = "https://crates.io/api/v1/crates/strsim/0.9.3/download",
        type = "tar.gz",
        sha256 = "6446ced80d6c486436db5c078dde11a9f73d42b57fb273121e160b84f63d894c",
        strip_prefix = "strsim-0.9.3",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.strsim-0.9.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__syn__1_0_56",
        url = "https://crates.io/api/v1/crates/syn/1.0.56/download",
        type = "tar.gz",
        sha256 = "a9802ddde94170d186eeee5005b798d9c159fa970403f1be19976d0cfb939b72",
        strip_prefix = "syn-1.0.56",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.syn-1.0.56.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__tempdir__0_3_7",
        url = "https://crates.io/api/v1/crates/tempdir/0.3.7/download",
        type = "tar.gz",
        sha256 = "15f2b5fb00ccdf689e0149d1b1b3c03fead81c2b37735d812fa8bddbbf41b6d8",
        strip_prefix = "tempdir-0.3.7",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.tempdir-0.3.7.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__tempfile__3_1_0",
        url = "https://crates.io/api/v1/crates/tempfile/3.1.0/download",
        type = "tar.gz",
        sha256 = "7a6e24d9338a0a5be79593e2fa15a648add6138caa803e2d5bc782c371732ca9",
        strip_prefix = "tempfile-3.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.tempfile-3.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__term__0_5_2",
        url = "https://crates.io/api/v1/crates/term/0.5.2/download",
        type = "tar.gz",
        sha256 = "edd106a334b7657c10b7c540a0106114feadeb4dc314513e97df481d5d966f42",
        strip_prefix = "term-0.5.2",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.term-0.5.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__termcolor__1_1_2",
        url = "https://crates.io/api/v1/crates/termcolor/1.1.2/download",
        type = "tar.gz",
        sha256 = "2dfed899f0eb03f32ee8c6a0aabdb8a7949659e3466561fc0adf54e26d88c5f4",
        strip_prefix = "termcolor-1.1.2",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.termcolor-1.1.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__thread_local__1_0_1",
        url = "https://crates.io/api/v1/crates/thread_local/1.0.1/download",
        type = "tar.gz",
        sha256 = "d40c6d1b69745a6ec6fb1ca717914848da4b44ae29d9b3080cbee91d72a69b14",
        strip_prefix = "thread_local-1.0.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.thread_local-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__threadpool__1_8_1",
        url = "https://crates.io/api/v1/crates/threadpool/1.8.1/download",
        type = "tar.gz",
        sha256 = "d050e60b33d41c19108b32cea32164033a9013fe3b46cbd4457559bfbf77afaa",
        strip_prefix = "threadpool-1.8.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.threadpool-1.8.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__time__0_1_44",
        url = "https://crates.io/api/v1/crates/time/0.1.44/download",
        type = "tar.gz",
        sha256 = "6db9e6914ab8b1ae1c260a4ae7a49b6c5611b40328a735b21862567685e73255",
        strip_prefix = "time-0.1.44",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.time-0.1.44.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__tiny_http__0_6_2",
        url = "https://crates.io/api/v1/crates/tiny_http/0.6.2/download",
        type = "tar.gz",
        sha256 = "1661fa0a44c95d01604bd05c66732a446c657efb62b5164a7a083a3b552b4951",
        strip_prefix = "tiny_http-0.6.2",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.tiny_http-0.6.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__tinyvec__1_1_0",
        url = "https://crates.io/api/v1/crates/tinyvec/1.1.0/download",
        type = "tar.gz",
        sha256 = "ccf8dbc19eb42fba10e8feaaec282fb50e2c14b2726d6301dbfeed0f73306a6f",
        strip_prefix = "tinyvec-1.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.tinyvec-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__tinyvec_macros__0_1_0",
        url = "https://crates.io/api/v1/crates/tinyvec_macros/0.1.0/download",
        type = "tar.gz",
        sha256 = "cda74da7e1a664f795bb1f8a87ec406fb89a02522cf6e50620d016add6dbbf5c",
        strip_prefix = "tinyvec_macros-0.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.tinyvec_macros-0.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__treeline__0_1_0",
        url = "https://crates.io/api/v1/crates/treeline/0.1.0/download",
        type = "tar.gz",
        sha256 = "a7f741b240f1a48843f9b8e0444fb55fb2a4ff67293b50a9179dfd5ea67f8d41",
        strip_prefix = "treeline-0.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.treeline-0.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__twoway__0_1_8",
        url = "https://crates.io/api/v1/crates/twoway/0.1.8/download",
        type = "tar.gz",
        sha256 = "59b11b2b5241ba34be09c3cc85a36e56e48f9888862e19cedf23336d35316ed1",
        strip_prefix = "twoway-0.1.8",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.twoway-0.1.8.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__unicase__1_4_2",
        url = "https://crates.io/api/v1/crates/unicase/1.4.2/download",
        type = "tar.gz",
        sha256 = "7f4765f83163b74f957c797ad9253caf97f103fb064d3999aea9568d09fc8a33",
        strip_prefix = "unicase-1.4.2",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.unicase-1.4.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__unicode_bidi__0_3_4",
        url = "https://crates.io/api/v1/crates/unicode-bidi/0.3.4/download",
        type = "tar.gz",
        sha256 = "49f2bd0c6468a8230e1db229cff8029217cf623c767ea5d60bfbd42729ea54d5",
        strip_prefix = "unicode-bidi-0.3.4",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.unicode-bidi-0.3.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__unicode_normalization__0_1_16",
        url = "https://crates.io/api/v1/crates/unicode-normalization/0.1.16/download",
        type = "tar.gz",
        sha256 = "a13e63ab62dbe32aeee58d1c5408d35c36c392bba5d9d3142287219721afe606",
        strip_prefix = "unicode-normalization-0.1.16",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.unicode-normalization-0.1.16.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__unicode_segmentation__1_7_1",
        url = "https://crates.io/api/v1/crates/unicode-segmentation/1.7.1/download",
        type = "tar.gz",
        sha256 = "bb0d2e7be6ae3a5fa87eed5fb451aff96f2573d2694942e40543ae0bbe19c796",
        strip_prefix = "unicode-segmentation-1.7.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.unicode-segmentation-1.7.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__unicode_xid__0_2_1",
        url = "https://crates.io/api/v1/crates/unicode-xid/0.2.1/download",
        type = "tar.gz",
        sha256 = "f7fe0bb3479651439c9112f72b6c505038574c9fbb575ed1bf3b797fa39dd564",
        strip_prefix = "unicode-xid-0.2.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.unicode-xid-0.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__url__1_7_2",
        url = "https://crates.io/api/v1/crates/url/1.7.2/download",
        type = "tar.gz",
        sha256 = "dd4e7c0d531266369519a4aa4f399d748bd37043b00bde1e4ff1f60a120b355a",
        strip_prefix = "url-1.7.2",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.url-1.7.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__vcpkg__0_2_11",
        url = "https://crates.io/api/v1/crates/vcpkg/0.2.11/download",
        type = "tar.gz",
        sha256 = "b00bca6106a5e23f3eee943593759b7fcddb00554332e856d990c893966879fb",
        strip_prefix = "vcpkg-0.2.11",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.vcpkg-0.2.11.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__version_check__0_1_5",
        url = "https://crates.io/api/v1/crates/version_check/0.1.5/download",
        type = "tar.gz",
        sha256 = "914b1a6776c4c929a602fafd8bc742e06365d4bcbe48c30f9cca5824f70dc9dd",
        strip_prefix = "version_check-0.1.5",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.version_check-0.1.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wait_timeout__0_2_0",
        url = "https://crates.io/api/v1/crates/wait-timeout/0.2.0/download",
        type = "tar.gz",
        sha256 = "9f200f5b12eb75f8c1ed65abd4b2db8a6e1b138a20de009dacee265a2498f3f6",
        strip_prefix = "wait-timeout-0.2.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wait-timeout-0.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__walrus__0_18_0",
        url = "https://crates.io/api/v1/crates/walrus/0.18.0/download",
        type = "tar.gz",
        sha256 = "4d470d0583e65f4cab21a1ff3c1ba3dd23ae49e68f516f0afceaeb001b32af39",
        strip_prefix = "walrus-0.18.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.walrus-0.18.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__walrus_macro__0_18_0",
        url = "https://crates.io/api/v1/crates/walrus-macro/0.18.0/download",
        type = "tar.gz",
        sha256 = "d7c2bb690b44cb1b0fdcc54d4998d21f8bdaf706b93775425e440b174f39ad16",
        strip_prefix = "walrus-macro-0.18.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.walrus-macro-0.18.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasi__0_10_0_wasi_snapshot_preview1",
        url = "https://crates.io/api/v1/crates/wasi/0.10.0+wasi-snapshot-preview1/download",
        type = "tar.gz",
        sha256 = "1a143597ca7c7793eff794def352d41792a93c481eb1042423ff7ff72ba2c31f",
        strip_prefix = "wasi-0.10.0+wasi-snapshot-preview1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasi-0.10.0+wasi-snapshot-preview1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasi__0_9_0_wasi_snapshot_preview1",
        url = "https://crates.io/api/v1/crates/wasi/0.9.0+wasi-snapshot-preview1/download",
        type = "tar.gz",
        sha256 = "cccddf32554fecc6acb585f82a32a72e28b48f8c4c1883ddfeeeaa96f7d8e519",
        strip_prefix = "wasi-0.9.0+wasi-snapshot-preview1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasi-0.9.0+wasi-snapshot-preview1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen/0.2.68/download",
        type = "tar.gz",
        sha256 = "1ac64ead5ea5f05873d7c12b545865ca2b8d28adfc50a49b84770a3a97265d42",
        strip_prefix = "wasm-bindgen-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-0.2.68.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_backend__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-backend/0.2.68/download",
        type = "tar.gz",
        sha256 = "f22b422e2a757c35a73774860af8e112bff612ce6cb604224e8e47641a9e4f68",
        strip_prefix = "wasm-bindgen-backend-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-backend-0.2.68.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_cli__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-cli/0.2.68/download",
        type = "tar.gz",
        sha256 = "66892269704d2d149629b12b35200245953a63952db56b651117b3f42a6e8db9",
        strip_prefix = "wasm-bindgen-cli-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-cli-0.2.68.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_cli_support__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-cli-support/0.2.68/download",
        type = "tar.gz",
        sha256 = "0d7ab7ca2bed1686149512473ad17ef25038dbc2d4cd9060a5b9d0430eda57bd",
        strip_prefix = "wasm-bindgen-cli-support-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-cli-support-0.2.68.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_externref_xform__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-externref-xform/0.2.68/download",
        type = "tar.gz",
        sha256 = "fbda27740b611a84e5e60307d1e4bbe303131ee7dfa06b067c51a9be57694f9a",
        strip_prefix = "wasm-bindgen-externref-xform-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-externref-xform-0.2.68.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_macro__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-macro/0.2.68/download",
        type = "tar.gz",
        sha256 = "6b13312a745c08c469f0b292dd2fcd6411dba5f7160f593da6ef69b64e407038",
        strip_prefix = "wasm-bindgen-macro-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-macro-0.2.68.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_macro_support__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-macro-support/0.2.68/download",
        type = "tar.gz",
        sha256 = "f249f06ef7ee334cc3b8ff031bfc11ec99d00f34d86da7498396dc1e3b1498fe",
        strip_prefix = "wasm-bindgen-macro-support-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-macro-support-0.2.68.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_multi_value_xform__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-multi-value-xform/0.2.68/download",
        type = "tar.gz",
        sha256 = "75f1045a9ca195e5f5a20b838b9361c26e9a26df1817d69491bd36f5a33c506a",
        strip_prefix = "wasm-bindgen-multi-value-xform-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-multi-value-xform-0.2.68.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_shared__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-shared/0.2.68/download",
        type = "tar.gz",
        sha256 = "1d649a3145108d7d3fbcde896a468d1bd636791823c9921135218ad89be08307",
        strip_prefix = "wasm-bindgen-shared-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-shared-0.2.68.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_threads_xform__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-threads-xform/0.2.68/download",
        type = "tar.gz",
        sha256 = "0a5558ca1936b27999d37ddcfa8c8ac0d1f2d324604a999024a1ea6b5f242533",
        strip_prefix = "wasm-bindgen-threads-xform-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-threads-xform-0.2.68.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_wasm_conventions__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-wasm-conventions/0.2.68/download",
        type = "tar.gz",
        sha256 = "a14ec444689948d32ebfa9252651482feee34cb8b371b6f8da15775f07a94289",
        strip_prefix = "wasm-bindgen-wasm-conventions-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-wasm-conventions-0.2.68.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_wasm_interpreter__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-wasm-interpreter/0.2.68/download",
        type = "tar.gz",
        sha256 = "e47e8238a2b05dbaf164a628bbaa43aac4c5a965247a991f7f3248824c784b1b",
        strip_prefix = "wasm-bindgen-wasm-interpreter-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-wasm-interpreter-0.2.68.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasmparser__0_59_0",
        url = "https://crates.io/api/v1/crates/wasmparser/0.59.0/download",
        type = "tar.gz",
        sha256 = "a950e6a618f62147fd514ff445b2a0b53120d382751960797f85f058c7eda9b9",
        strip_prefix = "wasmparser-0.59.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasmparser-0.59.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasmparser__0_71_0",
        url = "https://crates.io/api/v1/crates/wasmparser/0.71.0/download",
        type = "tar.gz",
        sha256 = "89a30c99437829ede826802bfcf28500cf58df00e66cb9114df98813bc145ff1",
        strip_prefix = "wasmparser-0.71.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasmparser-0.71.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasmprinter__0_2_18",
        url = "https://crates.io/api/v1/crates/wasmprinter/0.2.18/download",
        type = "tar.gz",
        sha256 = "0515db67c610037f3c53ec36976edfd1eb01bac6b1226914b17ce609480e729f",
        strip_prefix = "wasmprinter-0.2.18",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasmprinter-0.2.18.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wast__21_0_0",
        url = "https://crates.io/api/v1/crates/wast/21.0.0/download",
        type = "tar.gz",
        sha256 = "0b1844f66a2bc8526d71690104c0e78a8e59ffa1597b7245769d174ebb91deb5",
        strip_prefix = "wast-21.0.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wast-21.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__winapi__0_3_9",
        url = "https://crates.io/api/v1/crates/winapi/0.3.9/download",
        type = "tar.gz",
        sha256 = "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419",
        strip_prefix = "winapi-0.3.9",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.winapi-0.3.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__winapi_i686_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-i686-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.winapi-i686-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__winapi_util__0_1_5",
        url = "https://crates.io/api/v1/crates/winapi-util/0.1.5/download",
        type = "tar.gz",
        sha256 = "70ec6ce85bb158151cae5e5c87f95a8e97d2c0c4b001223f33a334e3ce5de178",
        strip_prefix = "winapi-util-0.1.5",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.winapi-util-0.1.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__winapi_x86_64_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-x86_64-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.winapi-x86_64-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wit_parser__0_2_0",
        url = "https://crates.io/api/v1/crates/wit-parser/0.2.0/download",
        type = "tar.gz",
        sha256 = "3f5fd97866f4b9c8e1ed57bcf9446f3d0d8ba37e2dd01c3c612c046c053b06f7",
        strip_prefix = "wit-parser-0.2.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wit-parser-0.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wit_printer__0_2_0",
        url = "https://crates.io/api/v1/crates/wit-printer/0.2.0/download",
        type = "tar.gz",
        sha256 = "93f19ca44555a3c14d69acee6447a6e4f52771b0c6e5d8db3e42db3b90f6fce9",
        strip_prefix = "wit-printer-0.2.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wit-printer-0.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wit_schema_version__0_1_0",
        url = "https://crates.io/api/v1/crates/wit-schema-version/0.1.0/download",
        type = "tar.gz",
        sha256 = "bfee4a6a4716eefa0682e7a3b836152e894a3e4f34a9d6c2c3e1c94429bfe36a",
        strip_prefix = "wit-schema-version-0.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wit-schema-version-0.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wit_text__0_8_0",
        url = "https://crates.io/api/v1/crates/wit-text/0.8.0/download",
        type = "tar.gz",
        sha256 = "33358e95c77d660f1c7c07f4a93c2bd89768965e844e3c50730bb4b42658df5f",
        strip_prefix = "wit-text-0.8.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wit-text-0.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wit_validator__0_2_1",
        url = "https://crates.io/api/v1/crates/wit-validator/0.2.1/download",
        type = "tar.gz",
        sha256 = "3c11d93d925420e7872b226c4161849c32be38385ccab026b88df99d8ddc6ba6",
        strip_prefix = "wit-validator-0.2.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wit-validator-0.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wit_walrus__0_5_0",
        url = "https://crates.io/api/v1/crates/wit-walrus/0.5.0/download",
        type = "tar.gz",
        sha256 = "b532d7bc47d02a08463adc934301efbf67e7b1e1284f8a68edc85d1ca84fa125",
        strip_prefix = "wit-walrus-0.5.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wit-walrus-0.5.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wit_writer__0_2_0",
        url = "https://crates.io/api/v1/crates/wit-writer/0.2.0/download",
        type = "tar.gz",
        sha256 = "c2ad01ba5e9cbcff799a0689e56a153776ea694cec777f605938cb9880d41a09",
        strip_prefix = "wit-writer-0.2.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wit-writer-0.2.0.bazel"),
    )
