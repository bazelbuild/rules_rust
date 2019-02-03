"""
cargo-raze crate workspace functions

DO NOT EDIT! Replaced on runs of cargo-raze
"""
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")

def _new_http_archive(name, **kwargs):
    if not native.existing_rule(name):
        http_archive(name=name, **kwargs)

def _new_git_repository(name, **kwargs):
    if not native.existing_rule(name):
        new_git_repository(name=name, **kwargs)

def raze_fetch_remote_crates():

    _new_http_archive(
        name = "raze__aho_corasick__0_6_9",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/aho-corasick/aho-corasick-0.6.9.crate",
        type = "tar.gz",
        sha256 = "1e9a933f4e58658d7b12defcf96dc5c720f20832deebe3e0a19efd3b6aaeeb9e",
        strip_prefix = "aho-corasick-0.6.9",
        build_file = Label("//bindgen/raze/remote:aho-corasick-0.6.9.BUILD")
    )

    _new_http_archive(
        name = "raze__ansi_term__0_11_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/ansi_term/ansi_term-0.11.0.crate",
        type = "tar.gz",
        sha256 = "ee49baf6cb617b853aa8d93bf420db2383fab46d314482ca2803b40d5fde979b",
        strip_prefix = "ansi_term-0.11.0",
        build_file = Label("//bindgen/raze/remote:ansi_term-0.11.0.BUILD")
    )

    _new_http_archive(
        name = "raze__atty__0_2_11",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/atty/atty-0.2.11.crate",
        type = "tar.gz",
        sha256 = "9a7d5b8723950951411ee34d271d99dddcc2035a16ab25310ea2c8cfd4369652",
        strip_prefix = "atty-0.2.11",
        build_file = Label("//bindgen/raze/remote:atty-0.2.11.BUILD")
    )

    _new_http_archive(
        name = "raze__bindgen__0_40_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/bindgen/bindgen-0.40.0.crate",
        type = "tar.gz",
        sha256 = "8f4c4ffe91e0f26bdcc5a8dd58cbf0358ad772b8ec1ae274a11a0ba54ec175f4",
        strip_prefix = "bindgen-0.40.0",
        build_file = Label("//bindgen/raze/remote:bindgen-0.40.0.BUILD")
    )

    _new_http_archive(
        name = "raze__bitflags__1_0_4",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/bitflags/bitflags-1.0.4.crate",
        type = "tar.gz",
        sha256 = "228047a76f468627ca71776ecdebd732a3423081fcf5125585bcd7c49886ce12",
        strip_prefix = "bitflags-1.0.4",
        build_file = Label("//bindgen/raze/remote:bitflags-1.0.4.BUILD")
    )

    _new_http_archive(
        name = "raze__cc__1_0_28",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/cc/cc-1.0.28.crate",
        type = "tar.gz",
        sha256 = "bb4a8b715cb4597106ea87c7c84b2f1d452c7492033765df7f32651e66fcf749",
        strip_prefix = "cc-1.0.28",
        build_file = Label("//bindgen/raze/remote:cc-1.0.28.BUILD")
    )

    _new_http_archive(
        name = "raze__cexpr__0_2_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/cexpr/cexpr-0.2.3.crate",
        type = "tar.gz",
        sha256 = "42aac45e9567d97474a834efdee3081b3c942b2205be932092f53354ce503d6c",
        strip_prefix = "cexpr-0.2.3",
        build_file = Label("//bindgen/raze/remote:cexpr-0.2.3.BUILD")
    )

    _new_http_archive(
        name = "raze__cfg_if__0_1_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/cfg-if/cfg-if-0.1.6.crate",
        type = "tar.gz",
        sha256 = "082bb9b28e00d3c9d39cc03e64ce4cea0f1bb9b3fde493f0cbc008472d22bdf4",
        strip_prefix = "cfg-if-0.1.6",
        build_file = Label("//bindgen/raze/remote:cfg-if-0.1.6.BUILD")
    )

    _new_http_archive(
        name = "raze__clang_sys__0_23_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/clang-sys/clang-sys-0.23.0.crate",
        type = "tar.gz",
        sha256 = "d7f7c04e52c35222fffcc3a115b5daf5f7e2bfb71c13c4e2321afe1fc71859c2",
        strip_prefix = "clang-sys-0.23.0",
        build_file = Label("//bindgen/raze/remote:clang-sys-0.23.0.BUILD")
    )

    _new_http_archive(
        name = "raze__clap__2_32_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/clap/clap-2.32.0.crate",
        type = "tar.gz",
        sha256 = "b957d88f4b6a63b9d70d5f454ac8011819c6efa7727858f458ab71c756ce2d3e",
        strip_prefix = "clap-2.32.0",
        build_file = Label("//bindgen/raze/remote:clap-2.32.0.BUILD")
    )

    _new_http_archive(
        name = "raze__env_logger__0_5_13",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/env_logger/env_logger-0.5.13.crate",
        type = "tar.gz",
        sha256 = "15b0a4d2e39f8420210be8b27eeda28029729e2fd4291019455016c348240c38",
        strip_prefix = "env_logger-0.5.13",
        build_file = Label("//bindgen/raze/remote:env_logger-0.5.13.BUILD")
    )

    _new_http_archive(
        name = "raze__glob__0_2_11",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/glob/glob-0.2.11.crate",
        type = "tar.gz",
        sha256 = "8be18de09a56b60ed0edf84bc9df007e30040691af7acd1c41874faac5895bfb",
        strip_prefix = "glob-0.2.11",
        build_file = Label("//bindgen/raze/remote:glob-0.2.11.BUILD")
    )

    _new_http_archive(
        name = "raze__humantime__1_2_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/humantime/humantime-1.2.0.crate",
        type = "tar.gz",
        sha256 = "3ca7e5f2e110db35f93b837c81797f3714500b81d517bf20c431b16d3ca4f114",
        strip_prefix = "humantime-1.2.0",
        build_file = Label("//bindgen/raze/remote:humantime-1.2.0.BUILD")
    )

    _new_http_archive(
        name = "raze__lazy_static__1_2_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/lazy_static/lazy_static-1.2.0.crate",
        type = "tar.gz",
        sha256 = "a374c89b9db55895453a74c1e38861d9deec0b01b405a82516e9d5de4820dea1",
        strip_prefix = "lazy_static-1.2.0",
        build_file = Label("//bindgen/raze/remote:lazy_static-1.2.0.BUILD")
    )

    _new_http_archive(
        name = "raze__libc__0_2_48",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/libc/libc-0.2.48.crate",
        type = "tar.gz",
        sha256 = "e962c7641008ac010fa60a7dfdc1712449f29c44ef2d4702394aea943ee75047",
        strip_prefix = "libc-0.2.48",
        build_file = Label("//bindgen/raze/remote:libc-0.2.48.BUILD")
    )

    _new_http_archive(
        name = "raze__libloading__0_5_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/libloading/libloading-0.5.0.crate",
        type = "tar.gz",
        sha256 = "9c3ad660d7cb8c5822cd83d10897b0f1f1526792737a179e73896152f85b88c2",
        strip_prefix = "libloading-0.5.0",
        build_file = Label("//bindgen/raze/remote:libloading-0.5.0.BUILD")
    )

    _new_http_archive(
        name = "raze__log__0_4_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/log/log-0.4.6.crate",
        type = "tar.gz",
        sha256 = "c84ec4b527950aa83a329754b01dbe3f58361d1c5efacd1f6d68c494d08a17c6",
        strip_prefix = "log-0.4.6",
        build_file = Label("//bindgen/raze/remote:log-0.4.6.BUILD")
    )

    _new_http_archive(
        name = "raze__memchr__1_0_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/memchr/memchr-1.0.2.crate",
        type = "tar.gz",
        sha256 = "148fab2e51b4f1cfc66da2a7c32981d1d3c083a803978268bb11fe4b86925e7a",
        strip_prefix = "memchr-1.0.2",
        build_file = Label("//bindgen/raze/remote:memchr-1.0.2.BUILD")
    )

    _new_http_archive(
        name = "raze__memchr__2_1_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/memchr/memchr-2.1.3.crate",
        type = "tar.gz",
        sha256 = "e1dd4eaac298c32ce07eb6ed9242eda7d82955b9170b7d6db59b2e02cc63fcb8",
        strip_prefix = "memchr-2.1.3",
        build_file = Label("//bindgen/raze/remote:memchr-2.1.3.BUILD")
    )

    _new_http_archive(
        name = "raze__nom__3_2_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/nom/nom-3.2.1.crate",
        type = "tar.gz",
        sha256 = "05aec50c70fd288702bcd93284a8444607f3292dbdf2a30de5ea5dcdbe72287b",
        strip_prefix = "nom-3.2.1",
        build_file = Label("//bindgen/raze/remote:nom-3.2.1.BUILD")
    )

    _new_http_archive(
        name = "raze__peeking_take_while__0_1_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/peeking_take_while/peeking_take_while-0.1.2.crate",
        type = "tar.gz",
        sha256 = "19b17cddbe7ec3f8bc800887bab5e717348c95ea2ca0b1bf0837fb964dc67099",
        strip_prefix = "peeking_take_while-0.1.2",
        build_file = Label("//bindgen/raze/remote:peeking_take_while-0.1.2.BUILD")
    )

    _new_http_archive(
        name = "raze__proc_macro2__0_3_5",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/proc-macro2/proc-macro2-0.3.5.crate",
        type = "tar.gz",
        sha256 = "77997c53ae6edd6d187fec07ec41b207063b5ee6f33680e9fa86d405cdd313d4",
        strip_prefix = "proc-macro2-0.3.5",
        build_file = Label("//bindgen/raze/remote:proc-macro2-0.3.5.BUILD")
    )

    _new_http_archive(
        name = "raze__quick_error__1_2_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/quick-error/quick-error-1.2.2.crate",
        type = "tar.gz",
        sha256 = "9274b940887ce9addde99c4eee6b5c44cc494b182b97e73dc8ffdcb3397fd3f0",
        strip_prefix = "quick-error-1.2.2",
        build_file = Label("//bindgen/raze/remote:quick-error-1.2.2.BUILD")
    )

    _new_http_archive(
        name = "raze__quote__0_5_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/quote/quote-0.5.2.crate",
        type = "tar.gz",
        sha256 = "9949cfe66888ffe1d53e6ec9d9f3b70714083854be20fd5e271b232a017401e8",
        strip_prefix = "quote-0.5.2",
        build_file = Label("//bindgen/raze/remote:quote-0.5.2.BUILD")
    )

    _new_http_archive(
        name = "raze__redox_syscall__0_1_51",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/redox_syscall/redox_syscall-0.1.51.crate",
        type = "tar.gz",
        sha256 = "423e376fffca3dfa06c9e9790a9ccd282fafb3cc6e6397d01dbf64f9bacc6b85",
        strip_prefix = "redox_syscall-0.1.51",
        build_file = Label("//bindgen/raze/remote:redox_syscall-0.1.51.BUILD")
    )

    _new_http_archive(
        name = "raze__redox_termios__0_1_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/redox_termios/redox_termios-0.1.1.crate",
        type = "tar.gz",
        sha256 = "7e891cfe48e9100a70a3b6eb652fef28920c117d366339687bd5576160db0f76",
        strip_prefix = "redox_termios-0.1.1",
        build_file = Label("//bindgen/raze/remote:redox_termios-0.1.1.BUILD")
    )

    _new_http_archive(
        name = "raze__regex__1_1_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/regex/regex-1.1.0.crate",
        type = "tar.gz",
        sha256 = "37e7cbbd370869ce2e8dff25c7018702d10b21a20ef7135316f8daecd6c25b7f",
        strip_prefix = "regex-1.1.0",
        build_file = Label("//bindgen/raze/remote:regex-1.1.0.BUILD")
    )

    _new_http_archive(
        name = "raze__regex_syntax__0_6_5",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/regex-syntax/regex-syntax-0.6.5.crate",
        type = "tar.gz",
        sha256 = "8c2f35eedad5295fdf00a63d7d4b238135723f92b434ec06774dad15c7ab0861",
        strip_prefix = "regex-syntax-0.6.5",
        build_file = Label("//bindgen/raze/remote:regex-syntax-0.6.5.BUILD")
    )

    _new_http_archive(
        name = "raze__strsim__0_7_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/strsim/strsim-0.7.0.crate",
        type = "tar.gz",
        sha256 = "bb4f380125926a99e52bc279241539c018323fab05ad6368b56f93d9369ff550",
        strip_prefix = "strsim-0.7.0",
        build_file = Label("//bindgen/raze/remote:strsim-0.7.0.BUILD")
    )

    _new_http_archive(
        name = "raze__termcolor__1_0_4",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/termcolor/termcolor-1.0.4.crate",
        type = "tar.gz",
        sha256 = "4096add70612622289f2fdcdbd5086dc81c1e2675e6ae58d6c4f62a16c6d7f2f",
        strip_prefix = "termcolor-1.0.4",
        build_file = Label("//bindgen/raze/remote:termcolor-1.0.4.BUILD")
    )

    _new_http_archive(
        name = "raze__termion__1_5_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/termion/termion-1.5.1.crate",
        type = "tar.gz",
        sha256 = "689a3bdfaab439fd92bc87df5c4c78417d3cbe537487274e9b0b2dce76e92096",
        strip_prefix = "termion-1.5.1",
        build_file = Label("//bindgen/raze/remote:termion-1.5.1.BUILD")
    )

    _new_http_archive(
        name = "raze__textwrap__0_10_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/textwrap/textwrap-0.10.0.crate",
        type = "tar.gz",
        sha256 = "307686869c93e71f94da64286f9a9524c0f308a9e1c87a583de8e9c9039ad3f6",
        strip_prefix = "textwrap-0.10.0",
        build_file = Label("//bindgen/raze/remote:textwrap-0.10.0.BUILD")
    )

    _new_http_archive(
        name = "raze__thread_local__0_3_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/thread_local/thread_local-0.3.6.crate",
        type = "tar.gz",
        sha256 = "c6b53e329000edc2b34dbe8545fd20e55a333362d0a321909685a19bd28c3f1b",
        strip_prefix = "thread_local-0.3.6",
        build_file = Label("//bindgen/raze/remote:thread_local-0.3.6.BUILD")
    )

    _new_http_archive(
        name = "raze__ucd_util__0_1_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/ucd-util/ucd-util-0.1.3.crate",
        type = "tar.gz",
        sha256 = "535c204ee4d8434478593480b8f86ab45ec9aae0e83c568ca81abf0fd0e88f86",
        strip_prefix = "ucd-util-0.1.3",
        build_file = Label("//bindgen/raze/remote:ucd-util-0.1.3.BUILD")
    )

    _new_http_archive(
        name = "raze__unicode_width__0_1_5",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/unicode-width/unicode-width-0.1.5.crate",
        type = "tar.gz",
        sha256 = "882386231c45df4700b275c7ff55b6f3698780a650026380e72dabe76fa46526",
        strip_prefix = "unicode-width-0.1.5",
        build_file = Label("//bindgen/raze/remote:unicode-width-0.1.5.BUILD")
    )

    _new_http_archive(
        name = "raze__unicode_xid__0_1_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/unicode-xid/unicode-xid-0.1.0.crate",
        type = "tar.gz",
        sha256 = "fc72304796d0818e357ead4e000d19c9c174ab23dc11093ac919054d20a6a7fc",
        strip_prefix = "unicode-xid-0.1.0",
        build_file = Label("//bindgen/raze/remote:unicode-xid-0.1.0.BUILD")
    )

    _new_http_archive(
        name = "raze__utf8_ranges__1_0_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/utf8-ranges/utf8-ranges-1.0.2.crate",
        type = "tar.gz",
        sha256 = "796f7e48bef87609f7ade7e06495a87d5cd06c7866e6a5cbfceffc558a243737",
        strip_prefix = "utf8-ranges-1.0.2",
        build_file = Label("//bindgen/raze/remote:utf8-ranges-1.0.2.BUILD")
    )

    _new_http_archive(
        name = "raze__vec_map__0_8_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/vec_map/vec_map-0.8.1.crate",
        type = "tar.gz",
        sha256 = "05c78687fb1a80548ae3250346c3db86a80a7cdd77bda190189f2d0a0987c81a",
        strip_prefix = "vec_map-0.8.1",
        build_file = Label("//bindgen/raze/remote:vec_map-0.8.1.BUILD")
    )

    _new_http_archive(
        name = "raze__which__1_0_5",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/which/which-1.0.5.crate",
        type = "tar.gz",
        sha256 = "e84a603e7e0b1ce1aa1ee2b109c7be00155ce52df5081590d1ffb93f4f515cb2",
        strip_prefix = "which-1.0.5",
        build_file = Label("//bindgen/raze/remote:which-1.0.5.BUILD")
    )

    _new_http_archive(
        name = "raze__winapi__0_3_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi/winapi-0.3.6.crate",
        type = "tar.gz",
        sha256 = "92c1eb33641e276cfa214a0522acad57be5c56b10cb348b3c5117db75f3ac4b0",
        strip_prefix = "winapi-0.3.6",
        build_file = Label("//bindgen/raze/remote:winapi-0.3.6.BUILD")
    )

    _new_http_archive(
        name = "raze__winapi_i686_pc_windows_gnu__0_4_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi-i686-pc-windows-gnu/winapi-i686-pc-windows-gnu-0.4.0.crate",
        type = "tar.gz",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("//bindgen/raze/remote:winapi-i686-pc-windows-gnu-0.4.0.BUILD")
    )

    _new_http_archive(
        name = "raze__winapi_util__0_1_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi-util/winapi-util-0.1.1.crate",
        type = "tar.gz",
        sha256 = "afc5508759c5bf4285e61feb862b6083c8480aec864fa17a81fdec6f69b461ab",
        strip_prefix = "winapi-util-0.1.1",
        build_file = Label("//bindgen/raze/remote:winapi-util-0.1.1.BUILD")
    )

    _new_http_archive(
        name = "raze__winapi_x86_64_pc_windows_gnu__0_4_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi-x86_64-pc-windows-gnu/winapi-x86_64-pc-windows-gnu-0.4.0.crate",
        type = "tar.gz",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("//bindgen/raze/remote:winapi-x86_64-pc-windows-gnu-0.4.0.BUILD")
    )

    _new_http_archive(
        name = "raze__wincolor__1_0_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/wincolor/wincolor-1.0.1.crate",
        type = "tar.gz",
        sha256 = "561ed901ae465d6185fa7864d63fbd5720d0ef718366c9a4dc83cf6170d7e9ba",
        strip_prefix = "wincolor-1.0.1",
        build_file = Label("//bindgen/raze/remote:wincolor-1.0.1.BUILD")
    )

