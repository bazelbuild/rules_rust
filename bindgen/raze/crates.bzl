"""
@generated
cargo-raze generated Bazel file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

def rules_rust_bindgen_fetch_remote_crates():
    """This function defines a collection of repos and should be called in a WORKSPACE file"""
    maybe(
        http_archive,
        name = "rules_rust_bindgen__aho_corasick__0_7_18",
        url = "https://crates.io/api/v1/crates/aho-corasick/0.7.18/download",
        type = "tar.gz",
        sha256 = "1e37cfd5e7657ada45f742d6e99ca5788580b5c529dc78faf11ece6dc702656f",
        strip_prefix = "aho-corasick-0.7.18",
        build_file = Label("//bindgen/raze/remote:BUILD.aho-corasick-0.7.18.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__ansi_term__0_11_0",
        url = "https://crates.io/api/v1/crates/ansi_term/0.11.0/download",
        type = "tar.gz",
        sha256 = "ee49baf6cb617b853aa8d93bf420db2383fab46d314482ca2803b40d5fde979b",
        strip_prefix = "ansi_term-0.11.0",
        build_file = Label("//bindgen/raze/remote:BUILD.ansi_term-0.11.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__atty__0_2_14",
        url = "https://crates.io/api/v1/crates/atty/0.2.14/download",
        type = "tar.gz",
        sha256 = "d9b39be18770d11421cdb1b9947a45dd3f37e93092cbf377614828a319d5fee8",
        strip_prefix = "atty-0.2.14",
        build_file = Label("//bindgen/raze/remote:BUILD.atty-0.2.14.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__bindgen__0_58_1",
        url = "https://crates.io/api/v1/crates/bindgen/0.58.1/download",
        type = "tar.gz",
        sha256 = "0f8523b410d7187a43085e7e064416ea32ded16bd0a4e6fc025e21616d01258f",
        strip_prefix = "bindgen-0.58.1",
        build_file = Label("//bindgen/raze/remote:BUILD.bindgen-0.58.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__bitflags__1_2_1",
        url = "https://crates.io/api/v1/crates/bitflags/1.2.1/download",
        type = "tar.gz",
        sha256 = "cf1de2fe8c75bc145a2f577add951f8134889b4795d47466a54a5c846d691693",
        strip_prefix = "bitflags-1.2.1",
        build_file = Label("//bindgen/raze/remote:BUILD.bitflags-1.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__cexpr__0_4_0",
        url = "https://crates.io/api/v1/crates/cexpr/0.4.0/download",
        type = "tar.gz",
        sha256 = "f4aedb84272dbe89af497cf81375129abda4fc0a9e7c5d317498c15cc30c0d27",
        strip_prefix = "cexpr-0.4.0",
        build_file = Label("//bindgen/raze/remote:BUILD.cexpr-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__cfg_if__0_1_10",
        url = "https://crates.io/api/v1/crates/cfg-if/0.1.10/download",
        type = "tar.gz",
        sha256 = "4785bdd1c96b2a846b2bd7cc02e86b6b3dbf14e7e53446c4f54c92a361040822",
        strip_prefix = "cfg-if-0.1.10",
        build_file = Label("//bindgen/raze/remote:BUILD.cfg-if-0.1.10.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__cfg_if__1_0_0",
        url = "https://crates.io/api/v1/crates/cfg-if/1.0.0/download",
        type = "tar.gz",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("//bindgen/raze/remote:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__clang_sys__1_2_0",
        url = "https://crates.io/api/v1/crates/clang-sys/1.2.0/download",
        type = "tar.gz",
        sha256 = "853eda514c284c2287f4bf20ae614f8781f40a81d32ecda6e91449304dfe077c",
        strip_prefix = "clang-sys-1.2.0",
        build_file = Label("//bindgen/raze/remote:BUILD.clang-sys-1.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__clap__2_33_3",
        url = "https://crates.io/api/v1/crates/clap/2.33.3/download",
        type = "tar.gz",
        sha256 = "37e58ac78573c40708d45522f0d80fa2f01cc4f9b4e2bf749807255454312002",
        strip_prefix = "clap-2.33.3",
        build_file = Label("//bindgen/raze/remote:BUILD.clap-2.33.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__env_logger__0_8_3",
        url = "https://crates.io/api/v1/crates/env_logger/0.8.3/download",
        type = "tar.gz",
        sha256 = "17392a012ea30ef05a610aa97dfb49496e71c9f676b27879922ea5bdf60d9d3f",
        strip_prefix = "env_logger-0.8.3",
        build_file = Label("//bindgen/raze/remote:BUILD.env_logger-0.8.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__glob__0_3_0",
        url = "https://crates.io/api/v1/crates/glob/0.3.0/download",
        type = "tar.gz",
        sha256 = "9b919933a397b79c37e33b77bb2aa3dc8eb6e165ad809e58ff75bc7db2e34574",
        strip_prefix = "glob-0.3.0",
        build_file = Label("//bindgen/raze/remote:BUILD.glob-0.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__hermit_abi__0_1_18",
        url = "https://crates.io/api/v1/crates/hermit-abi/0.1.18/download",
        type = "tar.gz",
        sha256 = "322f4de77956e22ed0e5032c359a0f1273f1f7f0d79bfa3b8ffbc730d7fbcc5c",
        strip_prefix = "hermit-abi-0.1.18",
        build_file = Label("//bindgen/raze/remote:BUILD.hermit-abi-0.1.18.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__humantime__2_1_0",
        url = "https://crates.io/api/v1/crates/humantime/2.1.0/download",
        type = "tar.gz",
        sha256 = "9a3a5bfb195931eeb336b2a7b4d761daec841b97f947d34394601737a7bba5e4",
        strip_prefix = "humantime-2.1.0",
        build_file = Label("//bindgen/raze/remote:BUILD.humantime-2.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__lazy_static__1_4_0",
        url = "https://crates.io/api/v1/crates/lazy_static/1.4.0/download",
        type = "tar.gz",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        strip_prefix = "lazy_static-1.4.0",
        build_file = Label("//bindgen/raze/remote:BUILD.lazy_static-1.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__lazycell__1_3_0",
        url = "https://crates.io/api/v1/crates/lazycell/1.3.0/download",
        type = "tar.gz",
        sha256 = "830d08ce1d1d941e6b30645f1a0eb5643013d835ce3779a5fc208261dbe10f55",
        strip_prefix = "lazycell-1.3.0",
        build_file = Label("//bindgen/raze/remote:BUILD.lazycell-1.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__libc__0_2_94",
        url = "https://crates.io/api/v1/crates/libc/0.2.94/download",
        type = "tar.gz",
        sha256 = "18794a8ad5b29321f790b55d93dfba91e125cb1a9edbd4f8e3150acc771c1a5e",
        strip_prefix = "libc-0.2.94",
        build_file = Label("//bindgen/raze/remote:BUILD.libc-0.2.94.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__libloading__0_6_3",
        url = "https://crates.io/api/v1/crates/libloading/0.6.3/download",
        type = "tar.gz",
        sha256 = "2443d8f0478b16759158b2f66d525991a05491138bc05814ef52a250148ef4f9",
        strip_prefix = "libloading-0.6.3",
        build_file = Label("//bindgen/raze/remote:BUILD.libloading-0.6.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__libloading__0_7_0",
        url = "https://crates.io/api/v1/crates/libloading/0.7.0/download",
        type = "tar.gz",
        sha256 = "6f84d96438c15fcd6c3f244c8fce01d1e2b9c6b5623e9c711dc9286d8fc92d6a",
        strip_prefix = "libloading-0.7.0",
        build_file = Label("//bindgen/raze/remote:BUILD.libloading-0.7.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__log__0_4_14",
        url = "https://crates.io/api/v1/crates/log/0.4.14/download",
        type = "tar.gz",
        sha256 = "51b9bbe6c47d51fc3e1a9b945965946b4c44142ab8792c50835a980d362c2710",
        strip_prefix = "log-0.4.14",
        build_file = Label("//bindgen/raze/remote:BUILD.log-0.4.14.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__memchr__2_4_0",
        url = "https://crates.io/api/v1/crates/memchr/2.4.0/download",
        type = "tar.gz",
        sha256 = "b16bd47d9e329435e309c58469fe0791c2d0d1ba96ec0954152a5ae2b04387dc",
        strip_prefix = "memchr-2.4.0",
        build_file = Label("//bindgen/raze/remote:BUILD.memchr-2.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__nom__5_1_2",
        url = "https://crates.io/api/v1/crates/nom/5.1.2/download",
        type = "tar.gz",
        sha256 = "ffb4262d26ed83a1c0a33a38fe2bb15797329c85770da05e6b828ddb782627af",
        strip_prefix = "nom-5.1.2",
        build_file = Label("//bindgen/raze/remote:BUILD.nom-5.1.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__peeking_take_while__0_1_2",
        url = "https://crates.io/api/v1/crates/peeking_take_while/0.1.2/download",
        type = "tar.gz",
        sha256 = "19b17cddbe7ec3f8bc800887bab5e717348c95ea2ca0b1bf0837fb964dc67099",
        strip_prefix = "peeking_take_while-0.1.2",
        build_file = Label("//bindgen/raze/remote:BUILD.peeking_take_while-0.1.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__proc_macro2__1_0_26",
        url = "https://crates.io/api/v1/crates/proc-macro2/1.0.26/download",
        type = "tar.gz",
        sha256 = "a152013215dca273577e18d2bf00fa862b89b24169fb78c4c95aeb07992c9cec",
        strip_prefix = "proc-macro2-1.0.26",
        build_file = Label("//bindgen/raze/remote:BUILD.proc-macro2-1.0.26.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__quote__1_0_9",
        url = "https://crates.io/api/v1/crates/quote/1.0.9/download",
        type = "tar.gz",
        sha256 = "c3d0b9745dc2debf507c8422de05d7226cc1f0644216dfdfead988f9b1ab32a7",
        strip_prefix = "quote-1.0.9",
        build_file = Label("//bindgen/raze/remote:BUILD.quote-1.0.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__regex__1_5_4",
        url = "https://crates.io/api/v1/crates/regex/1.5.4/download",
        type = "tar.gz",
        sha256 = "d07a8629359eb56f1e2fb1652bb04212c072a87ba68546a04065d525673ac461",
        strip_prefix = "regex-1.5.4",
        build_file = Label("//bindgen/raze/remote:BUILD.regex-1.5.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__regex_syntax__0_6_25",
        url = "https://crates.io/api/v1/crates/regex-syntax/0.6.25/download",
        type = "tar.gz",
        sha256 = "f497285884f3fcff424ffc933e56d7cbca511def0c9831a7f9b5f6153e3cc89b",
        strip_prefix = "regex-syntax-0.6.25",
        build_file = Label("//bindgen/raze/remote:BUILD.regex-syntax-0.6.25.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__rustc_hash__1_1_0",
        url = "https://crates.io/api/v1/crates/rustc-hash/1.1.0/download",
        type = "tar.gz",
        sha256 = "08d43f7aa6b08d49f382cde6a7982047c3426db949b1424bc4b7ec9ae12c6ce2",
        strip_prefix = "rustc-hash-1.1.0",
        build_file = Label("//bindgen/raze/remote:BUILD.rustc-hash-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__shlex__1_0_0",
        url = "https://crates.io/api/v1/crates/shlex/1.0.0/download",
        type = "tar.gz",
        sha256 = "42a568c8f2cd051a4d283bd6eb0343ac214c1b0f1ac19f93e1175b2dee38c73d",
        strip_prefix = "shlex-1.0.0",
        build_file = Label("//bindgen/raze/remote:BUILD.shlex-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__strsim__0_8_0",
        url = "https://crates.io/api/v1/crates/strsim/0.8.0/download",
        type = "tar.gz",
        sha256 = "8ea5119cdb4c55b55d432abb513a0429384878c15dde60cc77b1c99de1a95a6a",
        strip_prefix = "strsim-0.8.0",
        build_file = Label("//bindgen/raze/remote:BUILD.strsim-0.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__termcolor__1_1_2",
        url = "https://crates.io/api/v1/crates/termcolor/1.1.2/download",
        type = "tar.gz",
        sha256 = "2dfed899f0eb03f32ee8c6a0aabdb8a7949659e3466561fc0adf54e26d88c5f4",
        strip_prefix = "termcolor-1.1.2",
        build_file = Label("//bindgen/raze/remote:BUILD.termcolor-1.1.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__textwrap__0_11_0",
        url = "https://crates.io/api/v1/crates/textwrap/0.11.0/download",
        type = "tar.gz",
        sha256 = "d326610f408c7a4eb6f51c37c330e496b08506c9457c9d34287ecc38809fb060",
        strip_prefix = "textwrap-0.11.0",
        build_file = Label("//bindgen/raze/remote:BUILD.textwrap-0.11.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__unicode_width__0_1_8",
        url = "https://crates.io/api/v1/crates/unicode-width/0.1.8/download",
        type = "tar.gz",
        sha256 = "9337591893a19b88d8d87f2cec1e73fad5cdfd10e5a6f349f498ad6ea2ffb1e3",
        strip_prefix = "unicode-width-0.1.8",
        build_file = Label("//bindgen/raze/remote:BUILD.unicode-width-0.1.8.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__unicode_xid__0_2_2",
        url = "https://crates.io/api/v1/crates/unicode-xid/0.2.2/download",
        type = "tar.gz",
        sha256 = "8ccb82d61f80a663efe1f787a51b16b5a51e3314d6ac365b08639f52387b33f3",
        strip_prefix = "unicode-xid-0.2.2",
        build_file = Label("//bindgen/raze/remote:BUILD.unicode-xid-0.2.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__vec_map__0_8_2",
        url = "https://crates.io/api/v1/crates/vec_map/0.8.2/download",
        type = "tar.gz",
        sha256 = "f1bddf1187be692e79c5ffeab891132dfb0f236ed36a43c7ed39f1165ee20191",
        strip_prefix = "vec_map-0.8.2",
        build_file = Label("//bindgen/raze/remote:BUILD.vec_map-0.8.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__version_check__0_9_3",
        url = "https://crates.io/api/v1/crates/version_check/0.9.3/download",
        type = "tar.gz",
        sha256 = "5fecdca9a5291cc2b8dcf7dc02453fee791a280f3743cb0905f8822ae463b3fe",
        strip_prefix = "version_check-0.9.3",
        build_file = Label("//bindgen/raze/remote:BUILD.version_check-0.9.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__which__3_1_1",
        url = "https://crates.io/api/v1/crates/which/3.1.1/download",
        type = "tar.gz",
        sha256 = "d011071ae14a2f6671d0b74080ae0cd8ebf3a6f8c9589a2cd45f23126fe29724",
        strip_prefix = "which-3.1.1",
        build_file = Label("//bindgen/raze/remote:BUILD.which-3.1.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__winapi__0_3_9",
        url = "https://crates.io/api/v1/crates/winapi/0.3.9/download",
        type = "tar.gz",
        sha256 = "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419",
        strip_prefix = "winapi-0.3.9",
        build_file = Label("//bindgen/raze/remote:BUILD.winapi-0.3.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__winapi_i686_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-i686-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("//bindgen/raze/remote:BUILD.winapi-i686-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__winapi_util__0_1_5",
        url = "https://crates.io/api/v1/crates/winapi-util/0.1.5/download",
        type = "tar.gz",
        sha256 = "70ec6ce85bb158151cae5e5c87f95a8e97d2c0c4b001223f33a334e3ce5de178",
        strip_prefix = "winapi-util-0.1.5",
        build_file = Label("//bindgen/raze/remote:BUILD.winapi-util-0.1.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__winapi_x86_64_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-x86_64-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("//bindgen/raze/remote:BUILD.winapi-x86_64-pc-windows-gnu-0.4.0.bazel"),
    )
