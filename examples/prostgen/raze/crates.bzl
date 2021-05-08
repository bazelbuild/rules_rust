"""
@generated
cargo-raze generated Bazel file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

def rules_rust_examples_prostgen_fetch_remote_crates():
    """This function defines a collection of repos and should be called in a WORKSPACE file"""
    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__anyhow__1_0_38",
        url = "https://crates.io/api/v1/crates/anyhow/1.0.38/download",
        type = "tar.gz",
        sha256 = "afddf7f520a80dbf76e6f50a35bca42a2331ef227a28b3b6dc5c2e2338d114b1",
        strip_prefix = "anyhow-1.0.38",
        build_file = Label("//prostgen/raze/remote:BUILD.anyhow-1.0.38.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__async_stream__0_3_0",
        url = "https://crates.io/api/v1/crates/async-stream/0.3.0/download",
        type = "tar.gz",
        sha256 = "3670df70cbc01729f901f94c887814b3c68db038aad1329a418bae178bc5295c",
        strip_prefix = "async-stream-0.3.0",
        build_file = Label("//prostgen/raze/remote:BUILD.async-stream-0.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__async_stream_impl__0_3_0",
        url = "https://crates.io/api/v1/crates/async-stream-impl/0.3.0/download",
        type = "tar.gz",
        sha256 = "a3548b8efc9f8e8a5a0a2808c5bd8451a9031b9e5b879a79590304ae928b0a70",
        strip_prefix = "async-stream-impl-0.3.0",
        build_file = Label("//prostgen/raze/remote:BUILD.async-stream-impl-0.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__async_trait__0_1_42",
        url = "https://crates.io/api/v1/crates/async-trait/0.1.42/download",
        type = "tar.gz",
        sha256 = "8d3a45e77e34375a7923b1e8febb049bb011f064714a8e17a1a616fef01da13d",
        strip_prefix = "async-trait-0.1.42",
        build_file = Label("//prostgen/raze/remote:BUILD.async-trait-0.1.42.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__autocfg__1_0_1",
        url = "https://crates.io/api/v1/crates/autocfg/1.0.1/download",
        type = "tar.gz",
        sha256 = "cdb031dd78e28731d87d56cc8ffef4a8f36ca26c38fe2de700543e627f8a464a",
        strip_prefix = "autocfg-1.0.1",
        build_file = Label("//prostgen/raze/remote:BUILD.autocfg-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__base64__0_13_0",
        url = "https://crates.io/api/v1/crates/base64/0.13.0/download",
        type = "tar.gz",
        sha256 = "904dfeac50f3cdaba28fc6f57fdcddb75f49ed61346676a78c4ffe55877802fd",
        strip_prefix = "base64-0.13.0",
        build_file = Label("//prostgen/raze/remote:BUILD.base64-0.13.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__bitflags__1_2_1",
        url = "https://crates.io/api/v1/crates/bitflags/1.2.1/download",
        type = "tar.gz",
        strip_prefix = "bitflags-1.2.1",
        build_file = Label("//prostgen/raze/remote:BUILD.bitflags-1.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__bumpalo__3_6_1",
        url = "https://crates.io/api/v1/crates/bumpalo/3.6.1/download",
        type = "tar.gz",
        strip_prefix = "bumpalo-3.6.1",
        build_file = Label("//prostgen/raze/remote:BUILD.bumpalo-3.6.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__bytes__1_0_1",
        url = "https://crates.io/api/v1/crates/bytes/1.0.1/download",
        type = "tar.gz",
        sha256 = "b700ce4376041dcd0a327fd0097c41095743c4c8af8887265942faf1100bd040",
        strip_prefix = "bytes-1.0.1",
        build_file = Label("//prostgen/raze/remote:BUILD.bytes-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__cc__1_0_67",
        url = "https://crates.io/api/v1/crates/cc/1.0.67/download",
        type = "tar.gz",
        strip_prefix = "cc-1.0.67",
        build_file = Label("//prostgen/raze/remote:BUILD.cc-1.0.67.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__cfg_if__1_0_0",
        url = "https://crates.io/api/v1/crates/cfg-if/1.0.0/download",
        type = "tar.gz",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("//prostgen/raze/remote:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__core_foundation__0_9_1",
        url = "https://crates.io/api/v1/crates/core-foundation/0.9.1/download",
        type = "tar.gz",
        strip_prefix = "core-foundation-0.9.1",
        build_file = Label("//prostgen/raze/remote:BUILD.core-foundation-0.9.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__core_foundation_sys__0_8_2",
        url = "https://crates.io/api/v1/crates/core-foundation-sys/0.8.2/download",
        type = "tar.gz",
        strip_prefix = "core-foundation-sys-0.8.2",
        build_file = Label("//prostgen/raze/remote:BUILD.core-foundation-sys-0.8.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__either__1_6_1",
        url = "https://crates.io/api/v1/crates/either/1.6.1/download",
        type = "tar.gz",
        sha256 = "e78d4f1cc4ae33bbfc157ed5d5a5ef3bc29227303d595861deb238fcec4e9457",
        strip_prefix = "either-1.6.1",
        build_file = Label("//prostgen/raze/remote:BUILD.either-1.6.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__encoding_rs__0_8_28",
        url = "https://crates.io/api/v1/crates/encoding_rs/0.8.28/download",
        type = "tar.gz",
        strip_prefix = "encoding_rs-0.8.28",
        build_file = Label("//prostgen/raze/remote:BUILD.encoding_rs-0.8.28.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__fnv__1_0_7",
        url = "https://crates.io/api/v1/crates/fnv/1.0.7/download",
        type = "tar.gz",
        sha256 = "3f9eec918d3f24069decb9af1554cad7c880e2da24a9afd88aca000531ab82c1",
        strip_prefix = "fnv-1.0.7",
        build_file = Label("//prostgen/raze/remote:BUILD.fnv-1.0.7.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__foreign_types__0_3_2",
        url = "https://crates.io/api/v1/crates/foreign-types/0.3.2/download",
        type = "tar.gz",
        strip_prefix = "foreign-types-0.3.2",
        build_file = Label("//prostgen/raze/remote:BUILD.foreign-types-0.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__foreign_types_shared__0_1_1",
        url = "https://crates.io/api/v1/crates/foreign-types-shared/0.1.1/download",
        type = "tar.gz",
        strip_prefix = "foreign-types-shared-0.1.1",
        build_file = Label("//prostgen/raze/remote:BUILD.foreign-types-shared-0.1.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__form_urlencoded__1_0_1",
        url = "https://crates.io/api/v1/crates/form_urlencoded/1.0.1/download",
        type = "tar.gz",
        strip_prefix = "form_urlencoded-1.0.1",
        build_file = Label("//prostgen/raze/remote:BUILD.form_urlencoded-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__futures_channel__0_3_13",
        url = "https://crates.io/api/v1/crates/futures-channel/0.3.13/download",
        type = "tar.gz",
        sha256 = "8c2dd2df839b57db9ab69c2c9d8f3e8c81984781937fe2807dc6dcf3b2ad2939",
        strip_prefix = "futures-channel-0.3.13",
        build_file = Label("//prostgen/raze/remote:BUILD.futures-channel-0.3.13.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__futures_core__0_3_13",
        url = "https://crates.io/api/v1/crates/futures-core/0.3.13/download",
        type = "tar.gz",
        sha256 = "15496a72fabf0e62bdc3df11a59a3787429221dd0710ba8ef163d6f7a9112c94",
        strip_prefix = "futures-core-0.3.13",
        build_file = Label("//prostgen/raze/remote:BUILD.futures-core-0.3.13.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__futures_sink__0_3_13",
        url = "https://crates.io/api/v1/crates/futures-sink/0.3.13/download",
        type = "tar.gz",
        sha256 = "85754d98985841b7d4f5e8e6fbfa4a4ac847916893ec511a2917ccd8525b8bb3",
        strip_prefix = "futures-sink-0.3.13",
        build_file = Label("//prostgen/raze/remote:BUILD.futures-sink-0.3.13.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__futures_task__0_3_13",
        url = "https://crates.io/api/v1/crates/futures-task/0.3.13/download",
        type = "tar.gz",
        sha256 = "fa189ef211c15ee602667a6fcfe1c1fd9e07d42250d2156382820fba33c9df80",
        strip_prefix = "futures-task-0.3.13",
        build_file = Label("//prostgen/raze/remote:BUILD.futures-task-0.3.13.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__futures_util__0_3_13",
        url = "https://crates.io/api/v1/crates/futures-util/0.3.13/download",
        type = "tar.gz",
        sha256 = "1812c7ab8aedf8d6f2701a43e1243acdbcc2b36ab26e2ad421eb99ac963d96d1",
        strip_prefix = "futures-util-0.3.13",
        build_file = Label("//prostgen/raze/remote:BUILD.futures-util-0.3.13.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__getrandom__0_2_2",
        url = "https://crates.io/api/v1/crates/getrandom/0.2.2/download",
        type = "tar.gz",
        sha256 = "c9495705279e7140bf035dde1f6e750c162df8b625267cd52cc44e0b156732c8",
        strip_prefix = "getrandom-0.2.2",
        build_file = Label("//prostgen/raze/remote:BUILD.getrandom-0.2.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__h2__0_3_0",
        url = "https://crates.io/api/v1/crates/h2/0.3.0/download",
        type = "tar.gz",
        sha256 = "6b67e66362108efccd8ac053abafc8b7a8d86a37e6e48fc4f6f7485eb5e9e6a5",
        strip_prefix = "h2-0.3.0",
        build_file = Label("//prostgen/raze/remote:BUILD.h2-0.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__hashbrown__0_9_1",
        url = "https://crates.io/api/v1/crates/hashbrown/0.9.1/download",
        type = "tar.gz",
        sha256 = "d7afe4a420e3fe79967a00898cc1f4db7c8a49a9333a29f8a4bd76a253d5cd04",
        strip_prefix = "hashbrown-0.9.1",
        build_file = Label("//prostgen/raze/remote:BUILD.hashbrown-0.9.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__hermit_abi__0_1_18",
        url = "https://crates.io/api/v1/crates/hermit-abi/0.1.18/download",
        type = "tar.gz",
        sha256 = "322f4de77956e22ed0e5032c359a0f1273f1f7f0d79bfa3b8ffbc730d7fbcc5c",
        strip_prefix = "hermit-abi-0.1.18",
        build_file = Label("//prostgen/raze/remote:BUILD.hermit-abi-0.1.18.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__http__0_2_3",
        url = "https://crates.io/api/v1/crates/http/0.2.3/download",
        type = "tar.gz",
        sha256 = "7245cd7449cc792608c3c8a9eaf69bd4eabbabf802713748fd739c98b82f0747",
        strip_prefix = "http-0.2.3",
        build_file = Label("//prostgen/raze/remote:BUILD.http-0.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__http_body__0_4_0",
        url = "https://crates.io/api/v1/crates/http-body/0.4.0/download",
        type = "tar.gz",
        sha256 = "2861bd27ee074e5ee891e8b539837a9430012e249d7f0ca2d795650f579c1994",
        strip_prefix = "http-body-0.4.0",
        build_file = Label("//prostgen/raze/remote:BUILD.http-body-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__httparse__1_3_5",
        url = "https://crates.io/api/v1/crates/httparse/1.3.5/download",
        type = "tar.gz",
        sha256 = "615caabe2c3160b313d52ccc905335f4ed5f10881dd63dc5699d47e90be85691",
        strip_prefix = "httparse-1.3.5",
        build_file = Label("//prostgen/raze/remote:BUILD.httparse-1.3.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__httpdate__0_3_2",
        url = "https://crates.io/api/v1/crates/httpdate/0.3.2/download",
        type = "tar.gz",
        sha256 = "494b4d60369511e7dea41cf646832512a94e542f68bb9c49e54518e0f468eb47",
        strip_prefix = "httpdate-0.3.2",
        build_file = Label("//prostgen/raze/remote:BUILD.httpdate-0.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__hyper__0_14_4",
        url = "https://crates.io/api/v1/crates/hyper/0.14.4/download",
        type = "tar.gz",
        sha256 = "e8e946c2b1349055e0b72ae281b238baf1a3ea7307c7e9f9d64673bdd9c26ac7",
        strip_prefix = "hyper-0.14.4",
        build_file = Label("//prostgen/raze/remote:BUILD.hyper-0.14.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__hyper_tls__0_5_0",
        url = "https://crates.io/api/v1/crates/hyper-tls/0.5.0/download",
        type = "tar.gz",
        strip_prefix = "hyper-tls-0.5.0",
        build_file = Label("//prostgen/raze/remote:BUILD.hyper-tls-0.5.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__idna__0_2_2",
        url = "https://crates.io/api/v1/crates/idna/0.2.2/download",
        type = "tar.gz",
        strip_prefix = "idna-0.2.2",
        build_file = Label("//prostgen/raze/remote:BUILD.idna-0.2.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__indexmap__1_6_1",
        url = "https://crates.io/api/v1/crates/indexmap/1.6.1/download",
        type = "tar.gz",
        sha256 = "4fb1fa934250de4de8aef298d81c729a7d33d8c239daa3a7575e6b92bfc7313b",
        strip_prefix = "indexmap-1.6.1",
        build_file = Label("//prostgen/raze/remote:BUILD.indexmap-1.6.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__ipnet__2_3_0",
        url = "https://crates.io/api/v1/crates/ipnet/2.3.0/download",
        type = "tar.gz",
        strip_prefix = "ipnet-2.3.0",
        build_file = Label("//prostgen/raze/remote:BUILD.ipnet-2.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__itertools__0_9_0",
        url = "https://crates.io/api/v1/crates/itertools/0.9.0/download",
        type = "tar.gz",
        sha256 = "284f18f85651fe11e8a991b2adb42cb078325c996ed026d994719efcfca1d54b",
        strip_prefix = "itertools-0.9.0",
        build_file = Label("//prostgen/raze/remote:BUILD.itertools-0.9.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__itoa__0_4_7",
        url = "https://crates.io/api/v1/crates/itoa/0.4.7/download",
        type = "tar.gz",
        sha256 = "dd25036021b0de88a0aff6b850051563c6516d0bf53f8638938edbb9de732736",
        strip_prefix = "itoa-0.4.7",
        build_file = Label("//prostgen/raze/remote:BUILD.itoa-0.4.7.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__js_sys__0_3_47",
        url = "https://crates.io/api/v1/crates/js-sys/0.3.47/download",
        type = "tar.gz",
        strip_prefix = "js-sys-0.3.47",
        build_file = Label("//prostgen/raze/remote:BUILD.js-sys-0.3.47.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__lazy_static__1_4_0",
        url = "https://crates.io/api/v1/crates/lazy_static/1.4.0/download",
        type = "tar.gz",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        strip_prefix = "lazy_static-1.4.0",
        build_file = Label("//prostgen/raze/remote:BUILD.lazy_static-1.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__libc__0_2_86",
        url = "https://crates.io/api/v1/crates/libc/0.2.86/download",
        type = "tar.gz",
        sha256 = "b7282d924be3275cec7f6756ff4121987bc6481325397dde6ba3e7802b1a8b1c",
        strip_prefix = "libc-0.2.86",
        build_file = Label("//prostgen/raze/remote:BUILD.libc-0.2.86.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__log__0_4_14",
        url = "https://crates.io/api/v1/crates/log/0.4.14/download",
        type = "tar.gz",
        sha256 = "51b9bbe6c47d51fc3e1a9b945965946b4c44142ab8792c50835a980d362c2710",
        strip_prefix = "log-0.4.14",
        build_file = Label("//prostgen/raze/remote:BUILD.log-0.4.14.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__matches__0_1_8",
        url = "https://crates.io/api/v1/crates/matches/0.1.8/download",
        type = "tar.gz",
        strip_prefix = "matches-0.1.8",
        build_file = Label("//prostgen/raze/remote:BUILD.matches-0.1.8.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__memchr__2_3_4",
        url = "https://crates.io/api/v1/crates/memchr/2.3.4/download",
        type = "tar.gz",
        sha256 = "0ee1c47aaa256ecabcaea351eae4a9b01ef39ed810004e298d2511ed284b1525",
        strip_prefix = "memchr-2.3.4",
        build_file = Label("//prostgen/raze/remote:BUILD.memchr-2.3.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__mime__0_3_16",
        url = "https://crates.io/api/v1/crates/mime/0.3.16/download",
        type = "tar.gz",
        strip_prefix = "mime-0.3.16",
        build_file = Label("//prostgen/raze/remote:BUILD.mime-0.3.16.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__mio__0_7_9",
        url = "https://crates.io/api/v1/crates/mio/0.7.9/download",
        type = "tar.gz",
        sha256 = "a5dede4e2065b3842b8b0af444119f3aa331cc7cc2dd20388bfb0f5d5a38823a",
        strip_prefix = "mio-0.7.9",
        build_file = Label("//prostgen/raze/remote:BUILD.mio-0.7.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__miow__0_3_6",
        url = "https://crates.io/api/v1/crates/miow/0.3.6/download",
        type = "tar.gz",
        sha256 = "5a33c1b55807fbed163481b5ba66db4b2fa6cde694a5027be10fb724206c5897",
        strip_prefix = "miow-0.3.6",
        build_file = Label("//prostgen/raze/remote:BUILD.miow-0.3.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__native_tls__0_2_7",
        url = "https://crates.io/api/v1/crates/native-tls/0.2.7/download",
        type = "tar.gz",
        strip_prefix = "native-tls-0.2.7",
        build_file = Label("//prostgen/raze/remote:BUILD.native-tls-0.2.7.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__ntapi__0_3_6",
        url = "https://crates.io/api/v1/crates/ntapi/0.3.6/download",
        type = "tar.gz",
        sha256 = "3f6bb902e437b6d86e03cce10a7e2af662292c5dfef23b65899ea3ac9354ad44",
        strip_prefix = "ntapi-0.3.6",
        build_file = Label("//prostgen/raze/remote:BUILD.ntapi-0.3.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__num_cpus__1_13_0",
        url = "https://crates.io/api/v1/crates/num_cpus/1.13.0/download",
        type = "tar.gz",
        sha256 = "05499f3756671c15885fee9034446956fff3f243d6077b91e5767df161f766b3",
        strip_prefix = "num_cpus-1.13.0",
        build_file = Label("//prostgen/raze/remote:BUILD.num_cpus-1.13.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__openssl__0_10_32",
        url = "https://crates.io/api/v1/crates/openssl/0.10.32/download",
        type = "tar.gz",
        strip_prefix = "openssl-0.10.32",
        build_file = Label("//prostgen/raze/remote:BUILD.openssl-0.10.32.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__openssl_probe__0_1_2",
        url = "https://crates.io/api/v1/crates/openssl-probe/0.1.2/download",
        type = "tar.gz",
        strip_prefix = "openssl-probe-0.1.2",
        build_file = Label("//prostgen/raze/remote:BUILD.openssl-probe-0.1.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__openssl_sys__0_9_60",
        url = "https://crates.io/api/v1/crates/openssl-sys/0.9.60/download",
        type = "tar.gz",
        strip_prefix = "openssl-sys-0.9.60",
        build_file = Label("//prostgen/raze/remote:BUILD.openssl-sys-0.9.60.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__percent_encoding__2_1_0",
        url = "https://crates.io/api/v1/crates/percent-encoding/2.1.0/download",
        type = "tar.gz",
        sha256 = "d4fd5641d01c8f18a23da7b6fe29298ff4b55afcccdf78973b24cf3175fee32e",
        strip_prefix = "percent-encoding-2.1.0",
        build_file = Label("//prostgen/raze/remote:BUILD.percent-encoding-2.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__pin_project__1_0_5",
        url = "https://crates.io/api/v1/crates/pin-project/1.0.5/download",
        type = "tar.gz",
        sha256 = "96fa8ebb90271c4477f144354485b8068bd8f6b78b428b01ba892ca26caf0b63",
        strip_prefix = "pin-project-1.0.5",
        build_file = Label("//prostgen/raze/remote:BUILD.pin-project-1.0.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__pin_project_internal__1_0_5",
        url = "https://crates.io/api/v1/crates/pin-project-internal/1.0.5/download",
        type = "tar.gz",
        sha256 = "758669ae3558c6f74bd2a18b41f7ac0b5a195aea6639d6a9b5e5d1ad5ba24c0b",
        strip_prefix = "pin-project-internal-1.0.5",
        build_file = Label("//prostgen/raze/remote:BUILD.pin-project-internal-1.0.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__pin_project_lite__0_2_4",
        url = "https://crates.io/api/v1/crates/pin-project-lite/0.2.4/download",
        type = "tar.gz",
        sha256 = "439697af366c49a6d0a010c56a0d97685bc140ce0d377b13a2ea2aa42d64a827",
        strip_prefix = "pin-project-lite-0.2.4",
        build_file = Label("//prostgen/raze/remote:BUILD.pin-project-lite-0.2.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__pin_utils__0_1_0",
        url = "https://crates.io/api/v1/crates/pin-utils/0.1.0/download",
        type = "tar.gz",
        sha256 = "8b870d8c151b6f2fb93e84a13146138f05d02ed11c7e7c54f8826aaaf7c9f184",
        strip_prefix = "pin-utils-0.1.0",
        build_file = Label("//prostgen/raze/remote:BUILD.pin-utils-0.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__pkg_config__0_3_19",
        url = "https://crates.io/api/v1/crates/pkg-config/0.3.19/download",
        type = "tar.gz",
        strip_prefix = "pkg-config-0.3.19",
        build_file = Label("//prostgen/raze/remote:BUILD.pkg-config-0.3.19.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__ppv_lite86__0_2_10",
        url = "https://crates.io/api/v1/crates/ppv-lite86/0.2.10/download",
        type = "tar.gz",
        sha256 = "ac74c624d6b2d21f425f752262f42188365d7b8ff1aff74c82e45136510a4857",
        strip_prefix = "ppv-lite86-0.2.10",
        build_file = Label("//prostgen/raze/remote:BUILD.ppv-lite86-0.2.10.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__proc_macro2__1_0_24",
        url = "https://crates.io/api/v1/crates/proc-macro2/1.0.24/download",
        type = "tar.gz",
        sha256 = "1e0704ee1a7e00d7bb417d0770ea303c1bccbabf0ef1667dae92b5967f5f8a71",
        strip_prefix = "proc-macro2-1.0.24",
        build_file = Label("//prostgen/raze/remote:BUILD.proc-macro2-1.0.24.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__prost__0_7_0",
        url = "https://crates.io/api/v1/crates/prost/0.7.0/download",
        type = "tar.gz",
        sha256 = "9e6984d2f1a23009bd270b8bb56d0926810a3d483f59c987d77969e9d8e840b2",
        strip_prefix = "prost-0.7.0",
        build_file = Label("//prostgen/raze/remote:BUILD.prost-0.7.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__prost_derive__0_7_0",
        url = "https://crates.io/api/v1/crates/prost-derive/0.7.0/download",
        type = "tar.gz",
        sha256 = "169a15f3008ecb5160cba7d37bcd690a7601b6d30cfb87a117d45e59d52af5d4",
        strip_prefix = "prost-derive-0.7.0",
        build_file = Label("//prostgen/raze/remote:BUILD.prost-derive-0.7.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__quote__1_0_9",
        url = "https://crates.io/api/v1/crates/quote/1.0.9/download",
        type = "tar.gz",
        sha256 = "c3d0b9745dc2debf507c8422de05d7226cc1f0644216dfdfead988f9b1ab32a7",
        strip_prefix = "quote-1.0.9",
        build_file = Label("//prostgen/raze/remote:BUILD.quote-1.0.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__rand__0_8_3",
        url = "https://crates.io/api/v1/crates/rand/0.8.3/download",
        type = "tar.gz",
        sha256 = "0ef9e7e66b4468674bfcb0c81af8b7fa0bb154fa9f28eb840da5c447baeb8d7e",
        strip_prefix = "rand-0.8.3",
        build_file = Label("//prostgen/raze/remote:BUILD.rand-0.8.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__rand_chacha__0_3_0",
        url = "https://crates.io/api/v1/crates/rand_chacha/0.3.0/download",
        type = "tar.gz",
        sha256 = "e12735cf05c9e10bf21534da50a147b924d555dc7a547c42e6bb2d5b6017ae0d",
        strip_prefix = "rand_chacha-0.3.0",
        build_file = Label("//prostgen/raze/remote:BUILD.rand_chacha-0.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__rand_core__0_6_2",
        url = "https://crates.io/api/v1/crates/rand_core/0.6.2/download",
        type = "tar.gz",
        sha256 = "34cf66eb183df1c5876e2dcf6b13d57340741e8dc255b48e40a26de954d06ae7",
        strip_prefix = "rand_core-0.6.2",
        build_file = Label("//prostgen/raze/remote:BUILD.rand_core-0.6.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__rand_hc__0_3_0",
        url = "https://crates.io/api/v1/crates/rand_hc/0.3.0/download",
        type = "tar.gz",
        sha256 = "3190ef7066a446f2e7f42e239d161e905420ccab01eb967c9eb27d21b2322a73",
        strip_prefix = "rand_hc-0.3.0",
        build_file = Label("//prostgen/raze/remote:BUILD.rand_hc-0.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__redox_syscall__0_2_5",
        url = "https://crates.io/api/v1/crates/redox_syscall/0.2.5/download",
        type = "tar.gz",
        strip_prefix = "redox_syscall-0.2.5",
        build_file = Label("//prostgen/raze/remote:BUILD.redox_syscall-0.2.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__remove_dir_all__0_5_3",
        url = "https://crates.io/api/v1/crates/remove_dir_all/0.5.3/download",
        type = "tar.gz",
        strip_prefix = "remove_dir_all-0.5.3",
        build_file = Label("//prostgen/raze/remote:BUILD.remove_dir_all-0.5.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__reqwest__0_11_1",
        url = "https://crates.io/api/v1/crates/reqwest/0.11.1/download",
        type = "tar.gz",
        strip_prefix = "reqwest-0.11.1",
        build_file = Label("//prostgen/raze/remote:BUILD.reqwest-0.11.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__ryu__1_0_5",
        url = "https://crates.io/api/v1/crates/ryu/1.0.5/download",
        type = "tar.gz",
        strip_prefix = "ryu-1.0.5",
        build_file = Label("//prostgen/raze/remote:BUILD.ryu-1.0.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__schannel__0_1_19",
        url = "https://crates.io/api/v1/crates/schannel/0.1.19/download",
        type = "tar.gz",
        strip_prefix = "schannel-0.1.19",
        build_file = Label("//prostgen/raze/remote:BUILD.schannel-0.1.19.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__security_framework__2_1_0",
        url = "https://crates.io/api/v1/crates/security-framework/2.1.0/download",
        type = "tar.gz",
        strip_prefix = "security-framework-2.1.0",
        build_file = Label("//prostgen/raze/remote:BUILD.security-framework-2.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__security_framework_sys__2_1_0",
        url = "https://crates.io/api/v1/crates/security-framework-sys/2.1.0/download",
        type = "tar.gz",
        strip_prefix = "security-framework-sys-2.1.0",
        build_file = Label("//prostgen/raze/remote:BUILD.security-framework-sys-2.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__serde__1_0_123",
        url = "https://crates.io/api/v1/crates/serde/1.0.123/download",
        type = "tar.gz",
        strip_prefix = "serde-1.0.123",
        build_file = Label("//prostgen/raze/remote:BUILD.serde-1.0.123.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__serde_json__1_0_62",
        url = "https://crates.io/api/v1/crates/serde_json/1.0.62/download",
        type = "tar.gz",
        strip_prefix = "serde_json-1.0.62",
        build_file = Label("//prostgen/raze/remote:BUILD.serde_json-1.0.62.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__serde_urlencoded__0_7_0",
        url = "https://crates.io/api/v1/crates/serde_urlencoded/0.7.0/download",
        type = "tar.gz",
        strip_prefix = "serde_urlencoded-0.7.0",
        build_file = Label("//prostgen/raze/remote:BUILD.serde_urlencoded-0.7.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__slab__0_4_2",
        url = "https://crates.io/api/v1/crates/slab/0.4.2/download",
        type = "tar.gz",
        sha256 = "c111b5bd5695e56cffe5129854aa230b39c93a305372fdbb2668ca2394eea9f8",
        strip_prefix = "slab-0.4.2",
        build_file = Label("//prostgen/raze/remote:BUILD.slab-0.4.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__socket2__0_3_19",
        url = "https://crates.io/api/v1/crates/socket2/0.3.19/download",
        type = "tar.gz",
        sha256 = "122e570113d28d773067fab24266b66753f6ea915758651696b6e35e49f88d6e",
        strip_prefix = "socket2-0.3.19",
        build_file = Label("//prostgen/raze/remote:BUILD.socket2-0.3.19.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__syn__1_0_60",
        url = "https://crates.io/api/v1/crates/syn/1.0.60/download",
        type = "tar.gz",
        sha256 = "c700597eca8a5a762beb35753ef6b94df201c81cca676604f547495a0d7f0081",
        strip_prefix = "syn-1.0.60",
        build_file = Label("//prostgen/raze/remote:BUILD.syn-1.0.60.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__tempfile__3_2_0",
        url = "https://crates.io/api/v1/crates/tempfile/3.2.0/download",
        type = "tar.gz",
        strip_prefix = "tempfile-3.2.0",
        build_file = Label("//prostgen/raze/remote:BUILD.tempfile-3.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__tinyvec__1_1_1",
        url = "https://crates.io/api/v1/crates/tinyvec/1.1.1/download",
        type = "tar.gz",
        strip_prefix = "tinyvec-1.1.1",
        build_file = Label("//prostgen/raze/remote:BUILD.tinyvec-1.1.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__tinyvec_macros__0_1_0",
        url = "https://crates.io/api/v1/crates/tinyvec_macros/0.1.0/download",
        type = "tar.gz",
        strip_prefix = "tinyvec_macros-0.1.0",
        build_file = Label("//prostgen/raze/remote:BUILD.tinyvec_macros-0.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__tokio__1_0_2",
        url = "https://crates.io/api/v1/crates/tokio/1.0.2/download",
        type = "tar.gz",
        sha256 = "0ca04cec6ff2474c638057b65798f60ac183e5e79d3448bb7163d36a39cff6ec",
        strip_prefix = "tokio-1.0.2",
        build_file = Label("//prostgen/raze/remote:BUILD.tokio-1.0.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__tokio_macros__1_1_0",
        url = "https://crates.io/api/v1/crates/tokio-macros/1.1.0/download",
        type = "tar.gz",
        sha256 = "caf7b11a536f46a809a8a9f0bb4237020f70ecbf115b842360afb127ea2fda57",
        strip_prefix = "tokio-macros-1.1.0",
        build_file = Label("//prostgen/raze/remote:BUILD.tokio-macros-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__tokio_native_tls__0_3_0",
        url = "https://crates.io/api/v1/crates/tokio-native-tls/0.3.0/download",
        type = "tar.gz",
        strip_prefix = "tokio-native-tls-0.3.0",
        build_file = Label("//prostgen/raze/remote:BUILD.tokio-native-tls-0.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__tokio_stream__0_1_3",
        url = "https://crates.io/api/v1/crates/tokio-stream/0.1.3/download",
        type = "tar.gz",
        sha256 = "1981ad97df782ab506a1f43bf82c967326960d278acf3bf8279809648c3ff3ea",
        strip_prefix = "tokio-stream-0.1.3",
        build_file = Label("//prostgen/raze/remote:BUILD.tokio-stream-0.1.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__tokio_util__0_6_3",
        url = "https://crates.io/api/v1/crates/tokio-util/0.6.3/download",
        type = "tar.gz",
        sha256 = "ebb7cb2f00c5ae8df755b252306272cd1790d39728363936e01827e11f0b017b",
        strip_prefix = "tokio-util-0.6.3",
        build_file = Label("//prostgen/raze/remote:BUILD.tokio-util-0.6.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__tonic__0_4_0",
        url = "https://crates.io/api/v1/crates/tonic/0.4.0/download",
        type = "tar.gz",
        sha256 = "3ba8f479158947373b6df40cf48f4779bb25c99ca3c661bd95e0ab1963ad8b0e",
        strip_prefix = "tonic-0.4.0",
        build_file = Label("//prostgen/raze/remote:BUILD.tonic-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__tower__0_4_5",
        url = "https://crates.io/api/v1/crates/tower/0.4.5/download",
        type = "tar.gz",
        sha256 = "713c629c07a3a97f741c140e474e7304294fabec66a43a33f0832e98315ab07f",
        strip_prefix = "tower-0.4.5",
        build_file = Label("//prostgen/raze/remote:BUILD.tower-0.4.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__tower_layer__0_3_1",
        url = "https://crates.io/api/v1/crates/tower-layer/0.3.1/download",
        type = "tar.gz",
        sha256 = "343bc9466d3fe6b0f960ef45960509f84480bf4fd96f92901afe7ff3df9d3a62",
        strip_prefix = "tower-layer-0.3.1",
        build_file = Label("//prostgen/raze/remote:BUILD.tower-layer-0.3.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__tower_service__0_3_1",
        url = "https://crates.io/api/v1/crates/tower-service/0.3.1/download",
        type = "tar.gz",
        sha256 = "360dfd1d6d30e05fda32ace2c8c70e9c0a9da713275777f5a4dbb8a1893930c6",
        strip_prefix = "tower-service-0.3.1",
        build_file = Label("//prostgen/raze/remote:BUILD.tower-service-0.3.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__tracing__0_1_25",
        url = "https://crates.io/api/v1/crates/tracing/0.1.25/download",
        type = "tar.gz",
        sha256 = "01ebdc2bb4498ab1ab5f5b73c5803825e60199229ccba0698170e3be0e7f959f",
        strip_prefix = "tracing-0.1.25",
        build_file = Label("//prostgen/raze/remote:BUILD.tracing-0.1.25.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__tracing_attributes__0_1_13",
        url = "https://crates.io/api/v1/crates/tracing-attributes/0.1.13/download",
        type = "tar.gz",
        sha256 = "a8a9bd1db7706f2373a190b0d067146caa39350c486f3d455b0e33b431f94c07",
        strip_prefix = "tracing-attributes-0.1.13",
        build_file = Label("//prostgen/raze/remote:BUILD.tracing-attributes-0.1.13.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__tracing_core__0_1_17",
        url = "https://crates.io/api/v1/crates/tracing-core/0.1.17/download",
        type = "tar.gz",
        sha256 = "f50de3927f93d202783f4513cda820ab47ef17f624b03c096e86ef00c67e6b5f",
        strip_prefix = "tracing-core-0.1.17",
        build_file = Label("//prostgen/raze/remote:BUILD.tracing-core-0.1.17.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__tracing_futures__0_2_5",
        url = "https://crates.io/api/v1/crates/tracing-futures/0.2.5/download",
        type = "tar.gz",
        sha256 = "97d095ae15e245a057c8e8451bab9b3ee1e1f68e9ba2b4fbc18d0ac5237835f2",
        strip_prefix = "tracing-futures-0.2.5",
        build_file = Label("//prostgen/raze/remote:BUILD.tracing-futures-0.2.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__try_lock__0_2_3",
        url = "https://crates.io/api/v1/crates/try-lock/0.2.3/download",
        type = "tar.gz",
        sha256 = "59547bce71d9c38b83d9c0e92b6066c4253371f15005def0c30d9657f50c7642",
        strip_prefix = "try-lock-0.2.3",
        build_file = Label("//prostgen/raze/remote:BUILD.try-lock-0.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__unicode_bidi__0_3_4",
        url = "https://crates.io/api/v1/crates/unicode-bidi/0.3.4/download",
        type = "tar.gz",
        strip_prefix = "unicode-bidi-0.3.4",
        build_file = Label("//prostgen/raze/remote:BUILD.unicode-bidi-0.3.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__unicode_normalization__0_1_17",
        url = "https://crates.io/api/v1/crates/unicode-normalization/0.1.17/download",
        type = "tar.gz",
        strip_prefix = "unicode-normalization-0.1.17",
        build_file = Label("//prostgen/raze/remote:BUILD.unicode-normalization-0.1.17.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__unicode_xid__0_2_1",
        url = "https://crates.io/api/v1/crates/unicode-xid/0.2.1/download",
        type = "tar.gz",
        sha256 = "f7fe0bb3479651439c9112f72b6c505038574c9fbb575ed1bf3b797fa39dd564",
        strip_prefix = "unicode-xid-0.2.1",
        build_file = Label("//prostgen/raze/remote:BUILD.unicode-xid-0.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__url__2_2_1",
        url = "https://crates.io/api/v1/crates/url/2.2.1/download",
        type = "tar.gz",
        strip_prefix = "url-2.2.1",
        build_file = Label("//prostgen/raze/remote:BUILD.url-2.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__vcpkg__0_2_11",
        url = "https://crates.io/api/v1/crates/vcpkg/0.2.11/download",
        type = "tar.gz",
        strip_prefix = "vcpkg-0.2.11",
        build_file = Label("//prostgen/raze/remote:BUILD.vcpkg-0.2.11.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__want__0_3_0",
        url = "https://crates.io/api/v1/crates/want/0.3.0/download",
        type = "tar.gz",
        sha256 = "1ce8a968cb1cd110d136ff8b819a556d6fb6d919363c61534f6860c7eb172ba0",
        strip_prefix = "want-0.3.0",
        build_file = Label("//prostgen/raze/remote:BUILD.want-0.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__wasi__0_10_2_wasi_snapshot_preview1",
        url = "https://crates.io/api/v1/crates/wasi/0.10.2+wasi-snapshot-preview1/download",
        type = "tar.gz",
        sha256 = "fd6fbd9a79829dd1ad0cc20627bf1ed606756a7f77edff7b66b7064f9cb327c6",
        strip_prefix = "wasi-0.10.2+wasi-snapshot-preview1",
        build_file = Label("//prostgen/raze/remote:BUILD.wasi-0.10.2+wasi-snapshot-preview1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__wasm_bindgen__0_2_70",
        url = "https://crates.io/api/v1/crates/wasm-bindgen/0.2.70/download",
        type = "tar.gz",
        strip_prefix = "wasm-bindgen-0.2.70",
        build_file = Label("//prostgen/raze/remote:BUILD.wasm-bindgen-0.2.70.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__wasm_bindgen_backend__0_2_70",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-backend/0.2.70/download",
        type = "tar.gz",
        strip_prefix = "wasm-bindgen-backend-0.2.70",
        build_file = Label("//prostgen/raze/remote:BUILD.wasm-bindgen-backend-0.2.70.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__wasm_bindgen_futures__0_4_20",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-futures/0.4.20/download",
        type = "tar.gz",
        strip_prefix = "wasm-bindgen-futures-0.4.20",
        build_file = Label("//prostgen/raze/remote:BUILD.wasm-bindgen-futures-0.4.20.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__wasm_bindgen_macro__0_2_70",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-macro/0.2.70/download",
        type = "tar.gz",
        strip_prefix = "wasm-bindgen-macro-0.2.70",
        build_file = Label("//prostgen/raze/remote:BUILD.wasm-bindgen-macro-0.2.70.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__wasm_bindgen_macro_support__0_2_70",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-macro-support/0.2.70/download",
        type = "tar.gz",
        strip_prefix = "wasm-bindgen-macro-support-0.2.70",
        build_file = Label("//prostgen/raze/remote:BUILD.wasm-bindgen-macro-support-0.2.70.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__wasm_bindgen_shared__0_2_70",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-shared/0.2.70/download",
        type = "tar.gz",
        strip_prefix = "wasm-bindgen-shared-0.2.70",
        build_file = Label("//prostgen/raze/remote:BUILD.wasm-bindgen-shared-0.2.70.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__web_sys__0_3_47",
        url = "https://crates.io/api/v1/crates/web-sys/0.3.47/download",
        type = "tar.gz",
        strip_prefix = "web-sys-0.3.47",
        build_file = Label("//prostgen/raze/remote:BUILD.web-sys-0.3.47.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__winapi__0_3_9",
        url = "https://crates.io/api/v1/crates/winapi/0.3.9/download",
        type = "tar.gz",
        sha256 = "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419",
        strip_prefix = "winapi-0.3.9",
        build_file = Label("//prostgen/raze/remote:BUILD.winapi-0.3.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__winapi_i686_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-i686-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("//prostgen/raze/remote:BUILD.winapi-i686-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__winapi_x86_64_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-x86_64-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("//prostgen/raze/remote:BUILD.winapi-x86_64-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_prostgen__winreg__0_7_0",
        url = "https://crates.io/api/v1/crates/winreg/0.7.0/download",
        type = "tar.gz",
        strip_prefix = "winreg-0.7.0",
        build_file = Label("//prostgen/raze/remote:BUILD.winreg-0.7.0.bazel"),
    )
