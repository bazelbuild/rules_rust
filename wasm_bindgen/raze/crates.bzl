"""
cargo-raze crate workspace functions

DO NOT EDIT! Replaced on runs of cargo-raze
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")

def _new_http_archive(name, **kwargs):
    if not native.existing_rule(name):
        http_archive(name = name, **kwargs)

def _new_git_repository(name, **kwargs):
    if not native.existing_rule(name):
        new_git_repository(name = name, **kwargs)

def raze_fetch_remote_crates():
    _new_http_archive(
        name = "raze__aho_corasick__0_7_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/aho-corasick/aho-corasick-0.7.3.crate",
        type = "tar.gz",
        sha256 = "e6f484ae0c99fec2e858eb6134949117399f222608d84cadb3f58c1f97c2364c",
        strip_prefix = "aho-corasick-0.7.3",
        build_file = Label("//wasm_bindgen/raze/remote:aho-corasick-0.7.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__argon2rs__0_2_5",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/argon2rs/argon2rs-0.2.5.crate",
        type = "tar.gz",
        sha256 = "3f67b0b6a86dae6e67ff4ca2b6201396074996379fba2b92ff649126f37cb392",
        strip_prefix = "argon2rs-0.2.5",
        build_file = Label("//wasm_bindgen/raze/remote:argon2rs-0.2.5.BUILD"),
    )

    _new_http_archive(
        name = "raze__arrayvec__0_4_10",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/arrayvec/arrayvec-0.4.10.crate",
        type = "tar.gz",
        sha256 = "92c7fb76bc8826a8b33b4ee5bb07a247a81e76764ab4d55e8f73e3a4d8808c71",
        strip_prefix = "arrayvec-0.4.10",
        build_file = Label("//wasm_bindgen/raze/remote:arrayvec-0.4.10.BUILD"),
    )

    _new_http_archive(
        name = "raze__ascii__0_8_7",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/ascii/ascii-0.8.7.crate",
        type = "tar.gz",
        sha256 = "97be891acc47ca214468e09425d02cef3af2c94d0d82081cd02061f996802f14",
        strip_prefix = "ascii-0.8.7",
        build_file = Label("//wasm_bindgen/raze/remote:ascii-0.8.7.BUILD"),
    )

    _new_http_archive(
        name = "raze__atty__0_2_11",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/atty/atty-0.2.11.crate",
        type = "tar.gz",
        sha256 = "9a7d5b8723950951411ee34d271d99dddcc2035a16ab25310ea2c8cfd4369652",
        strip_prefix = "atty-0.2.11",
        build_file = Label("//wasm_bindgen/raze/remote:atty-0.2.11.BUILD"),
    )

    _new_http_archive(
        name = "raze__autocfg__0_1_4",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/autocfg/autocfg-0.1.4.crate",
        type = "tar.gz",
        sha256 = "0e49efa51329a5fd37e7c79db4621af617cd4e3e5bc224939808d076077077bf",
        strip_prefix = "autocfg-0.1.4",
        build_file = Label("//wasm_bindgen/raze/remote:autocfg-0.1.4.BUILD"),
    )

    _new_http_archive(
        name = "raze__backtrace__0_3_32",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/backtrace/backtrace-0.3.32.crate",
        type = "tar.gz",
        sha256 = "18b50f5258d1a9ad8396d2d345827875de4261b158124d4c819d9b351454fae5",
        strip_prefix = "backtrace-0.3.32",
        build_file = Label("//wasm_bindgen/raze/remote:backtrace-0.3.32.BUILD"),
    )

    _new_http_archive(
        name = "raze__backtrace_sys__0_1_29",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/backtrace-sys/backtrace-sys-0.1.29.crate",
        type = "tar.gz",
        sha256 = "12cb9f1eef1d1fc869ad5a26c9fa48516339a15e54a227a25460fc304815fdb3",
        strip_prefix = "backtrace-sys-0.1.29",
        build_file = Label("//wasm_bindgen/raze/remote:backtrace-sys-0.1.29.BUILD"),
    )

    _new_http_archive(
        name = "raze__base64__0_9_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/base64/base64-0.9.3.crate",
        type = "tar.gz",
        sha256 = "489d6c0ed21b11d038c31b6ceccca973e65d73ba3bd8ecb9a2babf5546164643",
        strip_prefix = "base64-0.9.3",
        build_file = Label("//wasm_bindgen/raze/remote:base64-0.9.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__bitflags__1_1_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/bitflags/bitflags-1.1.0.crate",
        type = "tar.gz",
        sha256 = "3d155346769a6855b86399e9bc3814ab343cd3d62c7e985113d46a0ec3c281fd",
        strip_prefix = "bitflags-1.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:bitflags-1.1.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__blake2_rfc__0_2_18",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/blake2-rfc/blake2-rfc-0.2.18.crate",
        type = "tar.gz",
        sha256 = "5d6d530bdd2d52966a6d03b7a964add7ae1a288d25214066fd4b600f0f796400",
        strip_prefix = "blake2-rfc-0.2.18",
        build_file = Label("//wasm_bindgen/raze/remote:blake2-rfc-0.2.18.BUILD"),
    )

    _new_http_archive(
        name = "raze__buf_redux__0_8_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/buf_redux/buf_redux-0.8.1.crate",
        type = "tar.gz",
        sha256 = "72f25c67abbf523ff8457771622fb731ac4a2391439de33bc60febcdee1749c9",
        strip_prefix = "buf_redux-0.8.1",
        build_file = Label("//wasm_bindgen/raze/remote:buf_redux-0.8.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__bumpalo__2_4_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/bumpalo/bumpalo-2.4.3.crate",
        type = "tar.gz",
        sha256 = "84dca3afd8e01b9526818b7963e5b4916063b3cdf9f10cf6b73ef0bd0ec37aa5",
        strip_prefix = "bumpalo-2.4.3",
        build_file = Label("//wasm_bindgen/raze/remote:bumpalo-2.4.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__byteorder__1_3_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/byteorder/byteorder-1.3.2.crate",
        type = "tar.gz",
        sha256 = "a7c3dd8985a7111efc5c80b44e23ecdd8c007de8ade3b96595387e812b957cf5",
        strip_prefix = "byteorder-1.3.2",
        build_file = Label("//wasm_bindgen/raze/remote:byteorder-1.3.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__cc__1_0_37",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/cc/cc-1.0.37.crate",
        type = "tar.gz",
        sha256 = "39f75544d7bbaf57560d2168f28fd649ff9c76153874db88bdbdfd839b1a7e7d",
        strip_prefix = "cc-1.0.37",
        build_file = Label("//wasm_bindgen/raze/remote:cc-1.0.37.BUILD"),
    )

    _new_http_archive(
        name = "raze__cfg_if__0_1_9",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/cfg-if/cfg-if-0.1.9.crate",
        type = "tar.gz",
        sha256 = "b486ce3ccf7ffd79fdeb678eac06a9e6c09fc88d33836340becb8fffe87c5e33",
        strip_prefix = "cfg-if-0.1.9",
        build_file = Label("//wasm_bindgen/raze/remote:cfg-if-0.1.9.BUILD"),
    )

    _new_http_archive(
        name = "raze__chrono__0_4_7",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/chrono/chrono-0.4.7.crate",
        type = "tar.gz",
        sha256 = "77d81f58b7301084de3b958691458a53c3f7e0b1d702f77e550b6a88e3a88abe",
        strip_prefix = "chrono-0.4.7",
        build_file = Label("//wasm_bindgen/raze/remote:chrono-0.4.7.BUILD"),
    )

    _new_http_archive(
        name = "raze__chunked_transfer__0_3_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/chunked_transfer/chunked_transfer-0.3.1.crate",
        type = "tar.gz",
        sha256 = "498d20a7aaf62625b9bf26e637cf7736417cde1d0c99f1d04d1170229a85cf87",
        strip_prefix = "chunked_transfer-0.3.1",
        build_file = Label("//wasm_bindgen/raze/remote:chunked_transfer-0.3.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__cloudabi__0_0_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/cloudabi/cloudabi-0.0.3.crate",
        type = "tar.gz",
        sha256 = "ddfc5b9aa5d4507acaf872de71051dfd0e309860e88966e1051e462a077aac4f",
        strip_prefix = "cloudabi-0.0.3",
        build_file = Label("//wasm_bindgen/raze/remote:cloudabi-0.0.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__constant_time_eq__0_1_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/constant_time_eq/constant_time_eq-0.1.3.crate",
        type = "tar.gz",
        sha256 = "8ff012e225ce166d4422e0e78419d901719760f62ae2b7969ca6b564d1b54a9e",
        strip_prefix = "constant_time_eq-0.1.3",
        build_file = Label("//wasm_bindgen/raze/remote:constant_time_eq-0.1.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__crossbeam_deque__0_6_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crossbeam-deque/crossbeam-deque-0.6.3.crate",
        type = "tar.gz",
        sha256 = "05e44b8cf3e1a625844d1750e1f7820da46044ff6d28f4d43e455ba3e5bb2c13",
        strip_prefix = "crossbeam-deque-0.6.3",
        build_file = Label("//wasm_bindgen/raze/remote:crossbeam-deque-0.6.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__crossbeam_epoch__0_7_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crossbeam-epoch/crossbeam-epoch-0.7.1.crate",
        type = "tar.gz",
        sha256 = "04c9e3102cc2d69cd681412141b390abd55a362afc1540965dad0ad4d34280b4",
        strip_prefix = "crossbeam-epoch-0.7.1",
        build_file = Label("//wasm_bindgen/raze/remote:crossbeam-epoch-0.7.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__crossbeam_queue__0_1_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crossbeam-queue/crossbeam-queue-0.1.2.crate",
        type = "tar.gz",
        sha256 = "7c979cd6cfe72335896575c6b5688da489e420d36a27a0b9eb0c73db574b4a4b",
        strip_prefix = "crossbeam-queue-0.1.2",
        build_file = Label("//wasm_bindgen/raze/remote:crossbeam-queue-0.1.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__crossbeam_utils__0_6_5",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crossbeam-utils/crossbeam-utils-0.6.5.crate",
        type = "tar.gz",
        sha256 = "f8306fcef4a7b563b76b7dd949ca48f52bc1141aa067d2ea09565f3e2652aa5c",
        strip_prefix = "crossbeam-utils-0.6.5",
        build_file = Label("//wasm_bindgen/raze/remote:crossbeam-utils-0.6.5.BUILD"),
    )

    _new_http_archive(
        name = "raze__curl__0_4_22",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/curl/curl-0.4.22.crate",
        type = "tar.gz",
        sha256 = "f8ed9a22aa8c4e49ac0c896279ef532a43a7df2f54fcd19fa36960de029f965f",
        strip_prefix = "curl-0.4.22",
        build_file = Label("//wasm_bindgen/raze/remote:curl-0.4.22.BUILD"),
    )

    _new_http_archive(
        name = "raze__curl_sys__0_4_19",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/curl-sys/curl-sys-0.4.19.crate",
        type = "tar.gz",
        sha256 = "d2427916f870661c5473e41bb7a5ac08d1a01ae1a4db495f724e7b7212e40a73",
        strip_prefix = "curl-sys-0.4.19",
        build_file = Label("//wasm_bindgen/raze/remote:curl-sys-0.4.19.BUILD"),
    )

    _new_http_archive(
        name = "raze__dirs__1_0_5",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/dirs/dirs-1.0.5.crate",
        type = "tar.gz",
        sha256 = "3fd78930633bd1c6e35c4b42b1df7b0cbc6bc191146e512bb3bedf243fcc3901",
        strip_prefix = "dirs-1.0.5",
        build_file = Label("//wasm_bindgen/raze/remote:dirs-1.0.5.BUILD"),
    )

    _new_http_archive(
        name = "raze__docopt__1_1_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/docopt/docopt-1.1.0.crate",
        type = "tar.gz",
        sha256 = "7f525a586d310c87df72ebcd98009e57f1cc030c8c268305287a476beb653969",
        strip_prefix = "docopt-1.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:docopt-1.1.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__either__1_5_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/either/either-1.5.2.crate",
        type = "tar.gz",
        sha256 = "5527cfe0d098f36e3f8839852688e63c8fff1c90b2b405aef730615f9a7bcf7b",
        strip_prefix = "either-1.5.2",
        build_file = Label("//wasm_bindgen/raze/remote:either-1.5.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__env_logger__0_6_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/env_logger/env_logger-0.6.1.crate",
        type = "tar.gz",
        sha256 = "b61fa891024a945da30a9581546e8cfaf5602c7b3f4c137a2805cf388f92075a",
        strip_prefix = "env_logger-0.6.1",
        build_file = Label("//wasm_bindgen/raze/remote:env_logger-0.6.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__failure__0_1_5",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/failure/failure-0.1.5.crate",
        type = "tar.gz",
        sha256 = "795bd83d3abeb9220f257e597aa0080a508b27533824adf336529648f6abf7e2",
        strip_prefix = "failure-0.1.5",
        build_file = Label("//wasm_bindgen/raze/remote:failure-0.1.5.BUILD"),
    )

    _new_http_archive(
        name = "raze__failure_derive__0_1_5",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/failure_derive/failure_derive-0.1.5.crate",
        type = "tar.gz",
        sha256 = "ea1063915fd7ef4309e222a5a07cf9c319fb9c7836b1f89b85458672dbb127e1",
        strip_prefix = "failure_derive-0.1.5",
        build_file = Label("//wasm_bindgen/raze/remote:failure_derive-0.1.5.BUILD"),
    )

    _new_http_archive(
        name = "raze__filetime__0_2_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/filetime/filetime-0.2.6.crate",
        type = "tar.gz",
        sha256 = "450537dc346f0c4d738dda31e790da1da5d4bd12145aad4da0d03d713cb3794f",
        strip_prefix = "filetime-0.2.6",
        build_file = Label("//wasm_bindgen/raze/remote:filetime-0.2.6.BUILD"),
    )

    _new_http_archive(
        name = "raze__fuchsia_cprng__0_1_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/fuchsia-cprng/fuchsia-cprng-0.1.1.crate",
        type = "tar.gz",
        sha256 = "a06f77d526c1a601b7c4cdd98f54b5eaabffc14d5f2f0296febdc7f357c6d3ba",
        strip_prefix = "fuchsia-cprng-0.1.1",
        build_file = Label("//wasm_bindgen/raze/remote:fuchsia-cprng-0.1.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__heck__0_3_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/heck/heck-0.3.1.crate",
        type = "tar.gz",
        sha256 = "20564e78d53d2bb135c343b3f47714a56af2061f1c928fdb541dc7b9fdd94205",
        strip_prefix = "heck-0.3.1",
        build_file = Label("//wasm_bindgen/raze/remote:heck-0.3.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__httparse__1_3_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/httparse/httparse-1.3.3.crate",
        type = "tar.gz",
        sha256 = "e8734b0cfd3bc3e101ec59100e101c2eecd19282202e87808b3037b442777a83",
        strip_prefix = "httparse-1.3.3",
        build_file = Label("//wasm_bindgen/raze/remote:httparse-1.3.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__humantime__1_2_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/humantime/humantime-1.2.0.crate",
        type = "tar.gz",
        sha256 = "3ca7e5f2e110db35f93b837c81797f3714500b81d517bf20c431b16d3ca4f114",
        strip_prefix = "humantime-1.2.0",
        build_file = Label("//wasm_bindgen/raze/remote:humantime-1.2.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__id_arena__2_2_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/id-arena/id-arena-2.2.1.crate",
        type = "tar.gz",
        sha256 = "25a2bc672d1148e28034f176e01fffebb08b35768468cc954630da77a1449005",
        strip_prefix = "id-arena-2.2.1",
        build_file = Label("//wasm_bindgen/raze/remote:id-arena-2.2.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__idna__0_1_5",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/idna/idna-0.1.5.crate",
        type = "tar.gz",
        sha256 = "38f09e0f0b1fb55fdee1f17470ad800da77af5186a1a76c026b679358b7e844e",
        strip_prefix = "idna-0.1.5",
        build_file = Label("//wasm_bindgen/raze/remote:idna-0.1.5.BUILD"),
    )

    _new_http_archive(
        name = "raze__itoa__0_4_4",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/itoa/itoa-0.4.4.crate",
        type = "tar.gz",
        sha256 = "501266b7edd0174f8530248f87f99c88fbe60ca4ef3dd486835b8d8d53136f7f",
        strip_prefix = "itoa-0.4.4",
        build_file = Label("//wasm_bindgen/raze/remote:itoa-0.4.4.BUILD"),
    )

    _new_http_archive(
        name = "raze__kernel32_sys__0_2_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/kernel32-sys/kernel32-sys-0.2.2.crate",
        type = "tar.gz",
        sha256 = "7507624b29483431c0ba2d82aece8ca6cdba9382bff4ddd0f7490560c056098d",
        strip_prefix = "kernel32-sys-0.2.2",
        build_file = Label("//wasm_bindgen/raze/remote:kernel32-sys-0.2.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__lazy_static__1_3_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/lazy_static/lazy_static-1.3.0.crate",
        type = "tar.gz",
        sha256 = "bc5729f27f159ddd61f4df6228e827e86643d4d3e7c32183cb30a1c08f604a14",
        strip_prefix = "lazy_static-1.3.0",
        build_file = Label("//wasm_bindgen/raze/remote:lazy_static-1.3.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__leb128__0_2_4",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/leb128/leb128-0.2.4.crate",
        type = "tar.gz",
        sha256 = "3576a87f2ba00f6f106fdfcd16db1d698d648a26ad8e0573cad8537c3c362d2a",
        strip_prefix = "leb128-0.2.4",
        build_file = Label("//wasm_bindgen/raze/remote:leb128-0.2.4.BUILD"),
    )

    _new_http_archive(
        name = "raze__libc__0_2_58",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/libc/libc-0.2.58.crate",
        type = "tar.gz",
        sha256 = "6281b86796ba5e4366000be6e9e18bf35580adf9e63fbe2294aadb587613a319",
        strip_prefix = "libc-0.2.58",
        build_file = Label("//wasm_bindgen/raze/remote:libc-0.2.58.BUILD"),
    )

    _new_http_archive(
        name = "raze__libz_sys__1_0_25",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/libz-sys/libz-sys-1.0.25.crate",
        type = "tar.gz",
        sha256 = "2eb5e43362e38e2bca2fd5f5134c4d4564a23a5c28e9b95411652021a8675ebe",
        strip_prefix = "libz-sys-1.0.25",
        build_file = Label("//wasm_bindgen/raze/remote:libz-sys-1.0.25.BUILD"),
    )

    _new_http_archive(
        name = "raze__log__0_4_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/log/log-0.4.6.crate",
        type = "tar.gz",
        sha256 = "c84ec4b527950aa83a329754b01dbe3f58361d1c5efacd1f6d68c494d08a17c6",
        strip_prefix = "log-0.4.6",
        build_file = Label("//wasm_bindgen/raze/remote:log-0.4.6.BUILD"),
    )

    _new_http_archive(
        name = "raze__matches__0_1_8",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/matches/matches-0.1.8.crate",
        type = "tar.gz",
        sha256 = "7ffc5c5338469d4d3ea17d269fa8ea3512ad247247c30bd2df69e68309ed0a08",
        strip_prefix = "matches-0.1.8",
        build_file = Label("//wasm_bindgen/raze/remote:matches-0.1.8.BUILD"),
    )

    _new_http_archive(
        name = "raze__memchr__2_2_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/memchr/memchr-2.2.0.crate",
        type = "tar.gz",
        sha256 = "2efc7bc57c883d4a4d6e3246905283d8dae951bb3bd32f49d6ef297f546e1c39",
        strip_prefix = "memchr-2.2.0",
        build_file = Label("//wasm_bindgen/raze/remote:memchr-2.2.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__memoffset__0_2_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/memoffset/memoffset-0.2.1.crate",
        type = "tar.gz",
        sha256 = "0f9dc261e2b62d7a622bf416ea3c5245cdd5d9a7fcc428c0d06804dfce1775b3",
        strip_prefix = "memoffset-0.2.1",
        build_file = Label("//wasm_bindgen/raze/remote:memoffset-0.2.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__mime__0_2_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/mime/mime-0.2.6.crate",
        type = "tar.gz",
        sha256 = "ba626b8a6de5da682e1caa06bdb42a335aee5a84db8e5046a3e8ab17ba0a3ae0",
        strip_prefix = "mime-0.2.6",
        build_file = Label("//wasm_bindgen/raze/remote:mime-0.2.6.BUILD"),
    )

    _new_http_archive(
        name = "raze__mime_guess__1_8_7",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/mime_guess/mime_guess-1.8.7.crate",
        type = "tar.gz",
        sha256 = "0d977de9ee851a0b16e932979515c0f3da82403183879811bc97d50bd9cc50f7",
        strip_prefix = "mime_guess-1.8.7",
        build_file = Label("//wasm_bindgen/raze/remote:mime_guess-1.8.7.BUILD"),
    )

    _new_http_archive(
        name = "raze__multipart__0_15_4",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/multipart/multipart-0.15.4.crate",
        type = "tar.gz",
        sha256 = "adba94490a79baf2d6a23eac897157047008272fa3eecb3373ae6377b91eca28",
        strip_prefix = "multipart-0.15.4",
        build_file = Label("//wasm_bindgen/raze/remote:multipart-0.15.4.BUILD"),
    )

    _new_http_archive(
        name = "raze__nodrop__0_1_13",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/nodrop/nodrop-0.1.13.crate",
        type = "tar.gz",
        sha256 = "2f9667ddcc6cc8a43afc9b7917599d7216aa09c463919ea32c59ed6cac8bc945",
        strip_prefix = "nodrop-0.1.13",
        build_file = Label("//wasm_bindgen/raze/remote:nodrop-0.1.13.BUILD"),
    )

    _new_http_archive(
        name = "raze__num_integer__0_1_41",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/num-integer/num-integer-0.1.41.crate",
        type = "tar.gz",
        sha256 = "b85e541ef8255f6cf42bbfe4ef361305c6c135d10919ecc26126c4e5ae94bc09",
        strip_prefix = "num-integer-0.1.41",
        build_file = Label("//wasm_bindgen/raze/remote:num-integer-0.1.41.BUILD"),
    )

    _new_http_archive(
        name = "raze__num_traits__0_2_8",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/num-traits/num-traits-0.2.8.crate",
        type = "tar.gz",
        sha256 = "6ba9a427cfca2be13aa6f6403b0b7e7368fe982bfa16fccc450ce74c46cd9b32",
        strip_prefix = "num-traits-0.2.8",
        build_file = Label("//wasm_bindgen/raze/remote:num-traits-0.2.8.BUILD"),
    )

    _new_http_archive(
        name = "raze__num_cpus__1_10_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/num_cpus/num_cpus-1.10.1.crate",
        type = "tar.gz",
        sha256 = "bcef43580c035376c0705c42792c294b66974abbfd2789b511784023f71f3273",
        strip_prefix = "num_cpus-1.10.1",
        build_file = Label("//wasm_bindgen/raze/remote:num_cpus-1.10.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__numtoa__0_1_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/numtoa/numtoa-0.1.0.crate",
        type = "tar.gz",
        sha256 = "b8f8bdf33df195859076e54ab11ee78a1b208382d3a26ec40d142ffc1ecc49ef",
        strip_prefix = "numtoa-0.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:numtoa-0.1.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__openssl_probe__0_1_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/openssl-probe/openssl-probe-0.1.2.crate",
        type = "tar.gz",
        sha256 = "77af24da69f9d9341038eba93a073b1fdaaa1b788221b00a69bce9e762cb32de",
        strip_prefix = "openssl-probe-0.1.2",
        build_file = Label("//wasm_bindgen/raze/remote:openssl-probe-0.1.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__openssl_sys__0_9_47",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/openssl-sys/openssl-sys-0.9.47.crate",
        type = "tar.gz",
        sha256 = "75bdd6dbbb4958d38e47a1d2348847ad1eb4dc205dc5d37473ae504391865acc",
        strip_prefix = "openssl-sys-0.9.47",
        build_file = Label("//wasm_bindgen/raze/remote:openssl-sys-0.9.47.BUILD"),
    )

    _new_http_archive(
        name = "raze__percent_encoding__1_0_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/percent-encoding/percent-encoding-1.0.1.crate",
        type = "tar.gz",
        sha256 = "31010dd2e1ac33d5b46a5b413495239882813e0369f8ed8a5e266f173602f831",
        strip_prefix = "percent-encoding-1.0.1",
        build_file = Label("//wasm_bindgen/raze/remote:percent-encoding-1.0.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__phf__0_7_24",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/phf/phf-0.7.24.crate",
        type = "tar.gz",
        sha256 = "b3da44b85f8e8dfaec21adae67f95d93244b2ecf6ad2a692320598dcc8e6dd18",
        strip_prefix = "phf-0.7.24",
        build_file = Label("//wasm_bindgen/raze/remote:phf-0.7.24.BUILD"),
    )

    _new_http_archive(
        name = "raze__phf_codegen__0_7_24",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/phf_codegen/phf_codegen-0.7.24.crate",
        type = "tar.gz",
        sha256 = "b03e85129e324ad4166b06b2c7491ae27fe3ec353af72e72cd1654c7225d517e",
        strip_prefix = "phf_codegen-0.7.24",
        build_file = Label("//wasm_bindgen/raze/remote:phf_codegen-0.7.24.BUILD"),
    )

    _new_http_archive(
        name = "raze__phf_generator__0_7_24",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/phf_generator/phf_generator-0.7.24.crate",
        type = "tar.gz",
        sha256 = "09364cc93c159b8b06b1f4dd8a4398984503483891b0c26b867cf431fb132662",
        strip_prefix = "phf_generator-0.7.24",
        build_file = Label("//wasm_bindgen/raze/remote:phf_generator-0.7.24.BUILD"),
    )

    _new_http_archive(
        name = "raze__phf_shared__0_7_24",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/phf_shared/phf_shared-0.7.24.crate",
        type = "tar.gz",
        sha256 = "234f71a15de2288bcb7e3b6515828d22af7ec8598ee6d24c3b526fa0a80b67a0",
        strip_prefix = "phf_shared-0.7.24",
        build_file = Label("//wasm_bindgen/raze/remote:phf_shared-0.7.24.BUILD"),
    )

    _new_http_archive(
        name = "raze__pkg_config__0_3_14",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/pkg-config/pkg-config-0.3.14.crate",
        type = "tar.gz",
        sha256 = "676e8eb2b1b4c9043511a9b7bea0915320d7e502b0a079fb03f9635a5252b18c",
        strip_prefix = "pkg-config-0.3.14",
        build_file = Label("//wasm_bindgen/raze/remote:pkg-config-0.3.14.BUILD"),
    )

    _new_http_archive(
        name = "raze__proc_macro2__0_4_30",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/proc-macro2/proc-macro2-0.4.30.crate",
        type = "tar.gz",
        sha256 = "cf3d2011ab5c909338f7887f4fc896d35932e29146c12c8d01da6b22a80ba759",
        strip_prefix = "proc-macro2-0.4.30",
        build_file = Label("//wasm_bindgen/raze/remote:proc-macro2-0.4.30.BUILD"),
    )

    _new_http_archive(
        name = "raze__quick_error__1_2_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/quick-error/quick-error-1.2.2.crate",
        type = "tar.gz",
        sha256 = "9274b940887ce9addde99c4eee6b5c44cc494b182b97e73dc8ffdcb3397fd3f0",
        strip_prefix = "quick-error-1.2.2",
        build_file = Label("//wasm_bindgen/raze/remote:quick-error-1.2.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__quote__0_6_12",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/quote/quote-0.6.12.crate",
        type = "tar.gz",
        sha256 = "faf4799c5d274f3868a4aae320a0a182cbd2baee377b378f080e16a23e9d80db",
        strip_prefix = "quote-0.6.12",
        build_file = Label("//wasm_bindgen/raze/remote:quote-0.6.12.BUILD"),
    )

    _new_http_archive(
        name = "raze__rand__0_4_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rand/rand-0.4.6.crate",
        type = "tar.gz",
        sha256 = "552840b97013b1a26992c11eac34bdd778e464601a4c2054b5f0bff7c6761293",
        strip_prefix = "rand-0.4.6",
        build_file = Label("//wasm_bindgen/raze/remote:rand-0.4.6.BUILD"),
    )

    _new_http_archive(
        name = "raze__rand__0_5_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rand/rand-0.5.6.crate",
        type = "tar.gz",
        sha256 = "c618c47cd3ebd209790115ab837de41425723956ad3ce2e6a7f09890947cacb9",
        strip_prefix = "rand-0.5.6",
        build_file = Label("//wasm_bindgen/raze/remote:rand-0.5.6.BUILD"),
    )

    _new_http_archive(
        name = "raze__rand__0_6_5",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rand/rand-0.6.5.crate",
        type = "tar.gz",
        sha256 = "6d71dacdc3c88c1fde3885a3be3fbab9f35724e6ce99467f7d9c5026132184ca",
        strip_prefix = "rand-0.6.5",
        build_file = Label("//wasm_bindgen/raze/remote:rand-0.6.5.BUILD"),
    )

    _new_http_archive(
        name = "raze__rand_chacha__0_1_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rand_chacha/rand_chacha-0.1.1.crate",
        type = "tar.gz",
        sha256 = "556d3a1ca6600bfcbab7c7c91ccb085ac7fbbcd70e008a98742e7847f4f7bcef",
        strip_prefix = "rand_chacha-0.1.1",
        build_file = Label("//wasm_bindgen/raze/remote:rand_chacha-0.1.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__rand_core__0_3_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rand_core/rand_core-0.3.1.crate",
        type = "tar.gz",
        sha256 = "7a6fdeb83b075e8266dcc8762c22776f6877a63111121f5f8c7411e5be7eed4b",
        strip_prefix = "rand_core-0.3.1",
        build_file = Label("//wasm_bindgen/raze/remote:rand_core-0.3.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__rand_core__0_4_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rand_core/rand_core-0.4.0.crate",
        type = "tar.gz",
        sha256 = "d0e7a549d590831370895ab7ba4ea0c1b6b011d106b5ff2da6eee112615e6dc0",
        strip_prefix = "rand_core-0.4.0",
        build_file = Label("//wasm_bindgen/raze/remote:rand_core-0.4.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__rand_hc__0_1_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rand_hc/rand_hc-0.1.0.crate",
        type = "tar.gz",
        sha256 = "7b40677c7be09ae76218dc623efbf7b18e34bced3f38883af07bb75630a21bc4",
        strip_prefix = "rand_hc-0.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:rand_hc-0.1.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__rand_isaac__0_1_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rand_isaac/rand_isaac-0.1.1.crate",
        type = "tar.gz",
        sha256 = "ded997c9d5f13925be2a6fd7e66bf1872597f759fd9dd93513dd7e92e5a5ee08",
        strip_prefix = "rand_isaac-0.1.1",
        build_file = Label("//wasm_bindgen/raze/remote:rand_isaac-0.1.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__rand_jitter__0_1_4",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rand_jitter/rand_jitter-0.1.4.crate",
        type = "tar.gz",
        sha256 = "1166d5c91dc97b88d1decc3285bb0a99ed84b05cfd0bc2341bdf2d43fc41e39b",
        strip_prefix = "rand_jitter-0.1.4",
        build_file = Label("//wasm_bindgen/raze/remote:rand_jitter-0.1.4.BUILD"),
    )

    _new_http_archive(
        name = "raze__rand_os__0_1_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rand_os/rand_os-0.1.3.crate",
        type = "tar.gz",
        sha256 = "7b75f676a1e053fc562eafbb47838d67c84801e38fc1ba459e8f180deabd5071",
        strip_prefix = "rand_os-0.1.3",
        build_file = Label("//wasm_bindgen/raze/remote:rand_os-0.1.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__rand_pcg__0_1_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rand_pcg/rand_pcg-0.1.2.crate",
        type = "tar.gz",
        sha256 = "abf9b09b01790cfe0364f52bf32995ea3c39f4d2dd011eac241d2914146d0b44",
        strip_prefix = "rand_pcg-0.1.2",
        build_file = Label("//wasm_bindgen/raze/remote:rand_pcg-0.1.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__rand_xorshift__0_1_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rand_xorshift/rand_xorshift-0.1.1.crate",
        type = "tar.gz",
        sha256 = "cbf7e9e623549b0e21f6e97cf8ecf247c1a8fd2e8a992ae265314300b2455d5c",
        strip_prefix = "rand_xorshift-0.1.1",
        build_file = Label("//wasm_bindgen/raze/remote:rand_xorshift-0.1.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__rayon__1_1_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rayon/rayon-1.1.0.crate",
        type = "tar.gz",
        sha256 = "a4b0186e22767d5b9738a05eab7c6ac90b15db17e5b5f9bd87976dd7d89a10a4",
        strip_prefix = "rayon-1.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:rayon-1.1.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__rayon_core__1_5_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rayon-core/rayon-core-1.5.0.crate",
        type = "tar.gz",
        sha256 = "ebbe0df8435ac0c397d467b6cad6d25543d06e8a019ef3f6af3c384597515bd2",
        strip_prefix = "rayon-core-1.5.0",
        build_file = Label("//wasm_bindgen/raze/remote:rayon-core-1.5.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__rdrand__0_4_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rdrand/rdrand-0.4.0.crate",
        type = "tar.gz",
        sha256 = "678054eb77286b51581ba43620cc911abf02758c91f93f479767aed0f90458b2",
        strip_prefix = "rdrand-0.4.0",
        build_file = Label("//wasm_bindgen/raze/remote:rdrand-0.4.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__redox_syscall__0_1_54",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/redox_syscall/redox_syscall-0.1.54.crate",
        type = "tar.gz",
        sha256 = "12229c14a0f65c4f1cb046a3b52047cdd9da1f4b30f8a39c5063c8bae515e252",
        strip_prefix = "redox_syscall-0.1.54",
        build_file = Label("//wasm_bindgen/raze/remote:redox_syscall-0.1.54.BUILD"),
    )

    _new_http_archive(
        name = "raze__redox_termios__0_1_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/redox_termios/redox_termios-0.1.1.crate",
        type = "tar.gz",
        sha256 = "7e891cfe48e9100a70a3b6eb652fef28920c117d366339687bd5576160db0f76",
        strip_prefix = "redox_termios-0.1.1",
        build_file = Label("//wasm_bindgen/raze/remote:redox_termios-0.1.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__redox_users__0_3_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/redox_users/redox_users-0.3.0.crate",
        type = "tar.gz",
        sha256 = "3fe5204c3a17e97dde73f285d49be585df59ed84b50a872baf416e73b62c3828",
        strip_prefix = "redox_users-0.3.0",
        build_file = Label("//wasm_bindgen/raze/remote:redox_users-0.3.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__regex__1_1_7",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/regex/regex-1.1.7.crate",
        type = "tar.gz",
        sha256 = "0b2f0808e7d7e4fb1cb07feb6ff2f4bc827938f24f8c2e6a3beb7370af544bdd",
        strip_prefix = "regex-1.1.7",
        build_file = Label("//wasm_bindgen/raze/remote:regex-1.1.7.BUILD"),
    )

    _new_http_archive(
        name = "raze__regex_syntax__0_6_7",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/regex-syntax/regex-syntax-0.6.7.crate",
        type = "tar.gz",
        sha256 = "9d76410686f9e3a17f06128962e0ecc5755870bb890c34820c7af7f1db2e1d48",
        strip_prefix = "regex-syntax-0.6.7",
        build_file = Label("//wasm_bindgen/raze/remote:regex-syntax-0.6.7.BUILD"),
    )

    _new_http_archive(
        name = "raze__remove_dir_all__0_5_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/remove_dir_all/remove_dir_all-0.5.2.crate",
        type = "tar.gz",
        sha256 = "4a83fa3702a688b9359eccba92d153ac33fd2e8462f9e0e3fdf155239ea7792e",
        strip_prefix = "remove_dir_all-0.5.2",
        build_file = Label("//wasm_bindgen/raze/remote:remove_dir_all-0.5.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__rouille__3_0_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rouille/rouille-3.0.0.crate",
        type = "tar.gz",
        sha256 = "112568052ec17fa26c6c11c40acbb30d3ad244bf3d6da0be181f5e7e42e5004f",
        strip_prefix = "rouille-3.0.0",
        build_file = Label("//wasm_bindgen/raze/remote:rouille-3.0.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__rustc_demangle__0_1_15",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rustc-demangle/rustc-demangle-0.1.15.crate",
        type = "tar.gz",
        sha256 = "a7f4dccf6f4891ebcc0c39f9b6eb1a83b9bf5d747cb439ec6fba4f3b977038af",
        strip_prefix = "rustc-demangle-0.1.15",
        build_file = Label("//wasm_bindgen/raze/remote:rustc-demangle-0.1.15.BUILD"),
    )

    _new_http_archive(
        name = "raze__ryu__0_2_8",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/ryu/ryu-0.2.8.crate",
        type = "tar.gz",
        sha256 = "b96a9549dc8d48f2c283938303c4b5a77aa29bfbc5b54b084fb1630408899a8f",
        strip_prefix = "ryu-0.2.8",
        build_file = Label("//wasm_bindgen/raze/remote:ryu-0.2.8.BUILD"),
    )

    _new_http_archive(
        name = "raze__safemem__0_2_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/safemem/safemem-0.2.0.crate",
        type = "tar.gz",
        sha256 = "e27a8b19b835f7aea908818e871f5cc3a5a186550c30773be987e155e8163d8f",
        strip_prefix = "safemem-0.2.0",
        build_file = Label("//wasm_bindgen/raze/remote:safemem-0.2.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__safemem__0_3_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/safemem/safemem-0.3.0.crate",
        type = "tar.gz",
        sha256 = "8dca453248a96cb0749e36ccdfe2b0b4e54a61bfef89fb97ec621eb8e0a93dd9",
        strip_prefix = "safemem-0.3.0",
        build_file = Label("//wasm_bindgen/raze/remote:safemem-0.3.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__schannel__0_1_15",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/schannel/schannel-0.1.15.crate",
        type = "tar.gz",
        sha256 = "f2f6abf258d99c3c1c5c2131d99d064e94b7b3dd5f416483057f308fea253339",
        strip_prefix = "schannel-0.1.15",
        build_file = Label("//wasm_bindgen/raze/remote:schannel-0.1.15.BUILD"),
    )

    _new_http_archive(
        name = "raze__scoped_threadpool__0_1_9",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/scoped_threadpool/scoped_threadpool-0.1.9.crate",
        type = "tar.gz",
        sha256 = "1d51f5df5af43ab3f1360b429fa5e0152ac5ce8c0bd6485cae490332e96846a8",
        strip_prefix = "scoped_threadpool-0.1.9",
        build_file = Label("//wasm_bindgen/raze/remote:scoped_threadpool-0.1.9.BUILD"),
    )

    _new_http_archive(
        name = "raze__scopeguard__0_3_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/scopeguard/scopeguard-0.3.3.crate",
        type = "tar.gz",
        sha256 = "94258f53601af11e6a49f722422f6e3425c52b06245a5cf9bc09908b174f5e27",
        strip_prefix = "scopeguard-0.3.3",
        build_file = Label("//wasm_bindgen/raze/remote:scopeguard-0.3.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__serde__1_0_94",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/serde/serde-1.0.94.crate",
        type = "tar.gz",
        sha256 = "076a696fdea89c19d3baed462576b8f6d663064414b5c793642da8dfeb99475b",
        strip_prefix = "serde-1.0.94",
        build_file = Label("//wasm_bindgen/raze/remote:serde-1.0.94.BUILD"),
    )

    _new_http_archive(
        name = "raze__serde_derive__1_0_94",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/serde_derive/serde_derive-1.0.94.crate",
        type = "tar.gz",
        sha256 = "ef45eb79d6463b22f5f9e16d283798b7c0175ba6050bc25c1a946c122727fe7b",
        strip_prefix = "serde_derive-1.0.94",
        build_file = Label("//wasm_bindgen/raze/remote:serde_derive-1.0.94.BUILD"),
    )

    _new_http_archive(
        name = "raze__serde_json__1_0_39",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/serde_json/serde_json-1.0.39.crate",
        type = "tar.gz",
        sha256 = "5a23aa71d4a4d43fdbfaac00eff68ba8a06a51759a89ac3304323e800c4dd40d",
        strip_prefix = "serde_json-1.0.39",
        build_file = Label("//wasm_bindgen/raze/remote:serde_json-1.0.39.BUILD"),
    )

    _new_http_archive(
        name = "raze__sha1__0_6_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/sha1/sha1-0.6.0.crate",
        type = "tar.gz",
        sha256 = "2579985fda508104f7587689507983eadd6a6e84dd35d6d115361f530916fa0d",
        strip_prefix = "sha1-0.6.0",
        build_file = Label("//wasm_bindgen/raze/remote:sha1-0.6.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__siphasher__0_2_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/siphasher/siphasher-0.2.3.crate",
        type = "tar.gz",
        sha256 = "0b8de496cf83d4ed58b6be86c3a275b8602f6ffe98d3024a869e124147a9a3ac",
        strip_prefix = "siphasher-0.2.3",
        build_file = Label("//wasm_bindgen/raze/remote:siphasher-0.2.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__smallvec__0_6_10",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/smallvec/smallvec-0.6.10.crate",
        type = "tar.gz",
        sha256 = "ab606a9c5e214920bb66c458cd7be8ef094f813f20fe77a54cc7dbfff220d4b7",
        strip_prefix = "smallvec-0.6.10",
        build_file = Label("//wasm_bindgen/raze/remote:smallvec-0.6.10.BUILD"),
    )

    _new_http_archive(
        name = "raze__socket2__0_3_9",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/socket2/socket2-0.3.9.crate",
        type = "tar.gz",
        sha256 = "4e626972d3593207547f14bf5fc9efa4d0e7283deb73fef1dff313dae9ab8878",
        strip_prefix = "socket2-0.3.9",
        build_file = Label("//wasm_bindgen/raze/remote:socket2-0.3.9.BUILD"),
    )

    _new_http_archive(
        name = "raze__strsim__0_9_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/strsim/strsim-0.9.2.crate",
        type = "tar.gz",
        sha256 = "032c03039aae92b350aad2e3779c352e104d919cb192ba2fabbd7b831ce4f0f6",
        strip_prefix = "strsim-0.9.2",
        build_file = Label("//wasm_bindgen/raze/remote:strsim-0.9.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__syn__0_15_43",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/syn/syn-0.15.43.crate",
        type = "tar.gz",
        sha256 = "ee06ea4b620ab59a2267c6b48be16244a3389f8bfa0986bdd15c35b890b00af3",
        strip_prefix = "syn-0.15.43",
        build_file = Label("//wasm_bindgen/raze/remote:syn-0.15.43.BUILD"),
    )

    _new_http_archive(
        name = "raze__synstructure__0_10_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/synstructure/synstructure-0.10.2.crate",
        type = "tar.gz",
        sha256 = "02353edf96d6e4dc81aea2d8490a7e9db177bf8acb0e951c24940bf866cb313f",
        strip_prefix = "synstructure-0.10.2",
        build_file = Label("//wasm_bindgen/raze/remote:synstructure-0.10.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__tempdir__0_3_7",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tempdir/tempdir-0.3.7.crate",
        type = "tar.gz",
        sha256 = "15f2b5fb00ccdf689e0149d1b1b3c03fead81c2b37735d812fa8bddbbf41b6d8",
        strip_prefix = "tempdir-0.3.7",
        build_file = Label("//wasm_bindgen/raze/remote:tempdir-0.3.7.BUILD"),
    )

    _new_http_archive(
        name = "raze__tempfile__3_0_8",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tempfile/tempfile-3.0.8.crate",
        type = "tar.gz",
        sha256 = "7dc4738f2e68ed2855de5ac9cdbe05c9216773ecde4739b2f095002ab03a13ef",
        strip_prefix = "tempfile-3.0.8",
        build_file = Label("//wasm_bindgen/raze/remote:tempfile-3.0.8.BUILD"),
    )

    _new_http_archive(
        name = "raze__term__0_5_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/term/term-0.5.2.crate",
        type = "tar.gz",
        sha256 = "edd106a334b7657c10b7c540a0106114feadeb4dc314513e97df481d5d966f42",
        strip_prefix = "term-0.5.2",
        build_file = Label("//wasm_bindgen/raze/remote:term-0.5.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__termcolor__1_0_5",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/termcolor/termcolor-1.0.5.crate",
        type = "tar.gz",
        sha256 = "96d6098003bde162e4277c70665bd87c326f5a0c3f3fbfb285787fa482d54e6e",
        strip_prefix = "termcolor-1.0.5",
        build_file = Label("//wasm_bindgen/raze/remote:termcolor-1.0.5.BUILD"),
    )

    _new_http_archive(
        name = "raze__termion__1_5_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/termion/termion-1.5.3.crate",
        type = "tar.gz",
        sha256 = "6a8fb22f7cde82c8220e5aeacb3258ed7ce996142c77cba193f203515e26c330",
        strip_prefix = "termion-1.5.3",
        build_file = Label("//wasm_bindgen/raze/remote:termion-1.5.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__thread_local__0_3_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/thread_local/thread_local-0.3.6.crate",
        type = "tar.gz",
        sha256 = "c6b53e329000edc2b34dbe8545fd20e55a333362d0a321909685a19bd28c3f1b",
        strip_prefix = "thread_local-0.3.6",
        build_file = Label("//wasm_bindgen/raze/remote:thread_local-0.3.6.BUILD"),
    )

    _new_http_archive(
        name = "raze__threadpool__1_7_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/threadpool/threadpool-1.7.1.crate",
        type = "tar.gz",
        sha256 = "e2f0c90a5f3459330ac8bc0d2f879c693bb7a2f59689c1083fc4ef83834da865",
        strip_prefix = "threadpool-1.7.1",
        build_file = Label("//wasm_bindgen/raze/remote:threadpool-1.7.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__time__0_1_42",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/time/time-0.1.42.crate",
        type = "tar.gz",
        sha256 = "db8dcfca086c1143c9270ac42a2bbd8a7ee477b78ac8e45b19abfb0cbede4b6f",
        strip_prefix = "time-0.1.42",
        build_file = Label("//wasm_bindgen/raze/remote:time-0.1.42.BUILD"),
    )

    _new_http_archive(
        name = "raze__tiny_http__0_6_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tiny_http/tiny_http-0.6.2.crate",
        type = "tar.gz",
        sha256 = "1661fa0a44c95d01604bd05c66732a446c657efb62b5164a7a083a3b552b4951",
        strip_prefix = "tiny_http-0.6.2",
        build_file = Label("//wasm_bindgen/raze/remote:tiny_http-0.6.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__twoway__0_1_8",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/twoway/twoway-0.1.8.crate",
        type = "tar.gz",
        sha256 = "59b11b2b5241ba34be09c3cc85a36e56e48f9888862e19cedf23336d35316ed1",
        strip_prefix = "twoway-0.1.8",
        build_file = Label("//wasm_bindgen/raze/remote:twoway-0.1.8.BUILD"),
    )

    _new_http_archive(
        name = "raze__ucd_util__0_1_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/ucd-util/ucd-util-0.1.3.crate",
        type = "tar.gz",
        sha256 = "535c204ee4d8434478593480b8f86ab45ec9aae0e83c568ca81abf0fd0e88f86",
        strip_prefix = "ucd-util-0.1.3",
        build_file = Label("//wasm_bindgen/raze/remote:ucd-util-0.1.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__unicase__1_4_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/unicase/unicase-1.4.2.crate",
        type = "tar.gz",
        sha256 = "7f4765f83163b74f957c797ad9253caf97f103fb064d3999aea9568d09fc8a33",
        strip_prefix = "unicase-1.4.2",
        build_file = Label("//wasm_bindgen/raze/remote:unicase-1.4.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__unicode_bidi__0_3_4",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/unicode-bidi/unicode-bidi-0.3.4.crate",
        type = "tar.gz",
        sha256 = "49f2bd0c6468a8230e1db229cff8029217cf623c767ea5d60bfbd42729ea54d5",
        strip_prefix = "unicode-bidi-0.3.4",
        build_file = Label("//wasm_bindgen/raze/remote:unicode-bidi-0.3.4.BUILD"),
    )

    _new_http_archive(
        name = "raze__unicode_normalization__0_1_8",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/unicode-normalization/unicode-normalization-0.1.8.crate",
        type = "tar.gz",
        sha256 = "141339a08b982d942be2ca06ff8b076563cbe223d1befd5450716790d44e2426",
        strip_prefix = "unicode-normalization-0.1.8",
        build_file = Label("//wasm_bindgen/raze/remote:unicode-normalization-0.1.8.BUILD"),
    )

    _new_http_archive(
        name = "raze__unicode_segmentation__1_3_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/unicode-segmentation/unicode-segmentation-1.3.0.crate",
        type = "tar.gz",
        sha256 = "1967f4cdfc355b37fd76d2a954fb2ed3871034eb4f26d60537d88795cfc332a9",
        strip_prefix = "unicode-segmentation-1.3.0",
        build_file = Label("//wasm_bindgen/raze/remote:unicode-segmentation-1.3.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__unicode_xid__0_1_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/unicode-xid/unicode-xid-0.1.0.crate",
        type = "tar.gz",
        sha256 = "fc72304796d0818e357ead4e000d19c9c174ab23dc11093ac919054d20a6a7fc",
        strip_prefix = "unicode-xid-0.1.0",
        build_file = Label("//wasm_bindgen/raze/remote:unicode-xid-0.1.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__url__1_7_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/url/url-1.7.2.crate",
        type = "tar.gz",
        sha256 = "dd4e7c0d531266369519a4aa4f399d748bd37043b00bde1e4ff1f60a120b355a",
        strip_prefix = "url-1.7.2",
        build_file = Label("//wasm_bindgen/raze/remote:url-1.7.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__utf8_ranges__1_0_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/utf8-ranges/utf8-ranges-1.0.3.crate",
        type = "tar.gz",
        sha256 = "9d50aa7650df78abf942826607c62468ce18d9019673d4a2ebe1865dbb96ffde",
        strip_prefix = "utf8-ranges-1.0.3",
        build_file = Label("//wasm_bindgen/raze/remote:utf8-ranges-1.0.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__vcpkg__0_2_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/vcpkg/vcpkg-0.2.6.crate",
        type = "tar.gz",
        sha256 = "def296d3eb3b12371b2c7d0e83bfe1403e4db2d7a0bba324a12b21c4ee13143d",
        strip_prefix = "vcpkg-0.2.6",
        build_file = Label("//wasm_bindgen/raze/remote:vcpkg-0.2.6.BUILD"),
    )

    _new_http_archive(
        name = "raze__version_check__0_1_5",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/version_check/version_check-0.1.5.crate",
        type = "tar.gz",
        sha256 = "914b1a6776c4c929a602fafd8bc742e06365d4bcbe48c30f9cca5824f70dc9dd",
        strip_prefix = "version_check-0.1.5",
        build_file = Label("//wasm_bindgen/raze/remote:version_check-0.1.5.BUILD"),
    )

    _new_http_archive(
        name = "raze__walrus__0_8_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/walrus/walrus-0.8.0.crate",
        type = "tar.gz",
        sha256 = "9b751c638c5c86d92af28a3a68ce879b719c7e1cad75c66a3377ce386b9d705f",
        strip_prefix = "walrus-0.8.0",
        build_file = Label("//wasm_bindgen/raze/remote:walrus-0.8.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__walrus_macro__0_8_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/walrus-macro/walrus-macro-0.8.0.crate",
        type = "tar.gz",
        sha256 = "30dcc194dbffb8025ca1b42a92f8c33ac28b1025cd771f0d884f89508b5fb094",
        strip_prefix = "walrus-macro-0.8.0",
        build_file = Label("//wasm_bindgen/raze/remote:walrus-macro-0.8.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__wasm_bindgen__0_2_48",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/wasm-bindgen/wasm-bindgen-0.2.48.crate",
        type = "tar.gz",
        sha256 = "4de97fa1806bb1a99904216f6ac5e0c050dc4f8c676dc98775047c38e5c01b55",
        strip_prefix = "wasm-bindgen-0.2.48",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-0.2.48.BUILD"),
    )

    _new_http_archive(
        name = "raze__wasm_bindgen_anyref_xform__0_2_48",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/wasm-bindgen-anyref-xform/wasm-bindgen-anyref-xform-0.2.48.crate",
        type = "tar.gz",
        sha256 = "96b9065758e62fd7a445c1b37f427edc69771c400f13771ff0653e49fd39a8e7",
        strip_prefix = "wasm-bindgen-anyref-xform-0.2.48",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-anyref-xform-0.2.48.BUILD"),
    )

    _new_http_archive(
        name = "raze__wasm_bindgen_backend__0_2_48",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/wasm-bindgen-backend/wasm-bindgen-backend-0.2.48.crate",
        type = "tar.gz",
        sha256 = "5d82c170ef9f5b2c63ad4460dfcee93f3ec04a9a36a4cc20bc973c39e59ab8e3",
        strip_prefix = "wasm-bindgen-backend-0.2.48",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-backend-0.2.48.BUILD"),
    )

    _new_http_archive(
        name = "raze__wasm_bindgen_cli__0_2_48",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/wasm-bindgen-cli/wasm-bindgen-cli-0.2.48.crate",
        type = "tar.gz",
        sha256 = "ceb1786f6098700f9e2b33ad640392920c84cee6e9bdd8251e44e35fac472638",
        strip_prefix = "wasm-bindgen-cli-0.2.48",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-cli-0.2.48.BUILD"),
    )

    _new_http_archive(
        name = "raze__wasm_bindgen_cli_support__0_2_48",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/wasm-bindgen-cli-support/wasm-bindgen-cli-support-0.2.48.crate",
        type = "tar.gz",
        sha256 = "66aae0d39c155c9bf27b3c21113120d4c47bb0193234f15b98448b7b119c87be",
        strip_prefix = "wasm-bindgen-cli-support-0.2.48",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-cli-support-0.2.48.BUILD"),
    )

    _new_http_archive(
        name = "raze__wasm_bindgen_macro__0_2_48",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/wasm-bindgen-macro/wasm-bindgen-macro-0.2.48.crate",
        type = "tar.gz",
        sha256 = "f07d50f74bf7a738304f6b8157f4a581e1512cd9e9cdb5baad8c31bbe8ffd81d",
        strip_prefix = "wasm-bindgen-macro-0.2.48",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-macro-0.2.48.BUILD"),
    )

    _new_http_archive(
        name = "raze__wasm_bindgen_macro_support__0_2_48",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/wasm-bindgen-macro-support/wasm-bindgen-macro-support-0.2.48.crate",
        type = "tar.gz",
        sha256 = "95cf8fe77e45ba5f91bc8f3da0c3aa5d464b3d8ed85d84f4d4c7cc106436b1d7",
        strip_prefix = "wasm-bindgen-macro-support-0.2.48",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-macro-support-0.2.48.BUILD"),
    )

    _new_http_archive(
        name = "raze__wasm_bindgen_shared__0_2_48",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/wasm-bindgen-shared/wasm-bindgen-shared-0.2.48.crate",
        type = "tar.gz",
        sha256 = "d9c2d4d4756b2e46d3a5422e06277d02e4d3e1d62d138b76a4c681e925743623",
        strip_prefix = "wasm-bindgen-shared-0.2.48",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-shared-0.2.48.BUILD"),
    )

    _new_http_archive(
        name = "raze__wasm_bindgen_threads_xform__0_2_48",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/wasm-bindgen-threads-xform/wasm-bindgen-threads-xform-0.2.48.crate",
        type = "tar.gz",
        sha256 = "61de14e4283261b9ce99b15bd3fb52a4c8f56a3efef4b46cf2fa11c2a180be10",
        strip_prefix = "wasm-bindgen-threads-xform-0.2.48",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-threads-xform-0.2.48.BUILD"),
    )

    _new_http_archive(
        name = "raze__wasm_bindgen_wasm_interpreter__0_2_48",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/wasm-bindgen-wasm-interpreter/wasm-bindgen-wasm-interpreter-0.2.48.crate",
        type = "tar.gz",
        sha256 = "7cfc73f030ca101c85e75f5c5e2db061e762ff600edd77693c5c8581b90bdfe6",
        strip_prefix = "wasm-bindgen-wasm-interpreter-0.2.48",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-bindgen-wasm-interpreter-0.2.48.BUILD"),
    )

    _new_http_archive(
        name = "raze__wasm_webidl_bindings__0_1_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/wasm-webidl-bindings/wasm-webidl-bindings-0.1.2.crate",
        type = "tar.gz",
        sha256 = "216c964db43e07890435d9b152e59f0f520787ebed2c0666609fe8d933c3b749",
        strip_prefix = "wasm-webidl-bindings-0.1.2",
        build_file = Label("//wasm_bindgen/raze/remote:wasm-webidl-bindings-0.1.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__wasmparser__0_30_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/wasmparser/wasmparser-0.30.0.crate",
        type = "tar.gz",
        sha256 = "566a9eefa2267a1a32af59807326e84191cdff41c3fc2efda0a790d821615b31",
        strip_prefix = "wasmparser-0.30.0",
        build_file = Label("//wasm_bindgen/raze/remote:wasmparser-0.30.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__winapi__0_2_8",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi/winapi-0.2.8.crate",
        type = "tar.gz",
        sha256 = "167dc9d6949a9b857f3451275e911c3f44255842c1f7a76f33c55103a909087a",
        strip_prefix = "winapi-0.2.8",
        build_file = Label("//wasm_bindgen/raze/remote:winapi-0.2.8.BUILD"),
    )

    _new_http_archive(
        name = "raze__winapi__0_3_7",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi/winapi-0.3.7.crate",
        type = "tar.gz",
        sha256 = "f10e386af2b13e47c89e7236a7a14a086791a2b88ebad6df9bf42040195cf770",
        strip_prefix = "winapi-0.3.7",
        build_file = Label("//wasm_bindgen/raze/remote:winapi-0.3.7.BUILD"),
    )

    _new_http_archive(
        name = "raze__winapi_build__0_1_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi-build/winapi-build-0.1.1.crate",
        type = "tar.gz",
        sha256 = "2d315eee3b34aca4797b2da6b13ed88266e6d612562a0c46390af8299fc699bc",
        strip_prefix = "winapi-build-0.1.1",
        build_file = Label("//wasm_bindgen/raze/remote:winapi-build-0.1.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__winapi_i686_pc_windows_gnu__0_4_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi-i686-pc-windows-gnu/winapi-i686-pc-windows-gnu-0.4.0.crate",
        type = "tar.gz",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("//wasm_bindgen/raze/remote:winapi-i686-pc-windows-gnu-0.4.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__winapi_util__0_1_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi-util/winapi-util-0.1.2.crate",
        type = "tar.gz",
        sha256 = "7168bab6e1daee33b4557efd0e95d5ca70a03706d39fa5f3fe7a236f584b03c9",
        strip_prefix = "winapi-util-0.1.2",
        build_file = Label("//wasm_bindgen/raze/remote:winapi-util-0.1.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__winapi_x86_64_pc_windows_gnu__0_4_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi-x86_64-pc-windows-gnu/winapi-x86_64-pc-windows-gnu-0.4.0.crate",
        type = "tar.gz",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("//wasm_bindgen/raze/remote:winapi-x86_64-pc-windows-gnu-0.4.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__wincolor__1_0_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/wincolor/wincolor-1.0.1.crate",
        type = "tar.gz",
        sha256 = "561ed901ae465d6185fa7864d63fbd5720d0ef718366c9a4dc83cf6170d7e9ba",
        strip_prefix = "wincolor-1.0.1",
        build_file = Label("//wasm_bindgen/raze/remote:wincolor-1.0.1.BUILD"),
    )
