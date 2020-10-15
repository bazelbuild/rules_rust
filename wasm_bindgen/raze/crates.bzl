"""
@generated
cargo-raze crate workspace functions

DO NOT EDIT! Replaced on runs of cargo-raze
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

def rules_rust_wasm_bindgen_fetch_remote_crates():
    """This function defines a collection of repos and should be called in a WORKSPACE file"""
    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__backtrace_sys__0_1_29",
        url = "https://crates.io/api/v1/crates/backtrace-sys/0.1.29/download",
        type = "tar.gz",
        sha256 = "12cb9f1eef1d1fc869ad5a26c9fa48516339a15e54a227a25460fc304815fdb3",
        strip_prefix = "backtrace-sys-0.1.29",
        build_file = Label("//wasm_bindgen/raze/remote:backtrace-sys-0.1.29.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__bumpalo__2_6_0",
        url = "https://crates.io/api/v1/crates/bumpalo/2.6.0/download",
        type = "tar.gz",
        sha256 = "ad807f2fc2bf185eeb98ff3a901bd46dc5ad58163d0fa4577ba0d25674d71708",
        strip_prefix = "bumpalo-2.6.0",
        build_file = Label("//wasm_bindgen/raze/remote:bumpalo-2.6.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__cc__1_0_60",
        url = "https://crates.io/api/v1/crates/cc/1.0.60/download",
        type = "tar.gz",
        sha256 = "ef611cc68ff783f18535d77ddd080185275713d852c4f5cbb6122c462a7a825c",
        strip_prefix = "cc-1.0.60",
        build_file = Label("//wasm_bindgen/raze/remote:cc-1.0.60.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__cfg_if__0_1_10",
        url = "https://crates.io/api/v1/crates/cfg-if/0.1.10/download",
        type = "tar.gz",
        sha256 = "4785bdd1c96b2a846b2bd7cc02e86b6b3dbf14e7e53446c4f54c92a361040822",
        strip_prefix = "cfg-if-0.1.10",
        build_file = Label("//wasm_bindgen/raze/remote:cfg-if-0.1.10.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__lazy_static__1_4_0",
        url = "https://crates.io/api/v1/crates/lazy_static/1.4.0/download",
        type = "tar.gz",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        strip_prefix = "lazy_static-1.4.0",
        build_file = Label("//wasm_bindgen/raze/remote:lazy_static-1.4.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__libc__0_2_77",
        url = "https://crates.io/api/v1/crates/libc/0.2.77/download",
        type = "tar.gz",
        sha256 = "f2f96b10ec2560088a8e76961b00d47107b3a625fecb76dedb29ee7ccbf98235",
        strip_prefix = "libc-0.2.77",
        build_file = Label("//wasm_bindgen/raze/remote:libc-0.2.77.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__log__0_4_11",
        url = "https://crates.io/api/v1/crates/log/0.4.11/download",
        type = "tar.gz",
        sha256 = "4fabed175da42fed1fa0746b0ea71f412aa9d35e76e95e59b192c64b9dc2bf8b",
        strip_prefix = "log-0.4.11",
        build_file = Label("//wasm_bindgen/raze/remote:log-0.4.11.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__proc_macro2__0_4_30",
        url = "https://crates.io/api/v1/crates/proc-macro2/0.4.30/download",
        type = "tar.gz",
        sha256 = "cf3d2011ab5c909338f7887f4fc896d35932e29146c12c8d01da6b22a80ba759",
        strip_prefix = "proc-macro2-0.4.30",
        build_file = Label("//wasm_bindgen/raze/remote:proc-macro2-0.4.30.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__quote__0_6_13",
        url = "https://crates.io/api/v1/crates/quote/0.6.13/download",
        type = "tar.gz",
        sha256 = "6ce23b6b870e8f94f81fb0a363d65d86675884b34a09043c81e5562f11c1f8e1",
        strip_prefix = "quote-0.6.13",
        build_file = Label("//wasm_bindgen/raze/remote:quote-0.6.13.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__syn__0_15_44",
        url = "https://crates.io/api/v1/crates/syn/0.15.44/download",
        type = "tar.gz",
        sha256 = "9ca4b3b69a77cbe1ffc9e198781b7acb0c7365a883670e8f1c1bc66fba79a5c5",
        strip_prefix = "syn-0.15.44",
        build_file = Label("//wasm_bindgen/raze/remote:syn-0.15.44.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__unicode_xid__0_1_0",
        url = "https://crates.io/api/v1/crates/unicode-xid/0.1.0/download",
        type = "tar.gz",
        sha256 = "fc72304796d0818e357ead4e000d19c9c174ab23dc11093ac919054d20a6a7fc",
        strip_prefix = "unicode-xid-0.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:unicode-xid-0.1.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen__0_2_48",
        url = "https://crates.io/api/v1/crates/wasm-bindgen/0.2.48/download",
        type = "tar.gz",
        sha256 = "4de97fa1806bb1a99904216f6ac5e0c050dc4f8c676dc98775047c38e5c01b55",
        strip_prefix = "wasm-bindgen-0.2.48",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-0.2.48.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_backend__0_2_48",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-backend/0.2.48/download",
        type = "tar.gz",
        sha256 = "5d82c170ef9f5b2c63ad4460dfcee93f3ec04a9a36a4cc20bc973c39e59ab8e3",
        strip_prefix = "wasm-bindgen-backend-0.2.48",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-backend-0.2.48.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_macro__0_2_48",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-macro/0.2.48/download",
        type = "tar.gz",
        sha256 = "f07d50f74bf7a738304f6b8157f4a581e1512cd9e9cdb5baad8c31bbe8ffd81d",
        strip_prefix = "wasm-bindgen-macro-0.2.48",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-macro-0.2.48.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_macro_support__0_2_48",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-macro-support/0.2.48/download",
        type = "tar.gz",
        sha256 = "95cf8fe77e45ba5f91bc8f3da0c3aa5d464b3d8ed85d84f4d4c7cc106436b1d7",
        strip_prefix = "wasm-bindgen-macro-support-0.2.48",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-macro-support-0.2.48.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_shared__0_2_48",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-shared/0.2.48/download",
        type = "tar.gz",
        sha256 = "d9c2d4d4756b2e46d3a5422e06277d02e4d3e1d62d138b76a4c681e925743623",
        strip_prefix = "wasm-bindgen-shared-0.2.48",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-shared-0.2.48.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__addr2line__0_13_0",
        url = "https://crates.io/api/v1/crates/addr2line/0.13.0/download",
        type = "tar.gz",
        sha256 = "1b6a2d3371669ab3ca9797670853d61402b03d0b4b9ebf33d677dfa720203072",
        strip_prefix = "addr2line-0.13.0",
        build_file = Label("//wasm_bindgen/raze/remote:addr2line-0.13.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__adler__0_2_3",
        url = "https://crates.io/api/v1/crates/adler/0.2.3/download",
        type = "tar.gz",
        sha256 = "ee2a4ec343196209d6594e19543ae87a39f96d5534d7174822a3ad825dd6ed7e",
        strip_prefix = "adler-0.2.3",
        build_file = Label("//wasm_bindgen/raze/remote:adler-0.2.3.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__aho_corasick__0_7_14",
        url = "https://crates.io/api/v1/crates/aho-corasick/0.7.14/download",
        type = "tar.gz",
        sha256 = "b476ce7103678b0c6d3d395dbbae31d48ff910bd28be979ba5d48c6351131d0d",
        strip_prefix = "aho-corasick-0.7.14",
        build_file = Label("//wasm_bindgen/raze/remote:aho-corasick-0.7.14.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__arrayref__0_3_6",
        url = "https://crates.io/api/v1/crates/arrayref/0.3.6/download",
        type = "tar.gz",
        sha256 = "a4c527152e37cf757a3f78aae5a06fbeefdb07ccc535c980a3208ee3060dd544",
        strip_prefix = "arrayref-0.3.6",
        build_file = Label("//wasm_bindgen/raze/remote:arrayref-0.3.6.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__arrayvec__0_5_1",
        url = "https://crates.io/api/v1/crates/arrayvec/0.5.1/download",
        type = "tar.gz",
        sha256 = "cff77d8686867eceff3105329d4698d96c2391c176d5d03adc90c7389162b5b8",
        strip_prefix = "arrayvec-0.5.1",
        build_file = Label("//wasm_bindgen/raze/remote:arrayvec-0.5.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__ascii__0_8_7",
        url = "https://crates.io/api/v1/crates/ascii/0.8.7/download",
        type = "tar.gz",
        sha256 = "97be891acc47ca214468e09425d02cef3af2c94d0d82081cd02061f996802f14",
        strip_prefix = "ascii-0.8.7",
        build_file = Label("//wasm_bindgen/raze/remote:ascii-0.8.7.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__assert_cmd__0_11_1",
        url = "https://crates.io/api/v1/crates/assert_cmd/0.11.1/download",
        type = "tar.gz",
        sha256 = "2dc477793bd82ec39799b6f6b3df64938532fdf2ab0d49ef817eac65856a5a1e",
        strip_prefix = "assert_cmd-0.11.1",
        build_file = Label("//wasm_bindgen/raze/remote:assert_cmd-0.11.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__atty__0_2_14",
        url = "https://crates.io/api/v1/crates/atty/0.2.14/download",
        type = "tar.gz",
        sha256 = "d9b39be18770d11421cdb1b9947a45dd3f37e93092cbf377614828a319d5fee8",
        strip_prefix = "atty-0.2.14",
        build_file = Label("//wasm_bindgen/raze/remote:atty-0.2.14.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__autocfg__0_1_7",
        url = "https://crates.io/api/v1/crates/autocfg/0.1.7/download",
        type = "tar.gz",
        sha256 = "1d49d90015b3c36167a20fe2810c5cd875ad504b39cff3d4eae7977e6b7c1cb2",
        strip_prefix = "autocfg-0.1.7",
        build_file = Label("//wasm_bindgen/raze/remote:autocfg-0.1.7.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__autocfg__1_0_1",
        url = "https://crates.io/api/v1/crates/autocfg/1.0.1/download",
        type = "tar.gz",
        sha256 = "cdb031dd78e28731d87d56cc8ffef4a8f36ca26c38fe2de700543e627f8a464a",
        strip_prefix = "autocfg-1.0.1",
        build_file = Label("//wasm_bindgen/raze/remote:autocfg-1.0.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__backtrace__0_3_53",
        url = "https://crates.io/api/v1/crates/backtrace/0.3.53/download",
        type = "tar.gz",
        sha256 = "707b586e0e2f247cbde68cdd2c3ce69ea7b7be43e1c5b426e37c9319c4b9838e",
        strip_prefix = "backtrace-0.3.53",
        build_file = Label("//wasm_bindgen/raze/remote:backtrace-0.3.53.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__base64__0_12_3",
        url = "https://crates.io/api/v1/crates/base64/0.12.3/download",
        type = "tar.gz",
        sha256 = "3441f0f7b02788e948e47f457ca01f1d7e6d92c693bc132c22b087d3141c03ff",
        strip_prefix = "base64-0.12.3",
        build_file = Label("//wasm_bindgen/raze/remote:base64-0.12.3.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__base64__0_9_3",
        url = "https://crates.io/api/v1/crates/base64/0.9.3/download",
        type = "tar.gz",
        sha256 = "489d6c0ed21b11d038c31b6ceccca973e65d73ba3bd8ecb9a2babf5546164643",
        strip_prefix = "base64-0.9.3",
        build_file = Label("//wasm_bindgen/raze/remote:base64-0.9.3.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__bitflags__1_2_1",
        url = "https://crates.io/api/v1/crates/bitflags/1.2.1/download",
        type = "tar.gz",
        sha256 = "cf1de2fe8c75bc145a2f577add951f8134889b4795d47466a54a5c846d691693",
        strip_prefix = "bitflags-1.2.1",
        build_file = Label("//wasm_bindgen/raze/remote:bitflags-1.2.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__blake2b_simd__0_5_10",
        url = "https://crates.io/api/v1/crates/blake2b_simd/0.5.10/download",
        type = "tar.gz",
        sha256 = "d8fb2d74254a3a0b5cac33ac9f8ed0e44aa50378d9dbb2e5d83bd21ed1dc2c8a",
        strip_prefix = "blake2b_simd-0.5.10",
        build_file = Label("//wasm_bindgen/raze/remote:blake2b_simd-0.5.10.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__buf_redux__0_8_4",
        url = "https://crates.io/api/v1/crates/buf_redux/0.8.4/download",
        type = "tar.gz",
        sha256 = "b953a6887648bb07a535631f2bc00fbdb2a2216f135552cb3f534ed136b9c07f",
        strip_prefix = "buf_redux-0.8.4",
        build_file = Label("//wasm_bindgen/raze/remote:buf_redux-0.8.4.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__byteorder__1_3_4",
        url = "https://crates.io/api/v1/crates/byteorder/1.3.4/download",
        type = "tar.gz",
        sha256 = "08c48aae112d48ed9f069b33538ea9e3e90aa263cfa3d1c24309612b1f7472de",
        strip_prefix = "byteorder-1.3.4",
        build_file = Label("//wasm_bindgen/raze/remote:byteorder-1.3.4.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__cc__1_0_61",
        url = "https://crates.io/api/v1/crates/cc/1.0.61/download",
        type = "tar.gz",
        sha256 = "ed67cbde08356238e75fc4656be4749481eeffb09e19f320a25237d5221c985d",
        strip_prefix = "cc-1.0.61",
        build_file = Label("//wasm_bindgen/raze/remote:cc-1.0.61.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__cfg_if__0_1_10",
        url = "https://crates.io/api/v1/crates/cfg-if/0.1.10/download",
        type = "tar.gz",
        sha256 = "4785bdd1c96b2a846b2bd7cc02e86b6b3dbf14e7e53446c4f54c92a361040822",
        strip_prefix = "cfg-if-0.1.10",
        build_file = Label("//wasm_bindgen/raze/remote:cfg-if-0.1.10.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__cfg_if__1_0_0",
        url = "https://crates.io/api/v1/crates/cfg-if/1.0.0/download",
        type = "tar.gz",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("//wasm_bindgen/raze/remote:cfg-if-1.0.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__chrono__0_4_19",
        url = "https://crates.io/api/v1/crates/chrono/0.4.19/download",
        type = "tar.gz",
        sha256 = "670ad68c9088c2a963aaa298cb369688cf3f9465ce5e2d4ca10e6e0098a1ce73",
        strip_prefix = "chrono-0.4.19",
        build_file = Label("//wasm_bindgen/raze/remote:chrono-0.4.19.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__chunked_transfer__0_3_1",
        url = "https://crates.io/api/v1/crates/chunked_transfer/0.3.1/download",
        type = "tar.gz",
        sha256 = "498d20a7aaf62625b9bf26e637cf7736417cde1d0c99f1d04d1170229a85cf87",
        strip_prefix = "chunked_transfer-0.3.1",
        build_file = Label("//wasm_bindgen/raze/remote:chunked_transfer-0.3.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__cloudabi__0_0_3",
        url = "https://crates.io/api/v1/crates/cloudabi/0.0.3/download",
        type = "tar.gz",
        sha256 = "ddfc5b9aa5d4507acaf872de71051dfd0e309860e88966e1051e462a077aac4f",
        strip_prefix = "cloudabi-0.0.3",
        build_file = Label("//wasm_bindgen/raze/remote:cloudabi-0.0.3.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__constant_time_eq__0_1_5",
        url = "https://crates.io/api/v1/crates/constant_time_eq/0.1.5/download",
        type = "tar.gz",
        sha256 = "245097e9a4535ee1e3e3931fcfcd55a796a44c643e8596ff6566d68f09b87bbc",
        strip_prefix = "constant_time_eq-0.1.5",
        build_file = Label("//wasm_bindgen/raze/remote:constant_time_eq-0.1.5.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__crossbeam_channel__0_4_4",
        url = "https://crates.io/api/v1/crates/crossbeam-channel/0.4.4/download",
        type = "tar.gz",
        sha256 = "b153fe7cbef478c567df0f972e02e6d736db11affe43dfc9c56a9374d1adfb87",
        strip_prefix = "crossbeam-channel-0.4.4",
        build_file = Label("//wasm_bindgen/raze/remote:crossbeam-channel-0.4.4.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__crossbeam_deque__0_7_3",
        url = "https://crates.io/api/v1/crates/crossbeam-deque/0.7.3/download",
        type = "tar.gz",
        sha256 = "9f02af974daeee82218205558e51ec8768b48cf524bd01d550abe5573a608285",
        strip_prefix = "crossbeam-deque-0.7.3",
        build_file = Label("//wasm_bindgen/raze/remote:crossbeam-deque-0.7.3.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__crossbeam_epoch__0_8_2",
        url = "https://crates.io/api/v1/crates/crossbeam-epoch/0.8.2/download",
        type = "tar.gz",
        sha256 = "058ed274caafc1f60c4997b5fc07bf7dc7cca454af7c6e81edffe5f33f70dace",
        strip_prefix = "crossbeam-epoch-0.8.2",
        build_file = Label("//wasm_bindgen/raze/remote:crossbeam-epoch-0.8.2.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__crossbeam_utils__0_7_2",
        url = "https://crates.io/api/v1/crates/crossbeam-utils/0.7.2/download",
        type = "tar.gz",
        sha256 = "c3c7c73a2d1e9fc0886a08b93e98eb643461230d5f1925e4036204d5f2e261a8",
        strip_prefix = "crossbeam-utils-0.7.2",
        build_file = Label("//wasm_bindgen/raze/remote:crossbeam-utils-0.7.2.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__curl__0_4_34",
        url = "https://crates.io/api/v1/crates/curl/0.4.34/download",
        type = "tar.gz",
        sha256 = "e268162af1a5fe89917ae25ba3b0a77c8da752bdc58e7dbb4f15b91fbd33756e",
        strip_prefix = "curl-0.4.34",
        build_file = Label("//wasm_bindgen/raze/remote:curl-0.4.34.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__curl_sys__0_4_38_curl_7_73_0",
        url = "https://crates.io/api/v1/crates/curl-sys/0.4.38+curl-7.73.0/download",
        type = "tar.gz",
        sha256 = "498ecfb4f59997fd40023d62a9f1e506e768b2baeb59a1d311eb9751cdcd7e3f",
        strip_prefix = "curl-sys-0.4.38+curl-7.73.0",
        build_file = Label("//wasm_bindgen/raze/remote:curl-sys-0.4.38+curl-7.73.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__difference__2_0_0",
        url = "https://crates.io/api/v1/crates/difference/2.0.0/download",
        type = "tar.gz",
        sha256 = "524cbf6897b527295dff137cec09ecf3a05f4fddffd7dfcd1585403449e74198",
        strip_prefix = "difference-2.0.0",
        build_file = Label("//wasm_bindgen/raze/remote:difference-2.0.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__dirs__1_0_5",
        url = "https://crates.io/api/v1/crates/dirs/1.0.5/download",
        type = "tar.gz",
        sha256 = "3fd78930633bd1c6e35c4b42b1df7b0cbc6bc191146e512bb3bedf243fcc3901",
        strip_prefix = "dirs-1.0.5",
        build_file = Label("//wasm_bindgen/raze/remote:dirs-1.0.5.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__docopt__1_1_0",
        url = "https://crates.io/api/v1/crates/docopt/1.1.0/download",
        type = "tar.gz",
        sha256 = "7f525a586d310c87df72ebcd98009e57f1cc030c8c268305287a476beb653969",
        strip_prefix = "docopt-1.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:docopt-1.1.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__either__1_6_1",
        url = "https://crates.io/api/v1/crates/either/1.6.1/download",
        type = "tar.gz",
        sha256 = "e78d4f1cc4ae33bbfc157ed5d5a5ef3bc29227303d595861deb238fcec4e9457",
        strip_prefix = "either-1.6.1",
        build_file = Label("//wasm_bindgen/raze/remote:either-1.6.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__env_logger__0_6_2",
        url = "https://crates.io/api/v1/crates/env_logger/0.6.2/download",
        type = "tar.gz",
        sha256 = "aafcde04e90a5226a6443b7aabdb016ba2f8307c847d524724bd9b346dd1a2d3",
        strip_prefix = "env_logger-0.6.2",
        build_file = Label("//wasm_bindgen/raze/remote:env_logger-0.6.2.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__escargot__0_4_0",
        url = "https://crates.io/api/v1/crates/escargot/0.4.0/download",
        type = "tar.gz",
        sha256 = "ceb9adbf9874d5d028b5e4c5739d22b71988252b25c9c98fe7cf9738bee84597",
        strip_prefix = "escargot-0.4.0",
        build_file = Label("//wasm_bindgen/raze/remote:escargot-0.4.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__failure__0_1_8",
        url = "https://crates.io/api/v1/crates/failure/0.1.8/download",
        type = "tar.gz",
        sha256 = "d32e9bd16cc02eae7db7ef620b392808b89f6a5e16bb3497d159c6b92a0f4f86",
        strip_prefix = "failure-0.1.8",
        build_file = Label("//wasm_bindgen/raze/remote:failure-0.1.8.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__failure_derive__0_1_8",
        url = "https://crates.io/api/v1/crates/failure_derive/0.1.8/download",
        type = "tar.gz",
        sha256 = "aa4da3c766cd7a0db8242e326e9e4e081edd567072893ed320008189715366a4",
        strip_prefix = "failure_derive-0.1.8",
        build_file = Label("//wasm_bindgen/raze/remote:failure_derive-0.1.8.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__filetime__0_2_12",
        url = "https://crates.io/api/v1/crates/filetime/0.2.12/download",
        type = "tar.gz",
        sha256 = "3ed85775dcc68644b5c950ac06a2b23768d3bc9390464151aaf27136998dcf9e",
        strip_prefix = "filetime-0.2.12",
        build_file = Label("//wasm_bindgen/raze/remote:filetime-0.2.12.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__float_cmp__0_8_0",
        url = "https://crates.io/api/v1/crates/float-cmp/0.8.0/download",
        type = "tar.gz",
        sha256 = "e1267f4ac4f343772758f7b1bdcbe767c218bbab93bb432acbf5162bbf85a6c4",
        strip_prefix = "float-cmp-0.8.0",
        build_file = Label("//wasm_bindgen/raze/remote:float-cmp-0.8.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__fuchsia_cprng__0_1_1",
        url = "https://crates.io/api/v1/crates/fuchsia-cprng/0.1.1/download",
        type = "tar.gz",
        sha256 = "a06f77d526c1a601b7c4cdd98f54b5eaabffc14d5f2f0296febdc7f357c6d3ba",
        strip_prefix = "fuchsia-cprng-0.1.1",
        build_file = Label("//wasm_bindgen/raze/remote:fuchsia-cprng-0.1.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__getrandom__0_1_15",
        url = "https://crates.io/api/v1/crates/getrandom/0.1.15/download",
        type = "tar.gz",
        sha256 = "fc587bc0ec293155d5bfa6b9891ec18a1e330c234f896ea47fbada4cadbe47e6",
        strip_prefix = "getrandom-0.1.15",
        build_file = Label("//wasm_bindgen/raze/remote:getrandom-0.1.15.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__gimli__0_22_0",
        url = "https://crates.io/api/v1/crates/gimli/0.22.0/download",
        type = "tar.gz",
        sha256 = "aaf91faf136cb47367fa430cd46e37a788775e7fa104f8b4bcb3861dc389b724",
        strip_prefix = "gimli-0.22.0",
        build_file = Label("//wasm_bindgen/raze/remote:gimli-0.22.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__heck__0_3_1",
        url = "https://crates.io/api/v1/crates/heck/0.3.1/download",
        type = "tar.gz",
        sha256 = "20564e78d53d2bb135c343b3f47714a56af2061f1c928fdb541dc7b9fdd94205",
        strip_prefix = "heck-0.3.1",
        build_file = Label("//wasm_bindgen/raze/remote:heck-0.3.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__hermit_abi__0_1_17",
        url = "https://crates.io/api/v1/crates/hermit-abi/0.1.17/download",
        type = "tar.gz",
        sha256 = "5aca5565f760fb5b220e499d72710ed156fdb74e631659e99377d9ebfbd13ae8",
        strip_prefix = "hermit-abi-0.1.17",
        build_file = Label("//wasm_bindgen/raze/remote:hermit-abi-0.1.17.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__httparse__1_3_4",
        url = "https://crates.io/api/v1/crates/httparse/1.3.4/download",
        type = "tar.gz",
        sha256 = "cd179ae861f0c2e53da70d892f5f3029f9594be0c41dc5269cd371691b1dc2f9",
        strip_prefix = "httparse-1.3.4",
        build_file = Label("//wasm_bindgen/raze/remote:httparse-1.3.4.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__humantime__1_3_0",
        url = "https://crates.io/api/v1/crates/humantime/1.3.0/download",
        type = "tar.gz",
        sha256 = "df004cfca50ef23c36850aaaa59ad52cc70d0e90243c3c7737a4dd32dc7a3c4f",
        strip_prefix = "humantime-1.3.0",
        build_file = Label("//wasm_bindgen/raze/remote:humantime-1.3.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__id_arena__2_2_1",
        url = "https://crates.io/api/v1/crates/id-arena/2.2.1/download",
        type = "tar.gz",
        sha256 = "25a2bc672d1148e28034f176e01fffebb08b35768468cc954630da77a1449005",
        strip_prefix = "id-arena-2.2.1",
        build_file = Label("//wasm_bindgen/raze/remote:id-arena-2.2.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__idna__0_1_5",
        url = "https://crates.io/api/v1/crates/idna/0.1.5/download",
        type = "tar.gz",
        sha256 = "38f09e0f0b1fb55fdee1f17470ad800da77af5186a1a76c026b679358b7e844e",
        strip_prefix = "idna-0.1.5",
        build_file = Label("//wasm_bindgen/raze/remote:idna-0.1.5.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__itoa__0_4_6",
        url = "https://crates.io/api/v1/crates/itoa/0.4.6/download",
        type = "tar.gz",
        sha256 = "dc6f3ad7b9d11a0c00842ff8de1b60ee58661048eb8049ed33c73594f359d7e6",
        strip_prefix = "itoa-0.4.6",
        build_file = Label("//wasm_bindgen/raze/remote:itoa-0.4.6.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__lazy_static__1_4_0",
        url = "https://crates.io/api/v1/crates/lazy_static/1.4.0/download",
        type = "tar.gz",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        strip_prefix = "lazy_static-1.4.0",
        build_file = Label("//wasm_bindgen/raze/remote:lazy_static-1.4.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__leb128__0_2_4",
        url = "https://crates.io/api/v1/crates/leb128/0.2.4/download",
        type = "tar.gz",
        sha256 = "3576a87f2ba00f6f106fdfcd16db1d698d648a26ad8e0573cad8537c3c362d2a",
        strip_prefix = "leb128-0.2.4",
        build_file = Label("//wasm_bindgen/raze/remote:leb128-0.2.4.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__libc__0_2_79",
        url = "https://crates.io/api/v1/crates/libc/0.2.79/download",
        type = "tar.gz",
        sha256 = "2448f6066e80e3bfc792e9c98bf705b4b0fc6e8ef5b43e5889aff0eaa9c58743",
        strip_prefix = "libc-0.2.79",
        build_file = Label("//wasm_bindgen/raze/remote:libc-0.2.79.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__libz_sys__1_1_2",
        url = "https://crates.io/api/v1/crates/libz-sys/1.1.2/download",
        type = "tar.gz",
        sha256 = "602113192b08db8f38796c4e85c39e960c145965140e918018bcde1952429655",
        strip_prefix = "libz-sys-1.1.2",
        build_file = Label("//wasm_bindgen/raze/remote:libz-sys-1.1.2.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__log__0_3_9",
        url = "https://crates.io/api/v1/crates/log/0.3.9/download",
        type = "tar.gz",
        sha256 = "e19e8d5c34a3e0e2223db8e060f9e8264aeeb5c5fc64a4ee9965c062211c024b",
        strip_prefix = "log-0.3.9",
        build_file = Label("//wasm_bindgen/raze/remote:log-0.3.9.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__log__0_4_11",
        url = "https://crates.io/api/v1/crates/log/0.4.11/download",
        type = "tar.gz",
        sha256 = "4fabed175da42fed1fa0746b0ea71f412aa9d35e76e95e59b192c64b9dc2bf8b",
        strip_prefix = "log-0.4.11",
        build_file = Label("//wasm_bindgen/raze/remote:log-0.4.11.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__matches__0_1_8",
        url = "https://crates.io/api/v1/crates/matches/0.1.8/download",
        type = "tar.gz",
        sha256 = "7ffc5c5338469d4d3ea17d269fa8ea3512ad247247c30bd2df69e68309ed0a08",
        strip_prefix = "matches-0.1.8",
        build_file = Label("//wasm_bindgen/raze/remote:matches-0.1.8.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__maybe_uninit__2_0_0",
        url = "https://crates.io/api/v1/crates/maybe-uninit/2.0.0/download",
        type = "tar.gz",
        sha256 = "60302e4db3a61da70c0cb7991976248362f30319e88850c487b9b95bbf059e00",
        strip_prefix = "maybe-uninit-2.0.0",
        build_file = Label("//wasm_bindgen/raze/remote:maybe-uninit-2.0.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__memchr__2_3_3",
        url = "https://crates.io/api/v1/crates/memchr/2.3.3/download",
        type = "tar.gz",
        sha256 = "3728d817d99e5ac407411fa471ff9800a778d88a24685968b36824eaf4bee400",
        strip_prefix = "memchr-2.3.3",
        build_file = Label("//wasm_bindgen/raze/remote:memchr-2.3.3.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__memoffset__0_5_6",
        url = "https://crates.io/api/v1/crates/memoffset/0.5.6/download",
        type = "tar.gz",
        sha256 = "043175f069eda7b85febe4a74abbaeff828d9f8b448515d3151a14a3542811aa",
        strip_prefix = "memoffset-0.5.6",
        build_file = Label("//wasm_bindgen/raze/remote:memoffset-0.5.6.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__mime__0_2_6",
        url = "https://crates.io/api/v1/crates/mime/0.2.6/download",
        type = "tar.gz",
        sha256 = "ba626b8a6de5da682e1caa06bdb42a335aee5a84db8e5046a3e8ab17ba0a3ae0",
        strip_prefix = "mime-0.2.6",
        build_file = Label("//wasm_bindgen/raze/remote:mime-0.2.6.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__mime_guess__1_8_8",
        url = "https://crates.io/api/v1/crates/mime_guess/1.8.8/download",
        type = "tar.gz",
        sha256 = "216929a5ee4dd316b1702eedf5e74548c123d370f47841ceaac38ca154690ca3",
        strip_prefix = "mime_guess-1.8.8",
        build_file = Label("//wasm_bindgen/raze/remote:mime_guess-1.8.8.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__miniz_oxide__0_4_3",
        url = "https://crates.io/api/v1/crates/miniz_oxide/0.4.3/download",
        type = "tar.gz",
        sha256 = "0f2d26ec3309788e423cfbf68ad1800f061638098d76a83681af979dc4eda19d",
        strip_prefix = "miniz_oxide-0.4.3",
        build_file = Label("//wasm_bindgen/raze/remote:miniz_oxide-0.4.3.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__multipart__0_15_4",
        url = "https://crates.io/api/v1/crates/multipart/0.15.4/download",
        type = "tar.gz",
        sha256 = "adba94490a79baf2d6a23eac897157047008272fa3eecb3373ae6377b91eca28",
        strip_prefix = "multipart-0.15.4",
        build_file = Label("//wasm_bindgen/raze/remote:multipart-0.15.4.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__normalize_line_endings__0_3_0",
        url = "https://crates.io/api/v1/crates/normalize-line-endings/0.3.0/download",
        type = "tar.gz",
        sha256 = "61807f77802ff30975e01f4f071c8ba10c022052f98b3294119f3e615d13e5be",
        strip_prefix = "normalize-line-endings-0.3.0",
        build_file = Label("//wasm_bindgen/raze/remote:normalize-line-endings-0.3.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__num_integer__0_1_43",
        url = "https://crates.io/api/v1/crates/num-integer/0.1.43/download",
        type = "tar.gz",
        sha256 = "8d59457e662d541ba17869cf51cf177c0b5f0cbf476c66bdc90bf1edac4f875b",
        strip_prefix = "num-integer-0.1.43",
        build_file = Label("//wasm_bindgen/raze/remote:num-integer-0.1.43.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__num_traits__0_2_12",
        url = "https://crates.io/api/v1/crates/num-traits/0.2.12/download",
        type = "tar.gz",
        sha256 = "ac267bcc07f48ee5f8935ab0d24f316fb722d7a1292e2913f0cc196b29ffd611",
        strip_prefix = "num-traits-0.2.12",
        build_file = Label("//wasm_bindgen/raze/remote:num-traits-0.2.12.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__num_cpus__1_13_0",
        url = "https://crates.io/api/v1/crates/num_cpus/1.13.0/download",
        type = "tar.gz",
        sha256 = "05499f3756671c15885fee9034446956fff3f243d6077b91e5767df161f766b3",
        strip_prefix = "num_cpus-1.13.0",
        build_file = Label("//wasm_bindgen/raze/remote:num_cpus-1.13.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__object__0_21_1",
        url = "https://crates.io/api/v1/crates/object/0.21.1/download",
        type = "tar.gz",
        sha256 = "37fd5004feb2ce328a52b0b3d01dbf4ffff72583493900ed15f22d4111c51693",
        strip_prefix = "object-0.21.1",
        build_file = Label("//wasm_bindgen/raze/remote:object-0.21.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__openssl_probe__0_1_2",
        url = "https://crates.io/api/v1/crates/openssl-probe/0.1.2/download",
        type = "tar.gz",
        sha256 = "77af24da69f9d9341038eba93a073b1fdaaa1b788221b00a69bce9e762cb32de",
        strip_prefix = "openssl-probe-0.1.2",
        build_file = Label("//wasm_bindgen/raze/remote:openssl-probe-0.1.2.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__openssl_sys__0_9_58",
        url = "https://crates.io/api/v1/crates/openssl-sys/0.9.58/download",
        type = "tar.gz",
        sha256 = "a842db4709b604f0fe5d1170ae3565899be2ad3d9cbc72dedc789ac0511f78de",
        strip_prefix = "openssl-sys-0.9.58",
        build_file = Label("//wasm_bindgen/raze/remote:openssl-sys-0.9.58.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__percent_encoding__1_0_1",
        url = "https://crates.io/api/v1/crates/percent-encoding/1.0.1/download",
        type = "tar.gz",
        sha256 = "31010dd2e1ac33d5b46a5b413495239882813e0369f8ed8a5e266f173602f831",
        strip_prefix = "percent-encoding-1.0.1",
        build_file = Label("//wasm_bindgen/raze/remote:percent-encoding-1.0.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__phf__0_7_24",
        url = "https://crates.io/api/v1/crates/phf/0.7.24/download",
        type = "tar.gz",
        sha256 = "b3da44b85f8e8dfaec21adae67f95d93244b2ecf6ad2a692320598dcc8e6dd18",
        strip_prefix = "phf-0.7.24",
        build_file = Label("//wasm_bindgen/raze/remote:phf-0.7.24.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__phf_codegen__0_7_24",
        url = "https://crates.io/api/v1/crates/phf_codegen/0.7.24/download",
        type = "tar.gz",
        sha256 = "b03e85129e324ad4166b06b2c7491ae27fe3ec353af72e72cd1654c7225d517e",
        strip_prefix = "phf_codegen-0.7.24",
        build_file = Label("//wasm_bindgen/raze/remote:phf_codegen-0.7.24.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__phf_generator__0_7_24",
        url = "https://crates.io/api/v1/crates/phf_generator/0.7.24/download",
        type = "tar.gz",
        sha256 = "09364cc93c159b8b06b1f4dd8a4398984503483891b0c26b867cf431fb132662",
        strip_prefix = "phf_generator-0.7.24",
        build_file = Label("//wasm_bindgen/raze/remote:phf_generator-0.7.24.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__phf_shared__0_7_24",
        url = "https://crates.io/api/v1/crates/phf_shared/0.7.24/download",
        type = "tar.gz",
        sha256 = "234f71a15de2288bcb7e3b6515828d22af7ec8598ee6d24c3b526fa0a80b67a0",
        strip_prefix = "phf_shared-0.7.24",
        build_file = Label("//wasm_bindgen/raze/remote:phf_shared-0.7.24.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__pkg_config__0_3_19",
        url = "https://crates.io/api/v1/crates/pkg-config/0.3.19/download",
        type = "tar.gz",
        sha256 = "3831453b3449ceb48b6d9c7ad7c96d5ea673e9b470a1dc578c2ce6521230884c",
        strip_prefix = "pkg-config-0.3.19",
        build_file = Label("//wasm_bindgen/raze/remote:pkg-config-0.3.19.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__ppv_lite86__0_2_9",
        url = "https://crates.io/api/v1/crates/ppv-lite86/0.2.9/download",
        type = "tar.gz",
        sha256 = "c36fa947111f5c62a733b652544dd0016a43ce89619538a8ef92724a6f501a20",
        strip_prefix = "ppv-lite86-0.2.9",
        build_file = Label("//wasm_bindgen/raze/remote:ppv-lite86-0.2.9.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__predicates__1_0_5",
        url = "https://crates.io/api/v1/crates/predicates/1.0.5/download",
        type = "tar.gz",
        sha256 = "96bfead12e90dccead362d62bb2c90a5f6fc4584963645bc7f71a735e0b0735a",
        strip_prefix = "predicates-1.0.5",
        build_file = Label("//wasm_bindgen/raze/remote:predicates-1.0.5.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__predicates_core__1_0_0",
        url = "https://crates.io/api/v1/crates/predicates-core/1.0.0/download",
        type = "tar.gz",
        sha256 = "06075c3a3e92559ff8929e7a280684489ea27fe44805174c3ebd9328dcb37178",
        strip_prefix = "predicates-core-1.0.0",
        build_file = Label("//wasm_bindgen/raze/remote:predicates-core-1.0.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__predicates_tree__1_0_0",
        url = "https://crates.io/api/v1/crates/predicates-tree/1.0.0/download",
        type = "tar.gz",
        sha256 = "8e63c4859013b38a76eca2414c64911fba30def9e3202ac461a2d22831220124",
        strip_prefix = "predicates-tree-1.0.0",
        build_file = Label("//wasm_bindgen/raze/remote:predicates-tree-1.0.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__proc_macro2__0_4_30",
        url = "https://crates.io/api/v1/crates/proc-macro2/0.4.30/download",
        type = "tar.gz",
        sha256 = "cf3d2011ab5c909338f7887f4fc896d35932e29146c12c8d01da6b22a80ba759",
        strip_prefix = "proc-macro2-0.4.30",
        build_file = Label("//wasm_bindgen/raze/remote:proc-macro2-0.4.30.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__proc_macro2__1_0_24",
        url = "https://crates.io/api/v1/crates/proc-macro2/1.0.24/download",
        type = "tar.gz",
        sha256 = "1e0704ee1a7e00d7bb417d0770ea303c1bccbabf0ef1667dae92b5967f5f8a71",
        strip_prefix = "proc-macro2-1.0.24",
        build_file = Label("//wasm_bindgen/raze/remote:proc-macro2-1.0.24.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__quick_error__1_2_3",
        url = "https://crates.io/api/v1/crates/quick-error/1.2.3/download",
        type = "tar.gz",
        sha256 = "a1d01941d82fa2ab50be1e79e6714289dd7cde78eba4c074bc5a4374f650dfe0",
        strip_prefix = "quick-error-1.2.3",
        build_file = Label("//wasm_bindgen/raze/remote:quick-error-1.2.3.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__quote__0_6_13",
        url = "https://crates.io/api/v1/crates/quote/0.6.13/download",
        type = "tar.gz",
        sha256 = "6ce23b6b870e8f94f81fb0a363d65d86675884b34a09043c81e5562f11c1f8e1",
        strip_prefix = "quote-0.6.13",
        build_file = Label("//wasm_bindgen/raze/remote:quote-0.6.13.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__quote__1_0_7",
        url = "https://crates.io/api/v1/crates/quote/1.0.7/download",
        type = "tar.gz",
        sha256 = "aa563d17ecb180e500da1cfd2b028310ac758de548efdd203e18f283af693f37",
        strip_prefix = "quote-1.0.7",
        build_file = Label("//wasm_bindgen/raze/remote:quote-1.0.7.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand__0_4_6",
        url = "https://crates.io/api/v1/crates/rand/0.4.6/download",
        type = "tar.gz",
        sha256 = "552840b97013b1a26992c11eac34bdd778e464601a4c2054b5f0bff7c6761293",
        strip_prefix = "rand-0.4.6",
        build_file = Label("//wasm_bindgen/raze/remote:rand-0.4.6.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand__0_5_6",
        url = "https://crates.io/api/v1/crates/rand/0.5.6/download",
        type = "tar.gz",
        sha256 = "c618c47cd3ebd209790115ab837de41425723956ad3ce2e6a7f09890947cacb9",
        strip_prefix = "rand-0.5.6",
        build_file = Label("//wasm_bindgen/raze/remote:rand-0.5.6.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand__0_6_5",
        url = "https://crates.io/api/v1/crates/rand/0.6.5/download",
        type = "tar.gz",
        sha256 = "6d71dacdc3c88c1fde3885a3be3fbab9f35724e6ce99467f7d9c5026132184ca",
        strip_prefix = "rand-0.6.5",
        build_file = Label("//wasm_bindgen/raze/remote:rand-0.6.5.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand__0_7_3",
        url = "https://crates.io/api/v1/crates/rand/0.7.3/download",
        type = "tar.gz",
        sha256 = "6a6b1679d49b24bbfe0c803429aa1874472f50d9b363131f0e89fc356b544d03",
        strip_prefix = "rand-0.7.3",
        build_file = Label("//wasm_bindgen/raze/remote:rand-0.7.3.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_chacha__0_1_1",
        url = "https://crates.io/api/v1/crates/rand_chacha/0.1.1/download",
        type = "tar.gz",
        sha256 = "556d3a1ca6600bfcbab7c7c91ccb085ac7fbbcd70e008a98742e7847f4f7bcef",
        strip_prefix = "rand_chacha-0.1.1",
        build_file = Label("//wasm_bindgen/raze/remote:rand_chacha-0.1.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_chacha__0_2_2",
        url = "https://crates.io/api/v1/crates/rand_chacha/0.2.2/download",
        type = "tar.gz",
        sha256 = "f4c8ed856279c9737206bf725bf36935d8666ead7aa69b52be55af369d193402",
        strip_prefix = "rand_chacha-0.2.2",
        build_file = Label("//wasm_bindgen/raze/remote:rand_chacha-0.2.2.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_core__0_3_1",
        url = "https://crates.io/api/v1/crates/rand_core/0.3.1/download",
        type = "tar.gz",
        sha256 = "7a6fdeb83b075e8266dcc8762c22776f6877a63111121f5f8c7411e5be7eed4b",
        strip_prefix = "rand_core-0.3.1",
        build_file = Label("//wasm_bindgen/raze/remote:rand_core-0.3.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_core__0_4_2",
        url = "https://crates.io/api/v1/crates/rand_core/0.4.2/download",
        type = "tar.gz",
        sha256 = "9c33a3c44ca05fa6f1807d8e6743f3824e8509beca625669633be0acbdf509dc",
        strip_prefix = "rand_core-0.4.2",
        build_file = Label("//wasm_bindgen/raze/remote:rand_core-0.4.2.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_core__0_5_1",
        url = "https://crates.io/api/v1/crates/rand_core/0.5.1/download",
        type = "tar.gz",
        sha256 = "90bde5296fc891b0cef12a6d03ddccc162ce7b2aff54160af9338f8d40df6d19",
        strip_prefix = "rand_core-0.5.1",
        build_file = Label("//wasm_bindgen/raze/remote:rand_core-0.5.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_hc__0_1_0",
        url = "https://crates.io/api/v1/crates/rand_hc/0.1.0/download",
        type = "tar.gz",
        sha256 = "7b40677c7be09ae76218dc623efbf7b18e34bced3f38883af07bb75630a21bc4",
        strip_prefix = "rand_hc-0.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:rand_hc-0.1.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_hc__0_2_0",
        url = "https://crates.io/api/v1/crates/rand_hc/0.2.0/download",
        type = "tar.gz",
        sha256 = "ca3129af7b92a17112d59ad498c6f81eaf463253766b90396d39ea7a39d6613c",
        strip_prefix = "rand_hc-0.2.0",
        build_file = Label("//wasm_bindgen/raze/remote:rand_hc-0.2.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_isaac__0_1_1",
        url = "https://crates.io/api/v1/crates/rand_isaac/0.1.1/download",
        type = "tar.gz",
        sha256 = "ded997c9d5f13925be2a6fd7e66bf1872597f759fd9dd93513dd7e92e5a5ee08",
        strip_prefix = "rand_isaac-0.1.1",
        build_file = Label("//wasm_bindgen/raze/remote:rand_isaac-0.1.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_jitter__0_1_4",
        url = "https://crates.io/api/v1/crates/rand_jitter/0.1.4/download",
        type = "tar.gz",
        sha256 = "1166d5c91dc97b88d1decc3285bb0a99ed84b05cfd0bc2341bdf2d43fc41e39b",
        strip_prefix = "rand_jitter-0.1.4",
        build_file = Label("//wasm_bindgen/raze/remote:rand_jitter-0.1.4.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_os__0_1_3",
        url = "https://crates.io/api/v1/crates/rand_os/0.1.3/download",
        type = "tar.gz",
        sha256 = "7b75f676a1e053fc562eafbb47838d67c84801e38fc1ba459e8f180deabd5071",
        strip_prefix = "rand_os-0.1.3",
        build_file = Label("//wasm_bindgen/raze/remote:rand_os-0.1.3.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_pcg__0_1_2",
        url = "https://crates.io/api/v1/crates/rand_pcg/0.1.2/download",
        type = "tar.gz",
        sha256 = "abf9b09b01790cfe0364f52bf32995ea3c39f4d2dd011eac241d2914146d0b44",
        strip_prefix = "rand_pcg-0.1.2",
        build_file = Label("//wasm_bindgen/raze/remote:rand_pcg-0.1.2.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_xorshift__0_1_1",
        url = "https://crates.io/api/v1/crates/rand_xorshift/0.1.1/download",
        type = "tar.gz",
        sha256 = "cbf7e9e623549b0e21f6e97cf8ecf247c1a8fd2e8a992ae265314300b2455d5c",
        strip_prefix = "rand_xorshift-0.1.1",
        build_file = Label("//wasm_bindgen/raze/remote:rand_xorshift-0.1.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rayon__1_4_1",
        url = "https://crates.io/api/v1/crates/rayon/1.4.1/download",
        type = "tar.gz",
        sha256 = "dcf6960dc9a5b4ee8d3e4c5787b4a112a8818e0290a42ff664ad60692fdf2032",
        strip_prefix = "rayon-1.4.1",
        build_file = Label("//wasm_bindgen/raze/remote:rayon-1.4.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rayon_core__1_8_1",
        url = "https://crates.io/api/v1/crates/rayon-core/1.8.1/download",
        type = "tar.gz",
        sha256 = "e8c4fec834fb6e6d2dd5eece3c7b432a52f0ba887cf40e595190c4107edc08bf",
        strip_prefix = "rayon-core-1.8.1",
        build_file = Label("//wasm_bindgen/raze/remote:rayon-core-1.8.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rdrand__0_4_0",
        url = "https://crates.io/api/v1/crates/rdrand/0.4.0/download",
        type = "tar.gz",
        sha256 = "678054eb77286b51581ba43620cc911abf02758c91f93f479767aed0f90458b2",
        strip_prefix = "rdrand-0.4.0",
        build_file = Label("//wasm_bindgen/raze/remote:rdrand-0.4.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__redox_syscall__0_1_57",
        url = "https://crates.io/api/v1/crates/redox_syscall/0.1.57/download",
        type = "tar.gz",
        sha256 = "41cc0f7e4d5d4544e8861606a285bb08d3e70712ccc7d2b84d7c0ccfaf4b05ce",
        strip_prefix = "redox_syscall-0.1.57",
        build_file = Label("//wasm_bindgen/raze/remote:redox_syscall-0.1.57.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__redox_users__0_3_5",
        url = "https://crates.io/api/v1/crates/redox_users/0.3.5/download",
        type = "tar.gz",
        sha256 = "de0737333e7a9502c789a36d7c7fa6092a49895d4faa31ca5df163857ded2e9d",
        strip_prefix = "redox_users-0.3.5",
        build_file = Label("//wasm_bindgen/raze/remote:redox_users-0.3.5.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__regex__1_4_1",
        url = "https://crates.io/api/v1/crates/regex/1.4.1/download",
        type = "tar.gz",
        sha256 = "8963b85b8ce3074fecffde43b4b0dded83ce2f367dc8d363afc56679f3ee820b",
        strip_prefix = "regex-1.4.1",
        build_file = Label("//wasm_bindgen/raze/remote:regex-1.4.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__regex_syntax__0_6_20",
        url = "https://crates.io/api/v1/crates/regex-syntax/0.6.20/download",
        type = "tar.gz",
        sha256 = "8cab7a364d15cde1e505267766a2d3c4e22a843e1a601f0fa7564c0f82ced11c",
        strip_prefix = "regex-syntax-0.6.20",
        build_file = Label("//wasm_bindgen/raze/remote:regex-syntax-0.6.20.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__remove_dir_all__0_5_3",
        url = "https://crates.io/api/v1/crates/remove_dir_all/0.5.3/download",
        type = "tar.gz",
        sha256 = "3acd125665422973a33ac9d3dd2df85edad0f4ae9b00dafb1a05e43a9f5ef8e7",
        strip_prefix = "remove_dir_all-0.5.3",
        build_file = Label("//wasm_bindgen/raze/remote:remove_dir_all-0.5.3.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rouille__3_0_0",
        url = "https://crates.io/api/v1/crates/rouille/3.0.0/download",
        type = "tar.gz",
        sha256 = "112568052ec17fa26c6c11c40acbb30d3ad244bf3d6da0be181f5e7e42e5004f",
        strip_prefix = "rouille-3.0.0",
        build_file = Label("//wasm_bindgen/raze/remote:rouille-3.0.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rust_argon2__0_8_2",
        url = "https://crates.io/api/v1/crates/rust-argon2/0.8.2/download",
        type = "tar.gz",
        sha256 = "9dab61250775933275e84053ac235621dfb739556d5c54a2f2e9313b7cf43a19",
        strip_prefix = "rust-argon2-0.8.2",
        build_file = Label("//wasm_bindgen/raze/remote:rust-argon2-0.8.2.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rustc_demangle__0_1_17",
        url = "https://crates.io/api/v1/crates/rustc-demangle/0.1.17/download",
        type = "tar.gz",
        sha256 = "b2610b7f643d18c87dff3b489950269617e6601a51f1f05aa5daefee36f64f0b",
        strip_prefix = "rustc-demangle-0.1.17",
        build_file = Label("//wasm_bindgen/raze/remote:rustc-demangle-0.1.17.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__ryu__1_0_5",
        url = "https://crates.io/api/v1/crates/ryu/1.0.5/download",
        type = "tar.gz",
        sha256 = "71d301d4193d031abdd79ff7e3dd721168a9572ef3fe51a1517aba235bd8f86e",
        strip_prefix = "ryu-1.0.5",
        build_file = Label("//wasm_bindgen/raze/remote:ryu-1.0.5.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__safemem__0_3_3",
        url = "https://crates.io/api/v1/crates/safemem/0.3.3/download",
        type = "tar.gz",
        sha256 = "ef703b7cb59335eae2eb93ceb664c0eb7ea6bf567079d843e09420219668e072",
        strip_prefix = "safemem-0.3.3",
        build_file = Label("//wasm_bindgen/raze/remote:safemem-0.3.3.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__schannel__0_1_19",
        url = "https://crates.io/api/v1/crates/schannel/0.1.19/download",
        type = "tar.gz",
        sha256 = "8f05ba609c234e60bee0d547fe94a4c7e9da733d1c962cf6e59efa4cd9c8bc75",
        strip_prefix = "schannel-0.1.19",
        build_file = Label("//wasm_bindgen/raze/remote:schannel-0.1.19.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__scopeguard__1_1_0",
        url = "https://crates.io/api/v1/crates/scopeguard/1.1.0/download",
        type = "tar.gz",
        sha256 = "d29ab0c6d3fc0ee92fe66e2d99f700eab17a8d57d1c1d3b748380fb20baa78cd",
        strip_prefix = "scopeguard-1.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:scopeguard-1.1.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__serde__1_0_116",
        url = "https://crates.io/api/v1/crates/serde/1.0.116/download",
        type = "tar.gz",
        sha256 = "96fe57af81d28386a513cbc6858332abc6117cfdb5999647c6444b8f43a370a5",
        strip_prefix = "serde-1.0.116",
        build_file = Label("//wasm_bindgen/raze/remote:serde-1.0.116.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__serde_derive__1_0_116",
        url = "https://crates.io/api/v1/crates/serde_derive/1.0.116/download",
        type = "tar.gz",
        sha256 = "f630a6370fd8e457873b4bd2ffdae75408bc291ba72be773772a4c2a065d9ae8",
        strip_prefix = "serde_derive-1.0.116",
        build_file = Label("//wasm_bindgen/raze/remote:serde_derive-1.0.116.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__serde_json__1_0_59",
        url = "https://crates.io/api/v1/crates/serde_json/1.0.59/download",
        type = "tar.gz",
        sha256 = "dcac07dbffa1c65e7f816ab9eba78eb142c6d44410f4eeba1e26e4f5dfa56b95",
        strip_prefix = "serde_json-1.0.59",
        build_file = Label("//wasm_bindgen/raze/remote:serde_json-1.0.59.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__sha1__0_6_0",
        url = "https://crates.io/api/v1/crates/sha1/0.6.0/download",
        type = "tar.gz",
        sha256 = "2579985fda508104f7587689507983eadd6a6e84dd35d6d115361f530916fa0d",
        strip_prefix = "sha1-0.6.0",
        build_file = Label("//wasm_bindgen/raze/remote:sha1-0.6.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__siphasher__0_2_3",
        url = "https://crates.io/api/v1/crates/siphasher/0.2.3/download",
        type = "tar.gz",
        sha256 = "0b8de496cf83d4ed58b6be86c3a275b8602f6ffe98d3024a869e124147a9a3ac",
        strip_prefix = "siphasher-0.2.3",
        build_file = Label("//wasm_bindgen/raze/remote:siphasher-0.2.3.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__socket2__0_3_15",
        url = "https://crates.io/api/v1/crates/socket2/0.3.15/download",
        type = "tar.gz",
        sha256 = "b1fa70dc5c8104ec096f4fe7ede7a221d35ae13dcd19ba1ad9a81d2cab9a1c44",
        strip_prefix = "socket2-0.3.15",
        build_file = Label("//wasm_bindgen/raze/remote:socket2-0.3.15.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__strsim__0_9_3",
        url = "https://crates.io/api/v1/crates/strsim/0.9.3/download",
        type = "tar.gz",
        sha256 = "6446ced80d6c486436db5c078dde11a9f73d42b57fb273121e160b84f63d894c",
        strip_prefix = "strsim-0.9.3",
        build_file = Label("//wasm_bindgen/raze/remote:strsim-0.9.3.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__syn__0_15_44",
        url = "https://crates.io/api/v1/crates/syn/0.15.44/download",
        type = "tar.gz",
        sha256 = "9ca4b3b69a77cbe1ffc9e198781b7acb0c7365a883670e8f1c1bc66fba79a5c5",
        strip_prefix = "syn-0.15.44",
        build_file = Label("//wasm_bindgen/raze/remote:syn-0.15.44.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__syn__1_0_44",
        url = "https://crates.io/api/v1/crates/syn/1.0.44/download",
        type = "tar.gz",
        sha256 = "e03e57e4fcbfe7749842d53e24ccb9aa12b7252dbe5e91d2acad31834c8b8fdd",
        strip_prefix = "syn-1.0.44",
        build_file = Label("//wasm_bindgen/raze/remote:syn-1.0.44.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__synstructure__0_12_4",
        url = "https://crates.io/api/v1/crates/synstructure/0.12.4/download",
        type = "tar.gz",
        sha256 = "b834f2d66f734cb897113e34aaff2f1ab4719ca946f9a7358dba8f8064148701",
        strip_prefix = "synstructure-0.12.4",
        build_file = Label("//wasm_bindgen/raze/remote:synstructure-0.12.4.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__tempdir__0_3_7",
        url = "https://crates.io/api/v1/crates/tempdir/0.3.7/download",
        type = "tar.gz",
        sha256 = "15f2b5fb00ccdf689e0149d1b1b3c03fead81c2b37735d812fa8bddbbf41b6d8",
        strip_prefix = "tempdir-0.3.7",
        build_file = Label("//wasm_bindgen/raze/remote:tempdir-0.3.7.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__tempfile__3_1_0",
        url = "https://crates.io/api/v1/crates/tempfile/3.1.0/download",
        type = "tar.gz",
        sha256 = "7a6e24d9338a0a5be79593e2fa15a648add6138caa803e2d5bc782c371732ca9",
        strip_prefix = "tempfile-3.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:tempfile-3.1.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__term__0_5_2",
        url = "https://crates.io/api/v1/crates/term/0.5.2/download",
        type = "tar.gz",
        sha256 = "edd106a334b7657c10b7c540a0106114feadeb4dc314513e97df481d5d966f42",
        strip_prefix = "term-0.5.2",
        build_file = Label("//wasm_bindgen/raze/remote:term-0.5.2.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__termcolor__1_1_0",
        url = "https://crates.io/api/v1/crates/termcolor/1.1.0/download",
        type = "tar.gz",
        sha256 = "bb6bfa289a4d7c5766392812c0a1f4c1ba45afa1ad47803c11e1f407d846d75f",
        strip_prefix = "termcolor-1.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:termcolor-1.1.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__thread_local__1_0_1",
        url = "https://crates.io/api/v1/crates/thread_local/1.0.1/download",
        type = "tar.gz",
        sha256 = "d40c6d1b69745a6ec6fb1ca717914848da4b44ae29d9b3080cbee91d72a69b14",
        strip_prefix = "thread_local-1.0.1",
        build_file = Label("//wasm_bindgen/raze/remote:thread_local-1.0.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__threadpool__1_8_1",
        url = "https://crates.io/api/v1/crates/threadpool/1.8.1/download",
        type = "tar.gz",
        sha256 = "d050e60b33d41c19108b32cea32164033a9013fe3b46cbd4457559bfbf77afaa",
        strip_prefix = "threadpool-1.8.1",
        build_file = Label("//wasm_bindgen/raze/remote:threadpool-1.8.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__time__0_1_44",
        url = "https://crates.io/api/v1/crates/time/0.1.44/download",
        type = "tar.gz",
        sha256 = "6db9e6914ab8b1ae1c260a4ae7a49b6c5611b40328a735b21862567685e73255",
        strip_prefix = "time-0.1.44",
        build_file = Label("//wasm_bindgen/raze/remote:time-0.1.44.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__tiny_http__0_6_2",
        url = "https://crates.io/api/v1/crates/tiny_http/0.6.2/download",
        type = "tar.gz",
        sha256 = "1661fa0a44c95d01604bd05c66732a446c657efb62b5164a7a083a3b552b4951",
        strip_prefix = "tiny_http-0.6.2",
        build_file = Label("//wasm_bindgen/raze/remote:tiny_http-0.6.2.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__tinyvec__0_3_4",
        url = "https://crates.io/api/v1/crates/tinyvec/0.3.4/download",
        type = "tar.gz",
        sha256 = "238ce071d267c5710f9d31451efec16c5ee22de34df17cc05e56cbc92e967117",
        strip_prefix = "tinyvec-0.3.4",
        build_file = Label("//wasm_bindgen/raze/remote:tinyvec-0.3.4.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__treeline__0_1_0",
        url = "https://crates.io/api/v1/crates/treeline/0.1.0/download",
        type = "tar.gz",
        sha256 = "a7f741b240f1a48843f9b8e0444fb55fb2a4ff67293b50a9179dfd5ea67f8d41",
        strip_prefix = "treeline-0.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:treeline-0.1.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__twoway__0_1_8",
        url = "https://crates.io/api/v1/crates/twoway/0.1.8/download",
        type = "tar.gz",
        sha256 = "59b11b2b5241ba34be09c3cc85a36e56e48f9888862e19cedf23336d35316ed1",
        strip_prefix = "twoway-0.1.8",
        build_file = Label("//wasm_bindgen/raze/remote:twoway-0.1.8.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__unicase__1_4_2",
        url = "https://crates.io/api/v1/crates/unicase/1.4.2/download",
        type = "tar.gz",
        sha256 = "7f4765f83163b74f957c797ad9253caf97f103fb064d3999aea9568d09fc8a33",
        strip_prefix = "unicase-1.4.2",
        build_file = Label("//wasm_bindgen/raze/remote:unicase-1.4.2.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__unicode_bidi__0_3_4",
        url = "https://crates.io/api/v1/crates/unicode-bidi/0.3.4/download",
        type = "tar.gz",
        sha256 = "49f2bd0c6468a8230e1db229cff8029217cf623c767ea5d60bfbd42729ea54d5",
        strip_prefix = "unicode-bidi-0.3.4",
        build_file = Label("//wasm_bindgen/raze/remote:unicode-bidi-0.3.4.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__unicode_normalization__0_1_13",
        url = "https://crates.io/api/v1/crates/unicode-normalization/0.1.13/download",
        type = "tar.gz",
        sha256 = "6fb19cf769fa8c6a80a162df694621ebeb4dafb606470b2b2fce0be40a98a977",
        strip_prefix = "unicode-normalization-0.1.13",
        build_file = Label("//wasm_bindgen/raze/remote:unicode-normalization-0.1.13.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__unicode_segmentation__1_6_0",
        url = "https://crates.io/api/v1/crates/unicode-segmentation/1.6.0/download",
        type = "tar.gz",
        sha256 = "e83e153d1053cbb5a118eeff7fd5be06ed99153f00dbcd8ae310c5fb2b22edc0",
        strip_prefix = "unicode-segmentation-1.6.0",
        build_file = Label("//wasm_bindgen/raze/remote:unicode-segmentation-1.6.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__unicode_xid__0_1_0",
        url = "https://crates.io/api/v1/crates/unicode-xid/0.1.0/download",
        type = "tar.gz",
        sha256 = "fc72304796d0818e357ead4e000d19c9c174ab23dc11093ac919054d20a6a7fc",
        strip_prefix = "unicode-xid-0.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:unicode-xid-0.1.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__unicode_xid__0_2_1",
        url = "https://crates.io/api/v1/crates/unicode-xid/0.2.1/download",
        type = "tar.gz",
        sha256 = "f7fe0bb3479651439c9112f72b6c505038574c9fbb575ed1bf3b797fa39dd564",
        strip_prefix = "unicode-xid-0.2.1",
        build_file = Label("//wasm_bindgen/raze/remote:unicode-xid-0.2.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__url__1_7_2",
        url = "https://crates.io/api/v1/crates/url/1.7.2/download",
        type = "tar.gz",
        sha256 = "dd4e7c0d531266369519a4aa4f399d748bd37043b00bde1e4ff1f60a120b355a",
        strip_prefix = "url-1.7.2",
        build_file = Label("//wasm_bindgen/raze/remote:url-1.7.2.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__vcpkg__0_2_10",
        url = "https://crates.io/api/v1/crates/vcpkg/0.2.10/download",
        type = "tar.gz",
        sha256 = "6454029bf181f092ad1b853286f23e2c507d8e8194d01d92da4a55c274a5508c",
        strip_prefix = "vcpkg-0.2.10",
        build_file = Label("//wasm_bindgen/raze/remote:vcpkg-0.2.10.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__version_check__0_1_5",
        url = "https://crates.io/api/v1/crates/version_check/0.1.5/download",
        type = "tar.gz",
        sha256 = "914b1a6776c4c929a602fafd8bc742e06365d4bcbe48c30f9cca5824f70dc9dd",
        strip_prefix = "version_check-0.1.5",
        build_file = Label("//wasm_bindgen/raze/remote:version_check-0.1.5.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__walrus__0_8_0",
        url = "https://crates.io/api/v1/crates/walrus/0.8.0/download",
        type = "tar.gz",
        sha256 = "9b751c638c5c86d92af28a3a68ce879b719c7e1cad75c66a3377ce386b9d705f",
        strip_prefix = "walrus-0.8.0",
        build_file = Label("//wasm_bindgen/raze/remote:walrus-0.8.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__walrus_macro__0_8_0",
        url = "https://crates.io/api/v1/crates/walrus-macro/0.8.0/download",
        type = "tar.gz",
        sha256 = "30dcc194dbffb8025ca1b42a92f8c33ac28b1025cd771f0d884f89508b5fb094",
        strip_prefix = "walrus-macro-0.8.0",
        build_file = Label("//wasm_bindgen/raze/remote:walrus-macro-0.8.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasi__0_10_0_wasi_snapshot_preview1",
        url = "https://crates.io/api/v1/crates/wasi/0.10.0+wasi-snapshot-preview1/download",
        type = "tar.gz",
        sha256 = "1a143597ca7c7793eff794def352d41792a93c481eb1042423ff7ff72ba2c31f",
        strip_prefix = "wasi-0.10.0+wasi-snapshot-preview1",
        build_file = Label("//wasm_bindgen/raze/remote:wasi-0.10.0+wasi-snapshot-preview1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasi__0_9_0_wasi_snapshot_preview1",
        url = "https://crates.io/api/v1/crates/wasi/0.9.0+wasi-snapshot-preview1/download",
        type = "tar.gz",
        sha256 = "cccddf32554fecc6acb585f82a32a72e28b48f8c4c1883ddfeeeaa96f7d8e519",
        strip_prefix = "wasi-0.9.0+wasi-snapshot-preview1",
        build_file = Label("//wasm_bindgen/raze/remote:wasi-0.9.0+wasi-snapshot-preview1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_anyref_xform__0_2_48",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-anyref-xform/0.2.48/download",
        type = "tar.gz",
        sha256 = "96b9065758e62fd7a445c1b37f427edc69771c400f13771ff0653e49fd39a8e7",
        strip_prefix = "wasm-bindgen-anyref-xform-0.2.48",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-anyref-xform-0.2.48.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_cli__0_2_48",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-cli/0.2.48/download",
        type = "tar.gz",
        sha256 = "ceb1786f6098700f9e2b33ad640392920c84cee6e9bdd8251e44e35fac472638",
        strip_prefix = "wasm-bindgen-cli-0.2.48",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-cli-0.2.48.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_cli_support__0_2_48",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-cli-support/0.2.48/download",
        type = "tar.gz",
        sha256 = "66aae0d39c155c9bf27b3c21113120d4c47bb0193234f15b98448b7b119c87be",
        strip_prefix = "wasm-bindgen-cli-support-0.2.48",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-cli-support-0.2.48.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_shared__0_2_48",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-shared/0.2.48/download",
        type = "tar.gz",
        sha256 = "d9c2d4d4756b2e46d3a5422e06277d02e4d3e1d62d138b76a4c681e925743623",
        strip_prefix = "wasm-bindgen-shared-0.2.48",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-shared-0.2.48.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_threads_xform__0_2_48",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-threads-xform/0.2.48/download",
        type = "tar.gz",
        sha256 = "61de14e4283261b9ce99b15bd3fb52a4c8f56a3efef4b46cf2fa11c2a180be10",
        strip_prefix = "wasm-bindgen-threads-xform-0.2.48",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-threads-xform-0.2.48.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_wasm_interpreter__0_2_48",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-wasm-interpreter/0.2.48/download",
        type = "tar.gz",
        sha256 = "7cfc73f030ca101c85e75f5c5e2db061e762ff600edd77693c5c8581b90bdfe6",
        strip_prefix = "wasm-bindgen-wasm-interpreter-0.2.48",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-wasm-interpreter-0.2.48.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_webidl_bindings__0_1_2",
        url = "https://crates.io/api/v1/crates/wasm-webidl-bindings/0.1.2/download",
        type = "tar.gz",
        sha256 = "216c964db43e07890435d9b152e59f0f520787ebed2c0666609fe8d933c3b749",
        strip_prefix = "wasm-webidl-bindings-0.1.2",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-webidl-bindings-0.1.2.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasmparser__0_30_0",
        url = "https://crates.io/api/v1/crates/wasmparser/0.30.0/download",
        type = "tar.gz",
        sha256 = "566a9eefa2267a1a32af59807326e84191cdff41c3fc2efda0a790d821615b31",
        strip_prefix = "wasmparser-0.30.0",
        build_file = Label("//wasm_bindgen/raze/remote:wasmparser-0.30.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__winapi__0_3_9",
        url = "https://crates.io/api/v1/crates/winapi/0.3.9/download",
        type = "tar.gz",
        sha256 = "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419",
        strip_prefix = "winapi-0.3.9",
        build_file = Label("//wasm_bindgen/raze/remote:winapi-0.3.9.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__winapi_i686_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-i686-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("//wasm_bindgen/raze/remote:winapi-i686-pc-windows-gnu-0.4.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__winapi_util__0_1_5",
        url = "https://crates.io/api/v1/crates/winapi-util/0.1.5/download",
        type = "tar.gz",
        sha256 = "70ec6ce85bb158151cae5e5c87f95a8e97d2c0c4b001223f33a334e3ce5de178",
        strip_prefix = "winapi-util-0.1.5",
        build_file = Label("//wasm_bindgen/raze/remote:winapi-util-0.1.5.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__winapi_x86_64_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-x86_64-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("//wasm_bindgen/raze/remote:winapi-x86_64-pc-windows-gnu-0.4.0.BUILD"),
    )
