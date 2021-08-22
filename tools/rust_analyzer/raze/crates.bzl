"""
@generated
cargo-raze generated Bazel file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

def rules_rust_tools_rust_analyzer_fetch_remote_crates():
    """This function defines a collection of repos and should be called in a WORKSPACE file"""
    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__aho_corasick__0_7_18",
        url = "https://crates.io/api/v1/crates/aho-corasick/0.7.18/download",
        type = "tar.gz",
        sha256 = "1e37cfd5e7657ada45f742d6e99ca5788580b5c529dc78faf11ece6dc702656f",
        strip_prefix = "aho-corasick-0.7.18",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.aho-corasick-0.7.18.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__ansi_term__0_11_0",
        url = "https://crates.io/api/v1/crates/ansi_term/0.11.0/download",
        type = "tar.gz",
        sha256 = "ee49baf6cb617b853aa8d93bf420db2383fab46d314482ca2803b40d5fde979b",
        strip_prefix = "ansi_term-0.11.0",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.ansi_term-0.11.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__anyhow__1_0_43",
        url = "https://crates.io/api/v1/crates/anyhow/1.0.43/download",
        type = "tar.gz",
        sha256 = "28ae2b3dec75a406790005a200b1bd89785afc02517a00ca99ecfe093ee9e6cf",
        strip_prefix = "anyhow-1.0.43",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.anyhow-1.0.43.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__atty__0_2_14",
        url = "https://crates.io/api/v1/crates/atty/0.2.14/download",
        type = "tar.gz",
        sha256 = "d9b39be18770d11421cdb1b9947a45dd3f37e93092cbf377614828a319d5fee8",
        strip_prefix = "atty-0.2.14",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.atty-0.2.14.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__bitflags__1_3_2",
        url = "https://crates.io/api/v1/crates/bitflags/1.3.2/download",
        type = "tar.gz",
        sha256 = "bef38d45163c2f1dde094a7dfd33ccf595c92905c8f8f4fdc18d06fb1037718a",
        strip_prefix = "bitflags-1.3.2",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.bitflags-1.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__cfg_if__1_0_0",
        url = "https://crates.io/api/v1/crates/cfg-if/1.0.0/download",
        type = "tar.gz",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__clap__2_33_3",
        url = "https://crates.io/api/v1/crates/clap/2.33.3/download",
        type = "tar.gz",
        sha256 = "37e58ac78573c40708d45522f0d80fa2f01cc4f9b4e2bf749807255454312002",
        strip_prefix = "clap-2.33.3",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.clap-2.33.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__env_logger__0_9_0",
        url = "https://crates.io/api/v1/crates/env_logger/0.9.0/download",
        type = "tar.gz",
        sha256 = "0b2cf0344971ee6c64c31be0d530793fba457d322dfec2810c453d0ef228f9c3",
        strip_prefix = "env_logger-0.9.0",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.env_logger-0.9.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__heck__0_3_3",
        url = "https://crates.io/api/v1/crates/heck/0.3.3/download",
        type = "tar.gz",
        sha256 = "6d621efb26863f0e9924c6ac577e8275e5e6b77455db64ffa6c65c904e9e132c",
        strip_prefix = "heck-0.3.3",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.heck-0.3.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__hermit_abi__0_1_19",
        url = "https://crates.io/api/v1/crates/hermit-abi/0.1.19/download",
        type = "tar.gz",
        sha256 = "62b467343b94ba476dcb2500d242dadbb39557df889310ac77c5d99100aaac33",
        strip_prefix = "hermit-abi-0.1.19",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.hermit-abi-0.1.19.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__humantime__2_1_0",
        url = "https://crates.io/api/v1/crates/humantime/2.1.0/download",
        type = "tar.gz",
        sha256 = "9a3a5bfb195931eeb336b2a7b4d761daec841b97f947d34394601737a7bba5e4",
        strip_prefix = "humantime-2.1.0",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.humantime-2.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__itoa__0_4_8",
        url = "https://crates.io/api/v1/crates/itoa/0.4.8/download",
        type = "tar.gz",
        sha256 = "b71991ff56294aa922b450139ee08b3bfc70982c6b2c7562771375cf73542dd4",
        strip_prefix = "itoa-0.4.8",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.itoa-0.4.8.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__lazy_static__1_4_0",
        url = "https://crates.io/api/v1/crates/lazy_static/1.4.0/download",
        type = "tar.gz",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        strip_prefix = "lazy_static-1.4.0",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.lazy_static-1.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__libc__0_2_100",
        url = "https://crates.io/api/v1/crates/libc/0.2.100/download",
        type = "tar.gz",
        sha256 = "a1fa8cddc8fbbee11227ef194b5317ed014b8acbf15139bd716a18ad3fe99ec5",
        strip_prefix = "libc-0.2.100",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.libc-0.2.100.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__log__0_4_14",
        url = "https://crates.io/api/v1/crates/log/0.4.14/download",
        type = "tar.gz",
        sha256 = "51b9bbe6c47d51fc3e1a9b945965946b4c44142ab8792c50835a980d362c2710",
        strip_prefix = "log-0.4.14",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.log-0.4.14.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__memchr__2_4_1",
        url = "https://crates.io/api/v1/crates/memchr/2.4.1/download",
        type = "tar.gz",
        sha256 = "308cc39be01b73d0d18f82a0e7b2a3df85245f84af96fdddc5d202d27e47b86a",
        strip_prefix = "memchr-2.4.1",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.memchr-2.4.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__proc_macro_error__1_0_4",
        url = "https://crates.io/api/v1/crates/proc-macro-error/1.0.4/download",
        type = "tar.gz",
        sha256 = "da25490ff9892aab3fcf7c36f08cfb902dd3e71ca0f9f9517bea02a73a5ce38c",
        strip_prefix = "proc-macro-error-1.0.4",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.proc-macro-error-1.0.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__proc_macro_error_attr__1_0_4",
        url = "https://crates.io/api/v1/crates/proc-macro-error-attr/1.0.4/download",
        type = "tar.gz",
        sha256 = "a1be40180e52ecc98ad80b184934baf3d0d29f979574e439af5a55274b35f869",
        strip_prefix = "proc-macro-error-attr-1.0.4",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.proc-macro-error-attr-1.0.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__proc_macro2__1_0_28",
        url = "https://crates.io/api/v1/crates/proc-macro2/1.0.28/download",
        type = "tar.gz",
        sha256 = "5c7ed8b8c7b886ea3ed7dde405212185f423ab44682667c8c6dd14aa1d9f6612",
        strip_prefix = "proc-macro2-1.0.28",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.proc-macro2-1.0.28.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__quote__1_0_9",
        url = "https://crates.io/api/v1/crates/quote/1.0.9/download",
        type = "tar.gz",
        sha256 = "c3d0b9745dc2debf507c8422de05d7226cc1f0644216dfdfead988f9b1ab32a7",
        strip_prefix = "quote-1.0.9",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.quote-1.0.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__regex__1_5_4",
        url = "https://crates.io/api/v1/crates/regex/1.5.4/download",
        type = "tar.gz",
        sha256 = "d07a8629359eb56f1e2fb1652bb04212c072a87ba68546a04065d525673ac461",
        strip_prefix = "regex-1.5.4",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.regex-1.5.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__regex_syntax__0_6_25",
        url = "https://crates.io/api/v1/crates/regex-syntax/0.6.25/download",
        type = "tar.gz",
        sha256 = "f497285884f3fcff424ffc933e56d7cbca511def0c9831a7f9b5f6153e3cc89b",
        strip_prefix = "regex-syntax-0.6.25",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.regex-syntax-0.6.25.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__ryu__1_0_5",
        url = "https://crates.io/api/v1/crates/ryu/1.0.5/download",
        type = "tar.gz",
        sha256 = "71d301d4193d031abdd79ff7e3dd721168a9572ef3fe51a1517aba235bd8f86e",
        strip_prefix = "ryu-1.0.5",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.ryu-1.0.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__serde__1_0_128",
        url = "https://crates.io/api/v1/crates/serde/1.0.128/download",
        type = "tar.gz",
        sha256 = "1056a0db1978e9dbf0f6e4fca677f6f9143dc1c19de346f22cac23e422196834",
        strip_prefix = "serde-1.0.128",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.serde-1.0.128.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__serde_derive__1_0_128",
        url = "https://crates.io/api/v1/crates/serde_derive/1.0.128/download",
        type = "tar.gz",
        sha256 = "13af2fbb8b60a8950d6c72a56d2095c28870367cc8e10c55e9745bac4995a2c4",
        strip_prefix = "serde_derive-1.0.128",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.serde_derive-1.0.128.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__serde_json__1_0_66",
        url = "https://crates.io/api/v1/crates/serde_json/1.0.66/download",
        type = "tar.gz",
        sha256 = "336b10da19a12ad094b59d870ebde26a45402e5b470add4b5fd03c5048a32127",
        strip_prefix = "serde_json-1.0.66",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.serde_json-1.0.66.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__strsim__0_8_0",
        url = "https://crates.io/api/v1/crates/strsim/0.8.0/download",
        type = "tar.gz",
        sha256 = "8ea5119cdb4c55b55d432abb513a0429384878c15dde60cc77b1c99de1a95a6a",
        strip_prefix = "strsim-0.8.0",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.strsim-0.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__structopt__0_3_22",
        url = "https://crates.io/api/v1/crates/structopt/0.3.22/download",
        type = "tar.gz",
        sha256 = "69b041cdcb67226aca307e6e7be44c8806423d83e018bd662360a93dabce4d71",
        strip_prefix = "structopt-0.3.22",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.structopt-0.3.22.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__structopt_derive__0_4_15",
        url = "https://crates.io/api/v1/crates/structopt-derive/0.4.15/download",
        type = "tar.gz",
        sha256 = "7813934aecf5f51a54775e00068c237de98489463968231a51746bbbc03f9c10",
        strip_prefix = "structopt-derive-0.4.15",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.structopt-derive-0.4.15.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__syn__1_0_75",
        url = "https://crates.io/api/v1/crates/syn/1.0.75/download",
        type = "tar.gz",
        sha256 = "b7f58f7e8eaa0009c5fec437aabf511bd9933e4b2d7407bd05273c01a8906ea7",
        strip_prefix = "syn-1.0.75",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.syn-1.0.75.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__termcolor__1_1_2",
        url = "https://crates.io/api/v1/crates/termcolor/1.1.2/download",
        type = "tar.gz",
        sha256 = "2dfed899f0eb03f32ee8c6a0aabdb8a7949659e3466561fc0adf54e26d88c5f4",
        strip_prefix = "termcolor-1.1.2",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.termcolor-1.1.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__textwrap__0_11_0",
        url = "https://crates.io/api/v1/crates/textwrap/0.11.0/download",
        type = "tar.gz",
        sha256 = "d326610f408c7a4eb6f51c37c330e496b08506c9457c9d34287ecc38809fb060",
        strip_prefix = "textwrap-0.11.0",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.textwrap-0.11.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__unicode_segmentation__1_8_0",
        url = "https://crates.io/api/v1/crates/unicode-segmentation/1.8.0/download",
        type = "tar.gz",
        sha256 = "8895849a949e7845e06bd6dc1aa51731a103c42707010a5b591c0038fb73385b",
        strip_prefix = "unicode-segmentation-1.8.0",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.unicode-segmentation-1.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__unicode_width__0_1_8",
        url = "https://crates.io/api/v1/crates/unicode-width/0.1.8/download",
        type = "tar.gz",
        sha256 = "9337591893a19b88d8d87f2cec1e73fad5cdfd10e5a6f349f498ad6ea2ffb1e3",
        strip_prefix = "unicode-width-0.1.8",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.unicode-width-0.1.8.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__unicode_xid__0_2_2",
        url = "https://crates.io/api/v1/crates/unicode-xid/0.2.2/download",
        type = "tar.gz",
        sha256 = "8ccb82d61f80a663efe1f787a51b16b5a51e3314d6ac365b08639f52387b33f3",
        strip_prefix = "unicode-xid-0.2.2",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.unicode-xid-0.2.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__vec_map__0_8_2",
        url = "https://crates.io/api/v1/crates/vec_map/0.8.2/download",
        type = "tar.gz",
        sha256 = "f1bddf1187be692e79c5ffeab891132dfb0f236ed36a43c7ed39f1165ee20191",
        strip_prefix = "vec_map-0.8.2",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.vec_map-0.8.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__version_check__0_9_3",
        url = "https://crates.io/api/v1/crates/version_check/0.9.3/download",
        type = "tar.gz",
        sha256 = "5fecdca9a5291cc2b8dcf7dc02453fee791a280f3743cb0905f8822ae463b3fe",
        strip_prefix = "version_check-0.9.3",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.version_check-0.9.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__winapi__0_3_9",
        url = "https://crates.io/api/v1/crates/winapi/0.3.9/download",
        type = "tar.gz",
        sha256 = "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419",
        strip_prefix = "winapi-0.3.9",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.winapi-0.3.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__winapi_i686_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-i686-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.winapi-i686-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__winapi_util__0_1_5",
        url = "https://crates.io/api/v1/crates/winapi-util/0.1.5/download",
        type = "tar.gz",
        sha256 = "70ec6ce85bb158151cae5e5c87f95a8e97d2c0c4b001223f33a334e3ce5de178",
        strip_prefix = "winapi-util-0.1.5",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.winapi-util-0.1.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_tools_rust_analyzer__winapi_x86_64_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-x86_64-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("//tools/rust_analyzer/raze/remote:BUILD.winapi-x86_64-pc-windows-gnu-0.4.0.bazel"),
    )
