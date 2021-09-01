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
        name = "rules_rust_wasm_bindgen__aho_corasick__0_7_18",
        url = "https://crates.io/api/v1/crates/aho-corasick/0.7.18/download",
        type = "tar.gz",
        sha256 = "1e37cfd5e7657ada45f742d6e99ca5788580b5c529dc78faf11ece6dc702656f",
        strip_prefix = "aho-corasick-0.7.18",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.aho-corasick-0.7.18.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__anyhow__1_0_43",
        url = "https://crates.io/api/v1/crates/anyhow/1.0.43/download",
        type = "tar.gz",
        sha256 = "28ae2b3dec75a406790005a200b1bd89785afc02517a00ca99ecfe093ee9e6cf",
        strip_prefix = "anyhow-1.0.43",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.anyhow-1.0.43.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__ascii__1_0_0",
        url = "https://crates.io/api/v1/crates/ascii/1.0.0/download",
        type = "tar.gz",
        sha256 = "bbf56136a5198c7b01a49e3afcbef6cf84597273d298f54432926024107b0109",
        strip_prefix = "ascii-1.0.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.ascii-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__assert_cmd__1_0_8",
        url = "https://crates.io/api/v1/crates/assert_cmd/1.0.8/download",
        type = "tar.gz",
        sha256 = "c98233c6673d8601ab23e77eb38f999c51100d46c5703b17288c57fddf3a1ffe",
        strip_prefix = "assert_cmd-1.0.8",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.assert_cmd-1.0.8.bazel"),
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
        name = "rules_rust_wasm_bindgen__autocfg__1_0_1",
        url = "https://crates.io/api/v1/crates/autocfg/1.0.1/download",
        type = "tar.gz",
        sha256 = "cdb031dd78e28731d87d56cc8ffef4a8f36ca26c38fe2de700543e627f8a464a",
        strip_prefix = "autocfg-1.0.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.autocfg-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__base_x__0_2_8",
        url = "https://crates.io/api/v1/crates/base-x/0.2.8/download",
        type = "tar.gz",
        sha256 = "a4521f3e3d031370679b3b140beb36dfe4801b09ac77e30c61941f97df3ef28b",
        strip_prefix = "base-x-0.2.8",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.base-x-0.2.8.bazel"),
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
        name = "rules_rust_wasm_bindgen__bitflags__1_3_2",
        url = "https://crates.io/api/v1/crates/bitflags/1.3.2/download",
        type = "tar.gz",
        sha256 = "bef38d45163c2f1dde094a7dfd33ccf595c92905c8f8f4fdc18d06fb1037718a",
        strip_prefix = "bitflags-1.3.2",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.bitflags-1.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__bstr__0_2_16",
        url = "https://crates.io/api/v1/crates/bstr/0.2.16/download",
        type = "tar.gz",
        sha256 = "90682c8d613ad3373e66de8c6411e0ae2ab2571e879d2efbf73558cc66f21279",
        strip_prefix = "bstr-0.2.16",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.bstr-0.2.16.bazel"),
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
        name = "rules_rust_wasm_bindgen__bumpalo__3_7_0",
        url = "https://crates.io/api/v1/crates/bumpalo/3.7.0/download",
        type = "tar.gz",
        sha256 = "9c59e7af012c713f529e7a3ee57ce9b31ddd858d4b512923602f74608b009631",
        strip_prefix = "bumpalo-3.7.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.bumpalo-3.7.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__byteorder__1_4_3",
        url = "https://crates.io/api/v1/crates/byteorder/1.4.3/download",
        type = "tar.gz",
        sha256 = "14c189c53d098945499cdfa7ecc63567cf3886b3332b312a5b4585d8d3a6a610",
        strip_prefix = "byteorder-1.4.3",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.byteorder-1.4.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__cc__1_0_69",
        url = "https://crates.io/api/v1/crates/cc/1.0.69/download",
        type = "tar.gz",
        sha256 = "e70cc2f62c6ce1868963827bd677764c62d07c3d9a3e1fb1177ee1a9ab199eb2",
        strip_prefix = "cc-1.0.69",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.cc-1.0.69.bazel"),
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
        name = "rules_rust_wasm_bindgen__chunked_transfer__1_4_0",
        url = "https://crates.io/api/v1/crates/chunked_transfer/1.4.0/download",
        type = "tar.gz",
        sha256 = "fff857943da45f546682664a79488be82e69e43c1a7a2307679ab9afb3a66d2e",
        strip_prefix = "chunked_transfer-1.4.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.chunked_transfer-1.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__const_fn__0_4_8",
        url = "https://crates.io/api/v1/crates/const_fn/0.4.8/download",
        type = "tar.gz",
        sha256 = "f92cfa0fd5690b3cf8c1ef2cabbd9b7ef22fa53cf5e1f92b05103f6d5d1cf6e7",
        strip_prefix = "const_fn-0.4.8",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.const_fn-0.4.8.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__crossbeam_channel__0_5_1",
        url = "https://crates.io/api/v1/crates/crossbeam-channel/0.5.1/download",
        type = "tar.gz",
        sha256 = "06ed27e177f16d65f0f0c22a213e17c696ace5dd64b14258b52f9417ccb52db4",
        strip_prefix = "crossbeam-channel-0.5.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.crossbeam-channel-0.5.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__crossbeam_deque__0_8_1",
        url = "https://crates.io/api/v1/crates/crossbeam-deque/0.8.1/download",
        type = "tar.gz",
        sha256 = "6455c0ca19f0d2fbf751b908d5c55c1f5cbc65e03c4225427254b46890bdde1e",
        strip_prefix = "crossbeam-deque-0.8.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.crossbeam-deque-0.8.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__crossbeam_epoch__0_9_5",
        url = "https://crates.io/api/v1/crates/crossbeam-epoch/0.9.5/download",
        type = "tar.gz",
        sha256 = "4ec02e091aa634e2c3ada4a392989e7c3116673ef0ac5b72232439094d73b7fd",
        strip_prefix = "crossbeam-epoch-0.9.5",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.crossbeam-epoch-0.9.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__crossbeam_utils__0_8_5",
        url = "https://crates.io/api/v1/crates/crossbeam-utils/0.8.5/download",
        type = "tar.gz",
        sha256 = "d82cfc11ce7f2c3faef78d8a684447b40d503d9681acebed6cb728d45940c4db",
        strip_prefix = "crossbeam-utils-0.8.5",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.crossbeam-utils-0.8.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__curl__0_4_38",
        url = "https://crates.io/api/v1/crates/curl/0.4.38/download",
        type = "tar.gz",
        sha256 = "003cb79c1c6d1c93344c7e1201bb51c2148f24ec2bd9c253709d6b2efb796515",
        strip_prefix = "curl-0.4.38",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.curl-0.4.38.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__curl_sys__0_4_45_curl_7_78_0",
        url = "https://crates.io/api/v1/crates/curl-sys/0.4.45+curl-7.78.0/download",
        type = "tar.gz",
        sha256 = "de9e5a72b1c744eb5dd20b2be4d7eb84625070bb5c4ab9b347b70464ab1e62eb",
        strip_prefix = "curl-sys-0.4.45+curl-7.78.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.curl-sys-0.4.45+curl-7.78.0.bazel"),
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
        name = "rules_rust_wasm_bindgen__difflib__0_4_0",
        url = "https://crates.io/api/v1/crates/difflib/0.4.0/download",
        type = "tar.gz",
        sha256 = "6184e33543162437515c2e2b48714794e37845ec9851711914eec9d308f6ebe8",
        strip_prefix = "difflib-0.4.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.difflib-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__discard__1_0_4",
        url = "https://crates.io/api/v1/crates/discard/1.0.4/download",
        type = "tar.gz",
        sha256 = "212d0f5754cb6769937f4501cc0e67f4f4483c8d2c3e1e922ee9edbe4ab4c7c0",
        strip_prefix = "discard-1.0.4",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.discard-1.0.4.bazel"),
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
        name = "rules_rust_wasm_bindgen__docopt__1_1_1",
        url = "https://crates.io/api/v1/crates/docopt/1.1.1/download",
        type = "tar.gz",
        sha256 = "7f3f119846c823f9eafcf953a8f6ffb6ed69bf6240883261a7f13b634579a51f",
        strip_prefix = "docopt-1.1.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.docopt-1.1.1.bazel"),
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
        name = "rules_rust_wasm_bindgen__env_logger__0_8_4",
        url = "https://crates.io/api/v1/crates/env_logger/0.8.4/download",
        type = "tar.gz",
        sha256 = "a19187fea3ac7e84da7dacf48de0c45d63c6a76f9490dae389aead16c243fce3",
        strip_prefix = "env_logger-0.8.4",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.env_logger-0.8.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__filetime__0_2_15",
        url = "https://crates.io/api/v1/crates/filetime/0.2.15/download",
        type = "tar.gz",
        sha256 = "975ccf83d8d9d0d84682850a38c8169027be83368805971cc4f238c2b245bc98",
        strip_prefix = "filetime-0.2.15",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.filetime-0.2.15.bazel"),
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
        name = "rules_rust_wasm_bindgen__form_urlencoded__1_0_1",
        url = "https://crates.io/api/v1/crates/form_urlencoded/1.0.1/download",
        type = "tar.gz",
        sha256 = "5fc25a87fa4fd2094bffb06925852034d90a17f0d1e05197d4956d3555752191",
        strip_prefix = "form_urlencoded-1.0.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.form_urlencoded-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__getrandom__0_2_3",
        url = "https://crates.io/api/v1/crates/getrandom/0.2.3/download",
        type = "tar.gz",
        sha256 = "7fcd999463524c52659517fe2cea98493cfe485d10565e7b0fb07dbba7ad2753",
        strip_prefix = "getrandom-0.2.3",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.getrandom-0.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__heck__0_3_3",
        url = "https://crates.io/api/v1/crates/heck/0.3.3/download",
        type = "tar.gz",
        sha256 = "6d621efb26863f0e9924c6ac577e8275e5e6b77455db64ffa6c65c904e9e132c",
        strip_prefix = "heck-0.3.3",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.heck-0.3.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__hermit_abi__0_1_19",
        url = "https://crates.io/api/v1/crates/hermit-abi/0.1.19/download",
        type = "tar.gz",
        sha256 = "62b467343b94ba476dcb2500d242dadbb39557df889310ac77c5d99100aaac33",
        strip_prefix = "hermit-abi-0.1.19",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.hermit-abi-0.1.19.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__httparse__1_5_0",
        url = "https://crates.io/api/v1/crates/httparse/1.5.0/download",
        type = "tar.gz",
        sha256 = "7ba8d84e9efea6aedae6fed9b6d9cfcaac6c53992b437d79a87a549d5537fea9",
        strip_prefix = "httparse-1.5.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.httparse-1.5.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__humantime__2_1_0",
        url = "https://crates.io/api/v1/crates/humantime/2.1.0/download",
        type = "tar.gz",
        sha256 = "9a3a5bfb195931eeb336b2a7b4d761daec841b97f947d34394601737a7bba5e4",
        strip_prefix = "humantime-2.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.humantime-2.1.0.bazel"),
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
        name = "rules_rust_wasm_bindgen__idna__0_2_3",
        url = "https://crates.io/api/v1/crates/idna/0.2.3/download",
        type = "tar.gz",
        sha256 = "418a0a6fab821475f634efe3ccc45c013f742efe03d853e8d3355d5cb850ecf8",
        strip_prefix = "idna-0.2.3",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.idna-0.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__itertools__0_10_1",
        url = "https://crates.io/api/v1/crates/itertools/0.10.1/download",
        type = "tar.gz",
        sha256 = "69ddb889f9d0d08a67338271fa9b62996bc788c7796a5c18cf057420aaed5eaf",
        strip_prefix = "itertools-0.10.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.itertools-0.10.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__itoa__0_4_7",
        url = "https://crates.io/api/v1/crates/itoa/0.4.7/download",
        type = "tar.gz",
        sha256 = "dd25036021b0de88a0aff6b850051563c6516d0bf53f8638938edbb9de732736",
        strip_prefix = "itoa-0.4.7",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.itoa-0.4.7.bazel"),
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
        name = "rules_rust_wasm_bindgen__libc__0_2_99",
        url = "https://crates.io/api/v1/crates/libc/0.2.99/download",
        type = "tar.gz",
        sha256 = "a7f823d141fe0a24df1e23b4af4e3c7ba9e5966ec514ea068c93024aa7deb765",
        strip_prefix = "libc-0.2.99",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.libc-0.2.99.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__libz_sys__1_1_3",
        url = "https://crates.io/api/v1/crates/libz-sys/1.1.3/download",
        type = "tar.gz",
        sha256 = "de5435b8549c16d423ed0c03dbaafe57cf6c3344744f1242520d59c9d8ecec66",
        strip_prefix = "libz-sys-1.1.3",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.libz-sys-1.1.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__log__0_4_14",
        url = "https://crates.io/api/v1/crates/log/0.4.14/download",
        type = "tar.gz",
        sha256 = "51b9bbe6c47d51fc3e1a9b945965946b4c44142ab8792c50835a980d362c2710",
        strip_prefix = "log-0.4.14",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.log-0.4.14.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__matches__0_1_9",
        url = "https://crates.io/api/v1/crates/matches/0.1.9/download",
        type = "tar.gz",
        sha256 = "a3e378b66a060d48947b590737b30a1be76706c8dd7b8ba0f2fe3989c68a853f",
        strip_prefix = "matches-0.1.9",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.matches-0.1.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__memchr__2_4_1",
        url = "https://crates.io/api/v1/crates/memchr/2.4.1/download",
        type = "tar.gz",
        sha256 = "308cc39be01b73d0d18f82a0e7b2a3df85245f84af96fdddc5d202d27e47b86a",
        strip_prefix = "memchr-2.4.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.memchr-2.4.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__memoffset__0_6_4",
        url = "https://crates.io/api/v1/crates/memoffset/0.6.4/download",
        type = "tar.gz",
        sha256 = "59accc507f1338036a0477ef61afdae33cde60840f4dfe481319ce3ad116ddf9",
        strip_prefix = "memoffset-0.6.4",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.memoffset-0.6.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__mime__0_3_16",
        url = "https://crates.io/api/v1/crates/mime/0.3.16/download",
        type = "tar.gz",
        sha256 = "2a60c7ce501c71e03a9c9c0d35b861413ae925bd979cc7a4e30d060069aaac8d",
        strip_prefix = "mime-0.3.16",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.mime-0.3.16.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__mime_guess__2_0_3",
        url = "https://crates.io/api/v1/crates/mime_guess/2.0.3/download",
        type = "tar.gz",
        sha256 = "2684d4c2e97d99848d30b324b00c8fcc7e5c897b7cbb5819b09e7c90e8baf212",
        strip_prefix = "mime_guess-2.0.3",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.mime_guess-2.0.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__multipart__0_18_0",
        url = "https://crates.io/api/v1/crates/multipart/0.18.0/download",
        type = "tar.gz",
        sha256 = "00dec633863867f29cb39df64a397cdf4a6354708ddd7759f70c7fb51c5f9182",
        strip_prefix = "multipart-0.18.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.multipart-0.18.0.bazel"),
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
        name = "rules_rust_wasm_bindgen__openssl_probe__0_1_4",
        url = "https://crates.io/api/v1/crates/openssl-probe/0.1.4/download",
        type = "tar.gz",
        sha256 = "28988d872ab76095a6e6ac88d99b54fd267702734fd7ffe610ca27f533ddb95a",
        strip_prefix = "openssl-probe-0.1.4",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.openssl-probe-0.1.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__openssl_sys__0_9_66",
        url = "https://crates.io/api/v1/crates/openssl-sys/0.9.66/download",
        type = "tar.gz",
        sha256 = "1996d2d305e561b70d1ee0c53f1542833f4e1ac6ce9a6708b6ff2738ca67dc82",
        strip_prefix = "openssl-sys-0.9.66",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.openssl-sys-0.9.66.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__percent_encoding__2_1_0",
        url = "https://crates.io/api/v1/crates/percent-encoding/2.1.0/download",
        type = "tar.gz",
        sha256 = "d4fd5641d01c8f18a23da7b6fe29298ff4b55afcccdf78973b24cf3175fee32e",
        strip_prefix = "percent-encoding-2.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.percent-encoding-2.1.0.bazel"),
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
        name = "rules_rust_wasm_bindgen__predicates__1_0_8",
        url = "https://crates.io/api/v1/crates/predicates/1.0.8/download",
        type = "tar.gz",
        sha256 = "f49cfaf7fdaa3bfacc6fa3e7054e65148878354a5cfddcf661df4c851f8021df",
        strip_prefix = "predicates-1.0.8",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.predicates-1.0.8.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__predicates__2_0_2",
        url = "https://crates.io/api/v1/crates/predicates/2.0.2/download",
        type = "tar.gz",
        sha256 = "c143348f141cc87aab5b950021bac6145d0e5ae754b0591de23244cee42c9308",
        strip_prefix = "predicates-2.0.2",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.predicates-2.0.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__predicates_core__1_0_2",
        url = "https://crates.io/api/v1/crates/predicates-core/1.0.2/download",
        type = "tar.gz",
        sha256 = "57e35a3326b75e49aa85f5dc6ec15b41108cf5aee58eabb1f274dd18b73c2451",
        strip_prefix = "predicates-core-1.0.2",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.predicates-core-1.0.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__predicates_tree__1_0_3",
        url = "https://crates.io/api/v1/crates/predicates-tree/1.0.3/download",
        type = "tar.gz",
        sha256 = "d7dd0fd014130206c9352efbdc92be592751b2b9274dff685348341082c6ea3d",
        strip_prefix = "predicates-tree-1.0.3",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.predicates-tree-1.0.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__proc_macro_hack__0_5_19",
        url = "https://crates.io/api/v1/crates/proc-macro-hack/0.5.19/download",
        type = "tar.gz",
        sha256 = "dbf0c48bc1d91375ae5c3cd81e3722dff1abcf81a30960240640d223f59fe0e5",
        strip_prefix = "proc-macro-hack-0.5.19",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.proc-macro-hack-0.5.19.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__proc_macro2__1_0_28",
        url = "https://crates.io/api/v1/crates/proc-macro2/1.0.28/download",
        type = "tar.gz",
        sha256 = "5c7ed8b8c7b886ea3ed7dde405212185f423ab44682667c8c6dd14aa1d9f6612",
        strip_prefix = "proc-macro2-1.0.28",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.proc-macro2-1.0.28.bazel"),
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
        name = "rules_rust_wasm_bindgen__quote__1_0_9",
        url = "https://crates.io/api/v1/crates/quote/1.0.9/download",
        type = "tar.gz",
        sha256 = "c3d0b9745dc2debf507c8422de05d7226cc1f0644216dfdfead988f9b1ab32a7",
        strip_prefix = "quote-1.0.9",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.quote-1.0.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand__0_8_4",
        url = "https://crates.io/api/v1/crates/rand/0.8.4/download",
        type = "tar.gz",
        sha256 = "2e7573632e6454cf6b99d7aac4ccca54be06da05aca2ef7423d22d27d4d4bcd8",
        strip_prefix = "rand-0.8.4",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rand-0.8.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_chacha__0_3_1",
        url = "https://crates.io/api/v1/crates/rand_chacha/0.3.1/download",
        type = "tar.gz",
        sha256 = "e6c10a63a0fa32252be49d21e7709d4d4baf8d231c2dbce1eaa8141b9b127d88",
        strip_prefix = "rand_chacha-0.3.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rand_chacha-0.3.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_core__0_6_3",
        url = "https://crates.io/api/v1/crates/rand_core/0.6.3/download",
        type = "tar.gz",
        sha256 = "d34f1408f55294453790c48b2f1ebbb1c5b4b7563eb1f418bcfcfdbb06ebb4e7",
        strip_prefix = "rand_core-0.6.3",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rand_core-0.6.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rand_hc__0_3_1",
        url = "https://crates.io/api/v1/crates/rand_hc/0.3.1/download",
        type = "tar.gz",
        sha256 = "d51e9f596de227fda2ea6c84607f5558e196eeaf43c986b724ba4fb8fdf497e7",
        strip_prefix = "rand_hc-0.3.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rand_hc-0.3.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rayon__1_5_1",
        url = "https://crates.io/api/v1/crates/rayon/1.5.1/download",
        type = "tar.gz",
        sha256 = "c06aca804d41dbc8ba42dfd964f0d01334eceb64314b9ecf7c5fad5188a06d90",
        strip_prefix = "rayon-1.5.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rayon-1.5.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rayon_core__1_9_1",
        url = "https://crates.io/api/v1/crates/rayon-core/1.9.1/download",
        type = "tar.gz",
        sha256 = "d78120e2c850279833f1dd3582f730c4ab53ed95aeaaaa862a2a5c71b1656d8e",
        strip_prefix = "rayon-core-1.9.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rayon-core-1.9.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__redox_syscall__0_2_10",
        url = "https://crates.io/api/v1/crates/redox_syscall/0.2.10/download",
        type = "tar.gz",
        sha256 = "8383f39639269cde97d255a32bdb68c047337295414940c68bdd30c2e13203ff",
        strip_prefix = "redox_syscall-0.2.10",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.redox_syscall-0.2.10.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__regex__1_5_4",
        url = "https://crates.io/api/v1/crates/regex/1.5.4/download",
        type = "tar.gz",
        sha256 = "d07a8629359eb56f1e2fb1652bb04212c072a87ba68546a04065d525673ac461",
        strip_prefix = "regex-1.5.4",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.regex-1.5.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__regex_automata__0_1_10",
        url = "https://crates.io/api/v1/crates/regex-automata/0.1.10/download",
        type = "tar.gz",
        sha256 = "6c230d73fb8d8c1b9c0b3135c5142a8acee3a0558fb8db5cf1cb65f8d7862132",
        strip_prefix = "regex-automata-0.1.10",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.regex-automata-0.1.10.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__regex_syntax__0_6_25",
        url = "https://crates.io/api/v1/crates/regex-syntax/0.6.25/download",
        type = "tar.gz",
        sha256 = "f497285884f3fcff424ffc933e56d7cbca511def0c9831a7f9b5f6153e3cc89b",
        strip_prefix = "regex-syntax-0.6.25",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.regex-syntax-0.6.25.bazel"),
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
        name = "rules_rust_wasm_bindgen__rouille__3_2_1",
        url = "https://crates.io/api/v1/crates/rouille/3.2.1/download",
        type = "tar.gz",
        sha256 = "8263ea8c0988dbdd89e679d408eaa5505bb886677e997562646c2e2ba4d2e6db",
        strip_prefix = "rouille-3.2.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rouille-3.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rustc_demangle__0_1_20",
        url = "https://crates.io/api/v1/crates/rustc-demangle/0.1.20/download",
        type = "tar.gz",
        sha256 = "dead70b0b5e03e9c814bcb6b01e03e68f7c57a80aa48c72ec92152ab3e818d49",
        strip_prefix = "rustc-demangle-0.1.20",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rustc-demangle-0.1.20.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__rustc_version__0_2_3",
        url = "https://crates.io/api/v1/crates/rustc_version/0.2.3/download",
        type = "tar.gz",
        sha256 = "138e3e0acb6c9fb258b19b67cb8abd63c00679d2851805ea151465464fe9030a",
        strip_prefix = "rustc_version-0.2.3",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.rustc_version-0.2.3.bazel"),
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
        name = "rules_rust_wasm_bindgen__semver__0_9_0",
        url = "https://crates.io/api/v1/crates/semver/0.9.0/download",
        type = "tar.gz",
        sha256 = "1d7eb9ef2c18661902cc47e535f9bc51b78acd254da71d375c2f6720d9a40403",
        strip_prefix = "semver-0.9.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.semver-0.9.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__semver_parser__0_7_0",
        url = "https://crates.io/api/v1/crates/semver-parser/0.7.0/download",
        type = "tar.gz",
        sha256 = "388a1df253eca08550bef6c72392cfe7c30914bf41df5269b68cbd6ff8f570a3",
        strip_prefix = "semver-parser-0.7.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.semver-parser-0.7.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__serde__1_0_127",
        url = "https://crates.io/api/v1/crates/serde/1.0.127/download",
        type = "tar.gz",
        sha256 = "f03b9878abf6d14e6779d3f24f07b2cfa90352cfec4acc5aab8f1ac7f146fae8",
        strip_prefix = "serde-1.0.127",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.serde-1.0.127.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__serde_derive__1_0_127",
        url = "https://crates.io/api/v1/crates/serde_derive/1.0.127/download",
        type = "tar.gz",
        sha256 = "a024926d3432516606328597e0f224a51355a493b49fdd67e9209187cbe55ecc",
        strip_prefix = "serde_derive-1.0.127",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.serde_derive-1.0.127.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__serde_json__1_0_66",
        url = "https://crates.io/api/v1/crates/serde_json/1.0.66/download",
        type = "tar.gz",
        sha256 = "336b10da19a12ad094b59d870ebde26a45402e5b470add4b5fd03c5048a32127",
        strip_prefix = "serde_json-1.0.66",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.serde_json-1.0.66.bazel"),
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
        name = "rules_rust_wasm_bindgen__socket2__0_4_1",
        url = "https://crates.io/api/v1/crates/socket2/0.4.1/download",
        type = "tar.gz",
        sha256 = "765f090f0e423d2b55843402a07915add955e7d60657db13707a159727326cad",
        strip_prefix = "socket2-0.4.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.socket2-0.4.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__standback__0_2_17",
        url = "https://crates.io/api/v1/crates/standback/0.2.17/download",
        type = "tar.gz",
        sha256 = "e113fb6f3de07a243d434a56ec6f186dfd51cb08448239fe7bcae73f87ff28ff",
        strip_prefix = "standback-0.2.17",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.standback-0.2.17.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__stdweb__0_4_20",
        url = "https://crates.io/api/v1/crates/stdweb/0.4.20/download",
        type = "tar.gz",
        sha256 = "d022496b16281348b52d0e30ae99e01a73d737b2f45d38fed4edf79f9325a1d5",
        strip_prefix = "stdweb-0.4.20",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.stdweb-0.4.20.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__stdweb_derive__0_5_3",
        url = "https://crates.io/api/v1/crates/stdweb-derive/0.5.3/download",
        type = "tar.gz",
        sha256 = "c87a60a40fccc84bef0652345bbbbbe20a605bf5d0ce81719fc476f5c03b50ef",
        strip_prefix = "stdweb-derive-0.5.3",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.stdweb-derive-0.5.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__stdweb_internal_macros__0_2_9",
        url = "https://crates.io/api/v1/crates/stdweb-internal-macros/0.2.9/download",
        type = "tar.gz",
        sha256 = "58fa5ff6ad0d98d1ffa8cb115892b6e69d67799f6763e162a1c9db421dc22e11",
        strip_prefix = "stdweb-internal-macros-0.2.9",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.stdweb-internal-macros-0.2.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__stdweb_internal_runtime__0_1_5",
        url = "https://crates.io/api/v1/crates/stdweb-internal-runtime/0.1.5/download",
        type = "tar.gz",
        sha256 = "213701ba3370744dcd1a12960caa4843b3d68b4d1c0a5d575e0d65b2ee9d16c0",
        strip_prefix = "stdweb-internal-runtime-0.1.5",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.stdweb-internal-runtime-0.1.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__strsim__0_10_0",
        url = "https://crates.io/api/v1/crates/strsim/0.10.0/download",
        type = "tar.gz",
        sha256 = "73473c0e59e6d5812c5dfe2a064a6444949f089e20eec9a2e5506596494e4623",
        strip_prefix = "strsim-0.10.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.strsim-0.10.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__syn__1_0_74",
        url = "https://crates.io/api/v1/crates/syn/1.0.74/download",
        type = "tar.gz",
        sha256 = "1873d832550d4588c3dbc20f01361ab00bfe741048f71e3fecf145a7cc18b29c",
        strip_prefix = "syn-1.0.74",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.syn-1.0.74.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__tempfile__3_2_0",
        url = "https://crates.io/api/v1/crates/tempfile/3.2.0/download",
        type = "tar.gz",
        sha256 = "dac1c663cfc93810f88aed9b8941d48cabf856a1b111c29a40439018d870eb22",
        strip_prefix = "tempfile-3.2.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.tempfile-3.2.0.bazel"),
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
        name = "rules_rust_wasm_bindgen__threadpool__1_8_1",
        url = "https://crates.io/api/v1/crates/threadpool/1.8.1/download",
        type = "tar.gz",
        sha256 = "d050e60b33d41c19108b32cea32164033a9013fe3b46cbd4457559bfbf77afaa",
        strip_prefix = "threadpool-1.8.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.threadpool-1.8.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__time__0_1_43",
        url = "https://crates.io/api/v1/crates/time/0.1.43/download",
        type = "tar.gz",
        sha256 = "ca8a50ef2360fbd1eeb0ecd46795a87a19024eb4b53c5dc916ca1fd95fe62438",
        strip_prefix = "time-0.1.43",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.time-0.1.43.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__time__0_2_27",
        url = "https://crates.io/api/v1/crates/time/0.2.27/download",
        type = "tar.gz",
        sha256 = "4752a97f8eebd6854ff91f1c1824cd6160626ac4bd44287f7f4ea2035a02a242",
        strip_prefix = "time-0.2.27",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.time-0.2.27.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__time_macros__0_1_1",
        url = "https://crates.io/api/v1/crates/time-macros/0.1.1/download",
        type = "tar.gz",
        sha256 = "957e9c6e26f12cb6d0dd7fc776bb67a706312e7299aed74c8dd5b17ebb27e2f1",
        strip_prefix = "time-macros-0.1.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.time-macros-0.1.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__time_macros_impl__0_1_2",
        url = "https://crates.io/api/v1/crates/time-macros-impl/0.1.2/download",
        type = "tar.gz",
        sha256 = "fd3c141a1b43194f3f56a1411225df8646c55781d5f26db825b3d98507eb482f",
        strip_prefix = "time-macros-impl-0.1.2",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.time-macros-impl-0.1.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__tiny_http__0_8_2",
        url = "https://crates.io/api/v1/crates/tiny_http/0.8.2/download",
        type = "tar.gz",
        sha256 = "9ce51b50006056f590c9b7c3808c3bd70f0d1101666629713866c227d6e58d39",
        strip_prefix = "tiny_http-0.8.2",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.tiny_http-0.8.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__tinyvec__1_3_1",
        url = "https://crates.io/api/v1/crates/tinyvec/1.3.1/download",
        type = "tar.gz",
        sha256 = "848a1e1181b9f6753b5e96a092749e29b11d19ede67dfbbd6c7dc7e0f49b5338",
        strip_prefix = "tinyvec-1.3.1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.tinyvec-1.3.1.bazel"),
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
        name = "rules_rust_wasm_bindgen__unicase__2_6_0",
        url = "https://crates.io/api/v1/crates/unicase/2.6.0/download",
        type = "tar.gz",
        sha256 = "50f37be617794602aabbeee0be4f259dc1778fabe05e2d67ee8f79326d5cb4f6",
        strip_prefix = "unicase-2.6.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.unicase-2.6.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__unicode_bidi__0_3_6",
        url = "https://crates.io/api/v1/crates/unicode-bidi/0.3.6/download",
        type = "tar.gz",
        sha256 = "246f4c42e67e7a4e3c6106ff716a5d067d4132a642840b242e357e468a2a0085",
        strip_prefix = "unicode-bidi-0.3.6",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.unicode-bidi-0.3.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__unicode_normalization__0_1_19",
        url = "https://crates.io/api/v1/crates/unicode-normalization/0.1.19/download",
        type = "tar.gz",
        sha256 = "d54590932941a9e9266f0832deed84ebe1bf2e4c9e4a3554d393d18f5e854bf9",
        strip_prefix = "unicode-normalization-0.1.19",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.unicode-normalization-0.1.19.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__unicode_segmentation__1_8_0",
        url = "https://crates.io/api/v1/crates/unicode-segmentation/1.8.0/download",
        type = "tar.gz",
        sha256 = "8895849a949e7845e06bd6dc1aa51731a103c42707010a5b591c0038fb73385b",
        strip_prefix = "unicode-segmentation-1.8.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.unicode-segmentation-1.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__unicode_xid__0_2_2",
        url = "https://crates.io/api/v1/crates/unicode-xid/0.2.2/download",
        type = "tar.gz",
        sha256 = "8ccb82d61f80a663efe1f787a51b16b5a51e3314d6ac365b08639f52387b33f3",
        strip_prefix = "unicode-xid-0.2.2",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.unicode-xid-0.2.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__url__2_2_2",
        url = "https://crates.io/api/v1/crates/url/2.2.2/download",
        type = "tar.gz",
        sha256 = "a507c383b2d33b5fc35d1861e77e6b383d158b2da5e14fe51b83dfedf6fd578c",
        strip_prefix = "url-2.2.2",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.url-2.2.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__vcpkg__0_2_15",
        url = "https://crates.io/api/v1/crates/vcpkg/0.2.15/download",
        type = "tar.gz",
        sha256 = "accd4ea62f7bb7a82fe23066fb0957d48ef677f6eeb8215f372f52e48bb32426",
        strip_prefix = "vcpkg-0.2.15",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.vcpkg-0.2.15.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__version_check__0_9_3",
        url = "https://crates.io/api/v1/crates/version_check/0.9.3/download",
        type = "tar.gz",
        sha256 = "5fecdca9a5291cc2b8dcf7dc02453fee791a280f3743cb0905f8822ae463b3fe",
        strip_prefix = "version_check-0.9.3",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.version_check-0.9.3.bazel"),
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
        name = "rules_rust_wasm_bindgen__walrus__0_19_0",
        url = "https://crates.io/api/v1/crates/walrus/0.19.0/download",
        type = "tar.gz",
        sha256 = "4eb08e48cde54c05f363d984bb54ce374f49e242def9468d2e1b6c2372d291f8",
        strip_prefix = "walrus-0.19.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.walrus-0.19.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__walrus_macro__0_19_0",
        url = "https://crates.io/api/v1/crates/walrus-macro/0.19.0/download",
        type = "tar.gz",
        sha256 = "0a6e5bd22c71e77d60140b0bd5be56155a37e5bd14e24f5f87298040d0cc40d7",
        strip_prefix = "walrus-macro-0.19.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.walrus-macro-0.19.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasi__0_10_2_wasi_snapshot_preview1",
        url = "https://crates.io/api/v1/crates/wasi/0.10.2+wasi-snapshot-preview1/download",
        type = "tar.gz",
        sha256 = "fd6fbd9a79829dd1ad0cc20627bf1ed606756a7f77edff7b66b7064f9cb327c6",
        strip_prefix = "wasi-0.10.2+wasi-snapshot-preview1",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasi-0.10.2+wasi-snapshot-preview1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen__0_2_76",
        url = "https://crates.io/api/v1/crates/wasm-bindgen/0.2.76/download",
        type = "tar.gz",
        sha256 = "8ce9b1b516211d33767048e5d47fa2a381ed8b76fc48d2ce4aa39877f9f183e0",
        strip_prefix = "wasm-bindgen-0.2.76",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-0.2.76.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_backend__0_2_76",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-backend/0.2.76/download",
        type = "tar.gz",
        sha256 = "cfe8dc78e2326ba5f845f4b5bf548401604fa20b1dd1d365fb73b6c1d6364041",
        strip_prefix = "wasm-bindgen-backend-0.2.76",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-backend-0.2.76.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_cli__0_2_76",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-cli/0.2.76/download",
        type = "tar.gz",
        sha256 = "b78a4bddef01a751a5dfec29e6bc095563542d7018751652b56180c00dd1f5a1",
        strip_prefix = "wasm-bindgen-cli-0.2.76",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-cli-0.2.76.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_cli_support__0_2_76",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-cli-support/0.2.76/download",
        type = "tar.gz",
        sha256 = "e026e3a870b662ad7588ad2f869bf06701bd9f8aa6d0775092f50b09db261371",
        strip_prefix = "wasm-bindgen-cli-support-0.2.76",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-cli-support-0.2.76.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_externref_xform__0_2_76",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-externref-xform/0.2.76/download",
        type = "tar.gz",
        sha256 = "7ba5d590398c22756ddcbc9f725b78763e89d13b0f1b9e106afd0adb4554369b",
        strip_prefix = "wasm-bindgen-externref-xform-0.2.76",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-externref-xform-0.2.76.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_macro__0_2_76",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-macro/0.2.76/download",
        type = "tar.gz",
        sha256 = "44468aa53335841d9d6b6c023eaab07c0cd4bddbcfdee3e2bb1e8d2cb8069fef",
        strip_prefix = "wasm-bindgen-macro-0.2.76",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-macro-0.2.76.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_macro_support__0_2_76",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-macro-support/0.2.76/download",
        type = "tar.gz",
        sha256 = "0195807922713af1e67dc66132c7328206ed9766af3858164fb583eedc25fbad",
        strip_prefix = "wasm-bindgen-macro-support-0.2.76",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-macro-support-0.2.76.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_multi_value_xform__0_2_76",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-multi-value-xform/0.2.76/download",
        type = "tar.gz",
        sha256 = "10c316ea6ac943715678c3acfb312c7d635ae7e3203f7976806f7aba551dcef4",
        strip_prefix = "wasm-bindgen-multi-value-xform-0.2.76",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-multi-value-xform-0.2.76.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_shared__0_2_76",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-shared/0.2.76/download",
        type = "tar.gz",
        sha256 = "acdb075a845574a1fa5f09fd77e43f7747599301ea3417a9fbffdeedfc1f4a29",
        strip_prefix = "wasm-bindgen-shared-0.2.76",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-shared-0.2.76.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_threads_xform__0_2_76",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-threads-xform/0.2.76/download",
        type = "tar.gz",
        sha256 = "1505026cf20c85cae00426062d317a50613c36855c47c831cc36a31ad950a53e",
        strip_prefix = "wasm-bindgen-threads-xform-0.2.76",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-threads-xform-0.2.76.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_wasm_conventions__0_2_76",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-wasm-conventions/0.2.76/download",
        type = "tar.gz",
        sha256 = "2eca949de4dbffa4cfe0353f98389bc095fe10bff3b4381d2a2a96f33f066933",
        strip_prefix = "wasm-bindgen-wasm-conventions-0.2.76",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-wasm-conventions-0.2.76.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasm_bindgen_wasm_interpreter__0_2_76",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-wasm-interpreter/0.2.76/download",
        type = "tar.gz",
        sha256 = "a65da9c930cf63b51b3448cd9ca614371dd0d8b4d3bd55620afef87c47ddad21",
        strip_prefix = "wasm-bindgen-wasm-interpreter-0.2.76",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasm-bindgen-wasm-interpreter-0.2.76.bazel"),
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
        name = "rules_rust_wasm_bindgen__wasmparser__0_77_0",
        url = "https://crates.io/api/v1/crates/wasmparser/0.77.0/download",
        type = "tar.gz",
        sha256 = "b35c86d22e720a07d954ebbed772d01180501afe7d03d464f413bb5f8914a8d6",
        strip_prefix = "wasmparser-0.77.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasmparser-0.77.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasmparser__0_80_0",
        url = "https://crates.io/api/v1/crates/wasmparser/0.80.0/download",
        type = "tar.gz",
        sha256 = "a5f71b80b8193e50910919e7d1bc956d2b4f42b1cb1fad84bacb59332c16f2cf",
        strip_prefix = "wasmparser-0.80.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasmparser-0.80.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen__wasmprinter__0_2_28",
        url = "https://crates.io/api/v1/crates/wasmprinter/0.2.28/download",
        type = "tar.gz",
        sha256 = "b48e4f2999b9930e9b037e328357d7d2367e0d8ea6e534be90aeff60976c0452",
        strip_prefix = "wasmprinter-0.2.28",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wasmprinter-0.2.28.bazel"),
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
        name = "rules_rust_wasm_bindgen__wit_walrus__0_6_0",
        url = "https://crates.io/api/v1/crates/wit-walrus/0.6.0/download",
        type = "tar.gz",
        sha256 = "ad559e3e4c6404b2a6a675d44129d62a3836e3b951b90112fa1c5feb852757cd",
        strip_prefix = "wit-walrus-0.6.0",
        build_file = Label("//wasm_bindgen/raze/remote:BUILD.wit-walrus-0.6.0.bazel"),
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
