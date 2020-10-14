"""
@generated
cargo-raze crate workspace functions

DO NOT EDIT! Replaced on runs of cargo-raze
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

def rules_rust_bindgen_fetch_remote_crates():
    """This function defines a collection of repos and should be called in a WORKSPACE file"""
    maybe(
        http_archive,
        name = "rules_rust_bindgen__aho_corasick__0_7_13",
        url = "https://crates.io/api/v1/crates/aho-corasick/0.7.13/download",
        type = "tar.gz",
        sha256 = "043164d8ba5c4c3035fec9bbee8647c0261d788f3474306f93bb65901cae0e86",
        strip_prefix = "aho-corasick-0.7.13",
        build_file = Label("//bindgen/raze/remote:aho-corasick-0.7.13.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__ansi_term__0_11_0",
        url = "https://crates.io/api/v1/crates/ansi_term/0.11.0/download",
        type = "tar.gz",
        sha256 = "ee49baf6cb617b853aa8d93bf420db2383fab46d314482ca2803b40d5fde979b",
        strip_prefix = "ansi_term-0.11.0",
        build_file = Label("//bindgen/raze/remote:ansi_term-0.11.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__atty__0_2_14",
        url = "https://crates.io/api/v1/crates/atty/0.2.14/download",
        type = "tar.gz",
        sha256 = "d9b39be18770d11421cdb1b9947a45dd3f37e93092cbf377614828a319d5fee8",
        strip_prefix = "atty-0.2.14",
        build_file = Label("//bindgen/raze/remote:atty-0.2.14.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__bindgen__0_54_0",
        url = "https://crates.io/api/v1/crates/bindgen/0.54.0/download",
        type = "tar.gz",
        sha256 = "66c0bb6167449588ff70803f4127f0684f9063097eca5016f37eb52b92c2cf36",
        strip_prefix = "bindgen-0.54.0",
        build_file = Label("//bindgen/raze/remote:bindgen-0.54.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__bitflags__1_2_1",
        url = "https://crates.io/api/v1/crates/bitflags/1.2.1/download",
        type = "tar.gz",
        sha256 = "cf1de2fe8c75bc145a2f577add951f8134889b4795d47466a54a5c846d691693",
        strip_prefix = "bitflags-1.2.1",
        build_file = Label("//bindgen/raze/remote:bitflags-1.2.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__cc__1_0_60",
        url = "https://crates.io/api/v1/crates/cc/1.0.60/download",
        type = "tar.gz",
        sha256 = "ef611cc68ff783f18535d77ddd080185275713d852c4f5cbb6122c462a7a825c",
        strip_prefix = "cc-1.0.60",
        build_file = Label("//bindgen/raze/remote:cc-1.0.60.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__cexpr__0_4_0",
        url = "https://crates.io/api/v1/crates/cexpr/0.4.0/download",
        type = "tar.gz",
        sha256 = "f4aedb84272dbe89af497cf81375129abda4fc0a9e7c5d317498c15cc30c0d27",
        strip_prefix = "cexpr-0.4.0",
        build_file = Label("//bindgen/raze/remote:cexpr-0.4.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__cfg_if__0_1_10",
        url = "https://crates.io/api/v1/crates/cfg-if/0.1.10/download",
        type = "tar.gz",
        sha256 = "4785bdd1c96b2a846b2bd7cc02e86b6b3dbf14e7e53446c4f54c92a361040822",
        strip_prefix = "cfg-if-0.1.10",
        build_file = Label("//bindgen/raze/remote:cfg-if-0.1.10.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__clang_sys__0_29_3",
        url = "https://crates.io/api/v1/crates/clang-sys/0.29.3/download",
        type = "tar.gz",
        sha256 = "fe6837df1d5cba2397b835c8530f51723267e16abbf83892e9e5af4f0e5dd10a",
        strip_prefix = "clang-sys-0.29.3",
        build_file = Label("//bindgen/raze/remote:clang-sys-0.29.3.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__clap__2_33_3",
        url = "https://crates.io/api/v1/crates/clap/2.33.3/download",
        type = "tar.gz",
        sha256 = "37e58ac78573c40708d45522f0d80fa2f01cc4f9b4e2bf749807255454312002",
        strip_prefix = "clap-2.33.3",
        build_file = Label("//bindgen/raze/remote:clap-2.33.3.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__env_logger__0_7_1",
        url = "https://crates.io/api/v1/crates/env_logger/0.7.1/download",
        type = "tar.gz",
        sha256 = "44533bbbb3bb3c1fa17d9f2e4e38bbbaf8396ba82193c4cb1b6445d711445d36",
        strip_prefix = "env_logger-0.7.1",
        build_file = Label("//bindgen/raze/remote:env_logger-0.7.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__glob__0_3_0",
        url = "https://crates.io/api/v1/crates/glob/0.3.0/download",
        type = "tar.gz",
        sha256 = "9b919933a397b79c37e33b77bb2aa3dc8eb6e165ad809e58ff75bc7db2e34574",
        strip_prefix = "glob-0.3.0",
        build_file = Label("//bindgen/raze/remote:glob-0.3.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__hermit_abi__0_1_15",
        url = "https://crates.io/api/v1/crates/hermit-abi/0.1.15/download",
        type = "tar.gz",
        sha256 = "3deed196b6e7f9e44a2ae8d94225d80302d81208b1bb673fd21fe634645c85a9",
        strip_prefix = "hermit-abi-0.1.15",
        build_file = Label("//bindgen/raze/remote:hermit-abi-0.1.15.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__humantime__1_3_0",
        url = "https://crates.io/api/v1/crates/humantime/1.3.0/download",
        type = "tar.gz",
        sha256 = "df004cfca50ef23c36850aaaa59ad52cc70d0e90243c3c7737a4dd32dc7a3c4f",
        strip_prefix = "humantime-1.3.0",
        build_file = Label("//bindgen/raze/remote:humantime-1.3.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__lazy_static__1_4_0",
        url = "https://crates.io/api/v1/crates/lazy_static/1.4.0/download",
        type = "tar.gz",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        strip_prefix = "lazy_static-1.4.0",
        build_file = Label("//bindgen/raze/remote:lazy_static-1.4.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__lazycell__1_3_0",
        url = "https://crates.io/api/v1/crates/lazycell/1.3.0/download",
        type = "tar.gz",
        sha256 = "830d08ce1d1d941e6b30645f1a0eb5643013d835ce3779a5fc208261dbe10f55",
        strip_prefix = "lazycell-1.3.0",
        build_file = Label("//bindgen/raze/remote:lazycell-1.3.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__libc__0_2_77",
        url = "https://crates.io/api/v1/crates/libc/0.2.77/download",
        type = "tar.gz",
        sha256 = "f2f96b10ec2560088a8e76961b00d47107b3a625fecb76dedb29ee7ccbf98235",
        strip_prefix = "libc-0.2.77",
        build_file = Label("//bindgen/raze/remote:libc-0.2.77.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__libloading__0_5_0",
        url = "https://crates.io/api/v1/crates/libloading/0.5.0/download",
        type = "tar.gz",
        sha256 = "9c3ad660d7cb8c5822cd83d10897b0f1f1526792737a179e73896152f85b88c2",
        strip_prefix = "libloading-0.5.0",
        build_file = Label("//bindgen/raze/remote:libloading-0.5.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__log__0_4_11",
        url = "https://crates.io/api/v1/crates/log/0.4.11/download",
        type = "tar.gz",
        sha256 = "4fabed175da42fed1fa0746b0ea71f412aa9d35e76e95e59b192c64b9dc2bf8b",
        strip_prefix = "log-0.4.11",
        build_file = Label("//bindgen/raze/remote:log-0.4.11.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__memchr__2_3_3",
        url = "https://crates.io/api/v1/crates/memchr/2.3.3/download",
        type = "tar.gz",
        sha256 = "3728d817d99e5ac407411fa471ff9800a778d88a24685968b36824eaf4bee400",
        strip_prefix = "memchr-2.3.3",
        build_file = Label("//bindgen/raze/remote:memchr-2.3.3.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__nom__5_1_2",
        url = "https://crates.io/api/v1/crates/nom/5.1.2/download",
        type = "tar.gz",
        sha256 = "ffb4262d26ed83a1c0a33a38fe2bb15797329c85770da05e6b828ddb782627af",
        strip_prefix = "nom-5.1.2",
        build_file = Label("//bindgen/raze/remote:nom-5.1.2.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__peeking_take_while__0_1_2",
        url = "https://crates.io/api/v1/crates/peeking_take_while/0.1.2/download",
        type = "tar.gz",
        sha256 = "19b17cddbe7ec3f8bc800887bab5e717348c95ea2ca0b1bf0837fb964dc67099",
        strip_prefix = "peeking_take_while-0.1.2",
        build_file = Label("//bindgen/raze/remote:peeking_take_while-0.1.2.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__proc_macro2__1_0_21",
        url = "https://crates.io/api/v1/crates/proc-macro2/1.0.21/download",
        type = "tar.gz",
        sha256 = "36e28516df94f3dd551a587da5357459d9b36d945a7c37c3557928c1c2ff2a2c",
        strip_prefix = "proc-macro2-1.0.21",
        build_file = Label("//bindgen/raze/remote:proc-macro2-1.0.21.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__quick_error__1_2_3",
        url = "https://crates.io/api/v1/crates/quick-error/1.2.3/download",
        type = "tar.gz",
        sha256 = "a1d01941d82fa2ab50be1e79e6714289dd7cde78eba4c074bc5a4374f650dfe0",
        strip_prefix = "quick-error-1.2.3",
        build_file = Label("//bindgen/raze/remote:quick-error-1.2.3.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__quote__1_0_7",
        url = "https://crates.io/api/v1/crates/quote/1.0.7/download",
        type = "tar.gz",
        sha256 = "aa563d17ecb180e500da1cfd2b028310ac758de548efdd203e18f283af693f37",
        strip_prefix = "quote-1.0.7",
        build_file = Label("//bindgen/raze/remote:quote-1.0.7.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__regex__1_3_9",
        url = "https://crates.io/api/v1/crates/regex/1.3.9/download",
        type = "tar.gz",
        sha256 = "9c3780fcf44b193bc4d09f36d2a3c87b251da4a046c87795a0d35f4f927ad8e6",
        strip_prefix = "regex-1.3.9",
        build_file = Label("//bindgen/raze/remote:regex-1.3.9.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__regex_syntax__0_6_18",
        url = "https://crates.io/api/v1/crates/regex-syntax/0.6.18/download",
        type = "tar.gz",
        sha256 = "26412eb97c6b088a6997e05f69403a802a92d520de2f8e63c2b65f9e0f47c4e8",
        strip_prefix = "regex-syntax-0.6.18",
        build_file = Label("//bindgen/raze/remote:regex-syntax-0.6.18.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__rustc_hash__1_1_0",
        url = "https://crates.io/api/v1/crates/rustc-hash/1.1.0/download",
        type = "tar.gz",
        sha256 = "08d43f7aa6b08d49f382cde6a7982047c3426db949b1424bc4b7ec9ae12c6ce2",
        strip_prefix = "rustc-hash-1.1.0",
        build_file = Label("//bindgen/raze/remote:rustc-hash-1.1.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__shlex__0_1_1",
        url = "https://crates.io/api/v1/crates/shlex/0.1.1/download",
        type = "tar.gz",
        sha256 = "7fdf1b9db47230893d76faad238fd6097fd6d6a9245cd7a4d90dbd639536bbd2",
        strip_prefix = "shlex-0.1.1",
        build_file = Label("//bindgen/raze/remote:shlex-0.1.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__strsim__0_8_0",
        url = "https://crates.io/api/v1/crates/strsim/0.8.0/download",
        type = "tar.gz",
        sha256 = "8ea5119cdb4c55b55d432abb513a0429384878c15dde60cc77b1c99de1a95a6a",
        strip_prefix = "strsim-0.8.0",
        build_file = Label("//bindgen/raze/remote:strsim-0.8.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__termcolor__1_1_0",
        url = "https://crates.io/api/v1/crates/termcolor/1.1.0/download",
        type = "tar.gz",
        sha256 = "bb6bfa289a4d7c5766392812c0a1f4c1ba45afa1ad47803c11e1f407d846d75f",
        strip_prefix = "termcolor-1.1.0",
        build_file = Label("//bindgen/raze/remote:termcolor-1.1.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__textwrap__0_11_0",
        url = "https://crates.io/api/v1/crates/textwrap/0.11.0/download",
        type = "tar.gz",
        sha256 = "d326610f408c7a4eb6f51c37c330e496b08506c9457c9d34287ecc38809fb060",
        strip_prefix = "textwrap-0.11.0",
        build_file = Label("//bindgen/raze/remote:textwrap-0.11.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__thread_local__1_0_1",
        url = "https://crates.io/api/v1/crates/thread_local/1.0.1/download",
        type = "tar.gz",
        sha256 = "d40c6d1b69745a6ec6fb1ca717914848da4b44ae29d9b3080cbee91d72a69b14",
        strip_prefix = "thread_local-1.0.1",
        build_file = Label("//bindgen/raze/remote:thread_local-1.0.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__unicode_width__0_1_8",
        url = "https://crates.io/api/v1/crates/unicode-width/0.1.8/download",
        type = "tar.gz",
        sha256 = "9337591893a19b88d8d87f2cec1e73fad5cdfd10e5a6f349f498ad6ea2ffb1e3",
        strip_prefix = "unicode-width-0.1.8",
        build_file = Label("//bindgen/raze/remote:unicode-width-0.1.8.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__unicode_xid__0_2_1",
        url = "https://crates.io/api/v1/crates/unicode-xid/0.2.1/download",
        type = "tar.gz",
        sha256 = "f7fe0bb3479651439c9112f72b6c505038574c9fbb575ed1bf3b797fa39dd564",
        strip_prefix = "unicode-xid-0.2.1",
        build_file = Label("//bindgen/raze/remote:unicode-xid-0.2.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__vec_map__0_8_2",
        url = "https://crates.io/api/v1/crates/vec_map/0.8.2/download",
        type = "tar.gz",
        sha256 = "f1bddf1187be692e79c5ffeab891132dfb0f236ed36a43c7ed39f1165ee20191",
        strip_prefix = "vec_map-0.8.2",
        build_file = Label("//bindgen/raze/remote:vec_map-0.8.2.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__version_check__0_9_2",
        url = "https://crates.io/api/v1/crates/version_check/0.9.2/download",
        type = "tar.gz",
        sha256 = "b5a972e5669d67ba988ce3dc826706fb0a8b01471c088cb0b6110b805cc36aed",
        strip_prefix = "version_check-0.9.2",
        build_file = Label("//bindgen/raze/remote:version_check-0.9.2.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__which__3_1_1",
        url = "https://crates.io/api/v1/crates/which/3.1.1/download",
        type = "tar.gz",
        sha256 = "d011071ae14a2f6671d0b74080ae0cd8ebf3a6f8c9589a2cd45f23126fe29724",
        strip_prefix = "which-3.1.1",
        build_file = Label("//bindgen/raze/remote:which-3.1.1.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__winapi__0_3_9",
        url = "https://crates.io/api/v1/crates/winapi/0.3.9/download",
        type = "tar.gz",
        sha256 = "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419",
        strip_prefix = "winapi-0.3.9",
        build_file = Label("//bindgen/raze/remote:winapi-0.3.9.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__winapi_i686_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-i686-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("//bindgen/raze/remote:winapi-i686-pc-windows-gnu-0.4.0.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__winapi_util__0_1_5",
        url = "https://crates.io/api/v1/crates/winapi-util/0.1.5/download",
        type = "tar.gz",
        sha256 = "70ec6ce85bb158151cae5e5c87f95a8e97d2c0c4b001223f33a334e3ce5de178",
        strip_prefix = "winapi-util-0.1.5",
        build_file = Label("//bindgen/raze/remote:winapi-util-0.1.5.BUILD"),
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__winapi_x86_64_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-x86_64-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("//bindgen/raze/remote:winapi-x86_64-pc-windows-gnu-0.4.0.BUILD"),
    )
