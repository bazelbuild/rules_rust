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
        name = "rules_rust_wasm_bindgen__bumpalo__3_4_0",
        url = "https://crates.io/api/v1/crates/bumpalo/3.4.0/download",
        type = "tar.gz",
        sha256 = "2e8c087f005730276d1096a652e92a8bacee2e2472bcc9715a74d2bec38b5820",
        strip_prefix = "bumpalo-3.4.0",
        build_file = Label("//wasm_bindgen/raze/remote:bumpalo-3.4.0.BUILD"),
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
        name = "rules_rust_wasm_bindgen__log__0_4_11",
        url = "https://crates.io/api/v1/crates/log/0.4.11/download",
        type = "tar.gz",
        sha256 = "4fabed175da42fed1fa0746b0ea71f412aa9d35e76e95e59b192c64b9dc2bf8b",
        strip_prefix = "log-0.4.11",
        build_file = Label("//wasm_bindgen/raze/remote:log-0.4.11.BUILD"),
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
        name = "rules_rust_wasm_bindgen__quote__1_0_7",
        url = "https://crates.io/api/v1/crates/quote/1.0.7/download",
        type = "tar.gz",
        sha256 = "aa563d17ecb180e500da1cfd2b028310ac758de548efdd203e18f283af693f37",
        strip_prefix = "quote-1.0.7",
        build_file = Label("//wasm_bindgen/raze/remote:quote-1.0.7.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__syn__1_0_45",
        url = "https://crates.io/api/v1/crates/syn/1.0.45/download",
        type = "tar.gz",
        sha256 = "ea9c5432ff16d6152371f808fb5a871cd67368171b09bb21b43df8e4a47a3556",
        strip_prefix = "syn-1.0.45",
        build_file = Label("//wasm_bindgen/raze/remote:syn-1.0.45.BUILD"),
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
        name = "rules_rust_wasm_bindgen__wasm_bindgen__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen/0.2.68/download",
        type = "tar.gz",
        sha256 = "1ac64ead5ea5f05873d7c12b545865ca2b8d28adfc50a49b84770a3a97265d42",
        strip_prefix = "wasm-bindgen-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-0.2.68.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_backend__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-backend/0.2.68/download",
        type = "tar.gz",
        sha256 = "f22b422e2a757c35a73774860af8e112bff612ce6cb604224e8e47641a9e4f68",
        strip_prefix = "wasm-bindgen-backend-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-backend-0.2.68.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_macro__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-macro/0.2.68/download",
        type = "tar.gz",
        sha256 = "6b13312a745c08c469f0b292dd2fcd6411dba5f7160f593da6ef69b64e407038",
        strip_prefix = "wasm-bindgen-macro-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-macro-0.2.68.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_macro_support__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-macro-support/0.2.68/download",
        type = "tar.gz",
        sha256 = "f249f06ef7ee334cc3b8ff031bfc11ec99d00f34d86da7498396dc1e3b1498fe",
        strip_prefix = "wasm-bindgen-macro-support-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-macro-support-0.2.68.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_shared__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-shared/0.2.68/download",
        type = "tar.gz",
        sha256 = "1d649a3145108d7d3fbcde896a468d1bd636791823c9921135218ad89be08307",
        strip_prefix = "wasm-bindgen-shared-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-shared-0.2.68.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__aho_corasick__0_7_13",
        url = "https://crates.io/api/v1/crates/aho-corasick/0.7.13/download",
        type = "tar.gz",
        sha256 = "043164d8ba5c4c3035fec9bbee8647c0261d788f3474306f93bb65901cae0e86",
        strip_prefix = "aho-corasick-0.7.13",
        build_file = Label("//wasm_bindgen/raze/remote:aho-corasick-0.7.13.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__anyhow__1_0_32",
        url = "https://crates.io/api/v1/crates/anyhow/1.0.32/download",
        type = "tar.gz",
        sha256 = "6b602bfe940d21c130f3895acd65221e8a61270debe89d628b9cb4e3ccb8569b",
        strip_prefix = "anyhow-1.0.32",
        build_file = Label("//wasm_bindgen/raze/remote:anyhow-1.0.32.BUILD"),
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
        name = "rules_rust_wasm_bindgen__assert_cmd__1_0_1",
        url = "https://crates.io/api/v1/crates/assert_cmd/1.0.1/download",
        type = "tar.gz",
        sha256 = "c88b9ca26f9c16ec830350d309397e74ee9abdfd8eb1f71cb6ecc71a3fc818da",
        strip_prefix = "assert_cmd-1.0.1",
        build_file = Label("//wasm_bindgen/raze/remote:assert_cmd-1.0.1.BUILD"),
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
        name = "rules_rust_wasm_bindgen__cc__1_0_59",
        url = "https://crates.io/api/v1/crates/cc/1.0.59/download",
        type = "tar.gz",
        sha256 = "66120af515773fb005778dc07c261bd201ec8ce50bd6e7144c927753fe013381",
        strip_prefix = "cc-1.0.59",
        build_file = Label("//wasm_bindgen/raze/remote:cc-1.0.59.BUILD"),
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
        name = "rules_rust_wasm_bindgen__chrono__0_4_15",
        url = "https://crates.io/api/v1/crates/chrono/0.4.15/download",
        type = "tar.gz",
        sha256 = "942f72db697d8767c22d46a598e01f2d3b475501ea43d0db4f16d90259182d0b",
        strip_prefix = "chrono-0.4.15",
        build_file = Label("//wasm_bindgen/raze/remote:chrono-0.4.15.BUILD"),
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
        name = "rules_rust_wasm_bindgen__curl__0_4_33",
        url = "https://crates.io/api/v1/crates/curl/0.4.33/download",
        type = "tar.gz",
        sha256 = "78baca05127a115136a9898e266988fc49ca7ea2c839f60fc6e1fc9df1599168",
        strip_prefix = "curl-0.4.33",
        build_file = Label("//wasm_bindgen/raze/remote:curl-0.4.33.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__curl_sys__0_4_36_curl_7_71_1",
        url = "https://crates.io/api/v1/crates/curl-sys/0.4.36+curl-7.71.1/download",
        type = "tar.gz",
        sha256 = "68cad94adeb0c16558429c3c34a607acc9ea58e09a7b66310aabc9788fc5d721",
        strip_prefix = "curl-sys-0.4.36+curl-7.71.1",
        build_file = Label("//wasm_bindgen/raze/remote:curl-sys-0.4.36+curl-7.71.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__diff__0_1_12",
        url = "https://crates.io/api/v1/crates/diff/0.1.12/download",
        type = "tar.gz",
        sha256 = "0e25ea47919b1560c4e3b7fe0aaab9becf5b84a10325ddf7db0f0ba5e1026499",
        strip_prefix = "diff-0.1.12",
        build_file = Label("//wasm_bindgen/raze/remote:diff-0.1.12.BUILD"),
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
        name = "rules_rust_wasm_bindgen__doc_comment__0_3_3",
        url = "https://crates.io/api/v1/crates/doc-comment/0.3.3/download",
        type = "tar.gz",
        sha256 = "fea41bba32d969b513997752735605054bc0dfa92b4c56bf1189f2e174be7a10",
        strip_prefix = "doc-comment-0.3.3",
        build_file = Label("//wasm_bindgen/raze/remote:doc-comment-0.3.3.BUILD"),
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
        name = "rules_rust_wasm_bindgen__either__1_6_0",
        url = "https://crates.io/api/v1/crates/either/1.6.0/download",
        type = "tar.gz",
        sha256 = "cd56b59865bce947ac5958779cfa508f6c3b9497cc762b7e24a12d11ccde2c4f",
        strip_prefix = "either-1.6.0",
        build_file = Label("//wasm_bindgen/raze/remote:either-1.6.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__env_logger__0_7_1",
        url = "https://crates.io/api/v1/crates/env_logger/0.7.1/download",
        type = "tar.gz",
        sha256 = "44533bbbb3bb3c1fa17d9f2e4e38bbbaf8396ba82193c4cb1b6445d711445d36",
        strip_prefix = "env_logger-0.7.1",
        build_file = Label("//wasm_bindgen/raze/remote:env_logger-0.7.1.BUILD"),
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
        name = "rules_rust_wasm_bindgen__getrandom__0_1_14",
        url = "https://crates.io/api/v1/crates/getrandom/0.1.14/download",
        type = "tar.gz",
        sha256 = "7abc8dd8451921606d809ba32e95b6111925cd2906060d2dcc29c070220503eb",
        strip_prefix = "getrandom-0.1.14",
        build_file = Label("//wasm_bindgen/raze/remote:getrandom-0.1.14.BUILD"),
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
        name = "rules_rust_wasm_bindgen__hermit_abi__0_1_15",
        url = "https://crates.io/api/v1/crates/hermit-abi/0.1.15/download",
        type = "tar.gz",
        sha256 = "3deed196b6e7f9e44a2ae8d94225d80302d81208b1bb673fd21fe634645c85a9",
        strip_prefix = "hermit-abi-0.1.15",
        build_file = Label("//wasm_bindgen/raze/remote:hermit-abi-0.1.15.BUILD"),
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
        name = "rules_rust_wasm_bindgen__libc__0_2_76",
        url = "https://crates.io/api/v1/crates/libc/0.2.76/download",
        type = "tar.gz",
        sha256 = "755456fae044e6fa1ebbbd1b3e902ae19e73097ed4ed87bb79934a867c007bc3",
        strip_prefix = "libc-0.2.76",
        build_file = Label("//wasm_bindgen/raze/remote:libc-0.2.76.BUILD"),
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
        name = "rules_rust_wasm_bindgen__memoffset__0_5_5",
        url = "https://crates.io/api/v1/crates/memoffset/0.5.5/download",
        type = "tar.gz",
        sha256 = "c198b026e1bbf08a937e94c6c60f9ec4a2267f5b0d2eec9c1b21b061ce2be55f",
        strip_prefix = "memoffset-0.5.5",
        build_file = Label("//wasm_bindgen/raze/remote:memoffset-0.5.5.BUILD"),
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
        name = "rules_rust_wasm_bindgen__pkg_config__0_3_18",
        url = "https://crates.io/api/v1/crates/pkg-config/0.3.18/download",
        type = "tar.gz",
        sha256 = "d36492546b6af1463394d46f0c834346f31548646f6ba10849802c9c9a27ac33",
        strip_prefix = "pkg-config-0.3.18",
        build_file = Label("//wasm_bindgen/raze/remote:pkg-config-0.3.18.BUILD"),
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
        name = "rules_rust_wasm_bindgen__rayon__1_4_0",
        url = "https://crates.io/api/v1/crates/rayon/1.4.0/download",
        type = "tar.gz",
        sha256 = "cfd016f0c045ad38b5251be2c9c0ab806917f82da4d36b2a327e5166adad9270",
        strip_prefix = "rayon-1.4.0",
        build_file = Label("//wasm_bindgen/raze/remote:rayon-1.4.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rayon_core__1_8_0",
        url = "https://crates.io/api/v1/crates/rayon-core/1.8.0/download",
        type = "tar.gz",
        sha256 = "91739a34c4355b5434ce54c9086c5895604a9c278586d1f1aa95e04f66b525a0",
        strip_prefix = "rayon-core-1.8.0",
        build_file = Label("//wasm_bindgen/raze/remote:rayon-core-1.8.0.BUILD"),
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
        name = "rules_rust_wasm_bindgen__regex__1_3_9",
        url = "https://crates.io/api/v1/crates/regex/1.3.9/download",
        type = "tar.gz",
        sha256 = "9c3780fcf44b193bc4d09f36d2a3c87b251da4a046c87795a0d35f4f927ad8e6",
        strip_prefix = "regex-1.3.9",
        build_file = Label("//wasm_bindgen/raze/remote:regex-1.3.9.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__regex_syntax__0_6_18",
        url = "https://crates.io/api/v1/crates/regex-syntax/0.6.18/download",
        type = "tar.gz",
        sha256 = "26412eb97c6b088a6997e05f69403a802a92d520de2f8e63c2b65f9e0f47c4e8",
        strip_prefix = "regex-syntax-0.6.18",
        build_file = Label("//wasm_bindgen/raze/remote:regex-syntax-0.6.18.BUILD"),
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
        name = "rules_rust_wasm_bindgen__rustc_demangle__0_1_16",
        url = "https://crates.io/api/v1/crates/rustc-demangle/0.1.16/download",
        type = "tar.gz",
        sha256 = "4c691c0e608126e00913e33f0ccf3727d5fc84573623b8d65b2df340b5201783",
        strip_prefix = "rustc-demangle-0.1.16",
        build_file = Label("//wasm_bindgen/raze/remote:rustc-demangle-0.1.16.BUILD"),
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
        name = "rules_rust_wasm_bindgen__serde__1_0_115",
        url = "https://crates.io/api/v1/crates/serde/1.0.115/download",
        type = "tar.gz",
        sha256 = "e54c9a88f2da7238af84b5101443f0c0d0a3bbdc455e34a5c9497b1903ed55d5",
        strip_prefix = "serde-1.0.115",
        build_file = Label("//wasm_bindgen/raze/remote:serde-1.0.115.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__serde_derive__1_0_115",
        url = "https://crates.io/api/v1/crates/serde_derive/1.0.115/download",
        type = "tar.gz",
        sha256 = "609feed1d0a73cc36a0182a840a9b37b4a82f0b1150369f0536a9e3f2a31dc48",
        strip_prefix = "serde_derive-1.0.115",
        build_file = Label("//wasm_bindgen/raze/remote:serde_derive-1.0.115.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__serde_json__1_0_57",
        url = "https://crates.io/api/v1/crates/serde_json/1.0.57/download",
        type = "tar.gz",
        sha256 = "164eacbdb13512ec2745fb09d51fd5b22b0d65ed294a1dcf7285a360c80a675c",
        strip_prefix = "serde_json-1.0.57",
        build_file = Label("//wasm_bindgen/raze/remote:serde_json-1.0.57.BUILD"),
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
        name = "rules_rust_wasm_bindgen__socket2__0_3_12",
        url = "https://crates.io/api/v1/crates/socket2/0.3.12/download",
        type = "tar.gz",
        sha256 = "03088793f677dce356f3ccc2edb1b314ad191ab702a5de3faf49304f7e104918",
        strip_prefix = "socket2-0.3.12",
        build_file = Label("//wasm_bindgen/raze/remote:socket2-0.3.12.BUILD"),
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
        name = "rules_rust_wasm_bindgen__syn__1_0_40",
        url = "https://crates.io/api/v1/crates/syn/1.0.40/download",
        type = "tar.gz",
        sha256 = "963f7d3cc59b59b9325165add223142bbf1df27655d07789f109896d353d8350",
        strip_prefix = "syn-1.0.40",
        build_file = Label("//wasm_bindgen/raze/remote:syn-1.0.40.BUILD"),
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
        name = "rules_rust_wasm_bindgen__wait_timeout__0_2_0",
        url = "https://crates.io/api/v1/crates/wait-timeout/0.2.0/download",
        type = "tar.gz",
        sha256 = "9f200f5b12eb75f8c1ed65abd4b2db8a6e1b138a20de009dacee265a2498f3f6",
        strip_prefix = "wait-timeout-0.2.0",
        build_file = Label("//wasm_bindgen/raze/remote:wait-timeout-0.2.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__walrus__0_18_0",
        url = "https://crates.io/api/v1/crates/walrus/0.18.0/download",
        type = "tar.gz",
        sha256 = "4d470d0583e65f4cab21a1ff3c1ba3dd23ae49e68f516f0afceaeb001b32af39",
        strip_prefix = "walrus-0.18.0",
        build_file = Label("//wasm_bindgen/raze/remote:walrus-0.18.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__walrus_macro__0_18_0",
        url = "https://crates.io/api/v1/crates/walrus-macro/0.18.0/download",
        type = "tar.gz",
        sha256 = "d7c2bb690b44cb1b0fdcc54d4998d21f8bdaf706b93775425e440b174f39ad16",
        strip_prefix = "walrus-macro-0.18.0",
        build_file = Label("//wasm_bindgen/raze/remote:walrus-macro-0.18.0.BUILD"),
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
        name = "rules_rust_wasm_bindgen__wasm_bindgen_cli__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-cli/0.2.68/download",
        type = "tar.gz",
        sha256 = "66892269704d2d149629b12b35200245953a63952db56b651117b3f42a6e8db9",
        strip_prefix = "wasm-bindgen-cli-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-cli-0.2.68.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_cli_support__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-cli-support/0.2.68/download",
        type = "tar.gz",
        sha256 = "0d7ab7ca2bed1686149512473ad17ef25038dbc2d4cd9060a5b9d0430eda57bd",
        strip_prefix = "wasm-bindgen-cli-support-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-cli-support-0.2.68.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_externref_xform__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-externref-xform/0.2.68/download",
        type = "tar.gz",
        sha256 = "fbda27740b611a84e5e60307d1e4bbe303131ee7dfa06b067c51a9be57694f9a",
        strip_prefix = "wasm-bindgen-externref-xform-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-externref-xform-0.2.68.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_multi_value_xform__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-multi-value-xform/0.2.68/download",
        type = "tar.gz",
        sha256 = "75f1045a9ca195e5f5a20b838b9361c26e9a26df1817d69491bd36f5a33c506a",
        strip_prefix = "wasm-bindgen-multi-value-xform-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-multi-value-xform-0.2.68.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_shared__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-shared/0.2.68/download",
        type = "tar.gz",
        sha256 = "1d649a3145108d7d3fbcde896a468d1bd636791823c9921135218ad89be08307",
        strip_prefix = "wasm-bindgen-shared-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-shared-0.2.68.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_threads_xform__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-threads-xform/0.2.68/download",
        type = "tar.gz",
        sha256 = "0a5558ca1936b27999d37ddcfa8c8ac0d1f2d324604a999024a1ea6b5f242533",
        strip_prefix = "wasm-bindgen-threads-xform-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-threads-xform-0.2.68.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_wasm_conventions__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-wasm-conventions/0.2.68/download",
        type = "tar.gz",
        sha256 = "a14ec444689948d32ebfa9252651482feee34cb8b371b6f8da15775f07a94289",
        strip_prefix = "wasm-bindgen-wasm-conventions-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-wasm-conventions-0.2.68.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_wasm_interpreter__0_2_68",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-wasm-interpreter/0.2.68/download",
        type = "tar.gz",
        sha256 = "e47e8238a2b05dbaf164a628bbaa43aac4c5a965247a991f7f3248824c784b1b",
        strip_prefix = "wasm-bindgen-wasm-interpreter-0.2.68",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-wasm-interpreter-0.2.68.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasmparser__0_59_0",
        url = "https://crates.io/api/v1/crates/wasmparser/0.59.0/download",
        type = "tar.gz",
        sha256 = "a950e6a618f62147fd514ff445b2a0b53120d382751960797f85f058c7eda9b9",
        strip_prefix = "wasmparser-0.59.0",
        build_file = Label("//wasm_bindgen/raze/remote:wasmparser-0.59.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasmparser__0_62_0",
        url = "https://crates.io/api/v1/crates/wasmparser/0.62.0/download",
        type = "tar.gz",
        sha256 = "e36b5b8441a5d83ea606c9eb904a3ee3889ebfeda1df1a5c48b84725239d93ce",
        strip_prefix = "wasmparser-0.62.0",
        build_file = Label("//wasm_bindgen/raze/remote:wasmparser-0.62.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasmprinter__0_2_9",
        url = "https://crates.io/api/v1/crates/wasmprinter/0.2.9/download",
        type = "tar.gz",
        sha256 = "adc9e10f7145e1c15f16c809d6c0937ab51a79478f53458fb78ded3491819a94",
        strip_prefix = "wasmprinter-0.2.9",
        build_file = Label("//wasm_bindgen/raze/remote:wasmprinter-0.2.9.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wast__21_0_0",
        url = "https://crates.io/api/v1/crates/wast/21.0.0/download",
        type = "tar.gz",
        sha256 = "0b1844f66a2bc8526d71690104c0e78a8e59ffa1597b7245769d174ebb91deb5",
        strip_prefix = "wast-21.0.0",
        build_file = Label("//wasm_bindgen/raze/remote:wast-21.0.0.BUILD"),
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

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wit_parser__0_2_0",
        url = "https://crates.io/api/v1/crates/wit-parser/0.2.0/download",
        type = "tar.gz",
        sha256 = "3f5fd97866f4b9c8e1ed57bcf9446f3d0d8ba37e2dd01c3c612c046c053b06f7",
        strip_prefix = "wit-parser-0.2.0",
        build_file = Label("//wasm_bindgen/raze/remote:wit-parser-0.2.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wit_printer__0_2_0",
        url = "https://crates.io/api/v1/crates/wit-printer/0.2.0/download",
        type = "tar.gz",
        sha256 = "93f19ca44555a3c14d69acee6447a6e4f52771b0c6e5d8db3e42db3b90f6fce9",
        strip_prefix = "wit-printer-0.2.0",
        build_file = Label("//wasm_bindgen/raze/remote:wit-printer-0.2.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wit_schema_version__0_1_0",
        url = "https://crates.io/api/v1/crates/wit-schema-version/0.1.0/download",
        type = "tar.gz",
        sha256 = "bfee4a6a4716eefa0682e7a3b836152e894a3e4f34a9d6c2c3e1c94429bfe36a",
        strip_prefix = "wit-schema-version-0.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:wit-schema-version-0.1.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wit_text__0_8_0",
        url = "https://crates.io/api/v1/crates/wit-text/0.8.0/download",
        type = "tar.gz",
        sha256 = "33358e95c77d660f1c7c07f4a93c2bd89768965e844e3c50730bb4b42658df5f",
        strip_prefix = "wit-text-0.8.0",
        build_file = Label("//wasm_bindgen/raze/remote:wit-text-0.8.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wit_validator__0_2_1",
        url = "https://crates.io/api/v1/crates/wit-validator/0.2.1/download",
        type = "tar.gz",
        sha256 = "3c11d93d925420e7872b226c4161849c32be38385ccab026b88df99d8ddc6ba6",
        strip_prefix = "wit-validator-0.2.1",
        build_file = Label("//wasm_bindgen/raze/remote:wit-validator-0.2.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wit_walrus__0_5_0",
        url = "https://crates.io/api/v1/crates/wit-walrus/0.5.0/download",
        type = "tar.gz",
        sha256 = "b532d7bc47d02a08463adc934301efbf67e7b1e1284f8a68edc85d1ca84fa125",
        strip_prefix = "wit-walrus-0.5.0",
        build_file = Label("//wasm_bindgen/raze/remote:wit-walrus-0.5.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wit_writer__0_2_0",
        url = "https://crates.io/api/v1/crates/wit-writer/0.2.0/download",
        type = "tar.gz",
        sha256 = "c2ad01ba5e9cbcff799a0689e56a153776ea694cec777f605938cb9880d41a09",
        strip_prefix = "wit-writer-0.2.0",
        build_file = Label("//wasm_bindgen/raze/remote:wit-writer-0.2.0.BUILD"),
    )
