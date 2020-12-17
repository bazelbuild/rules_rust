"""
@generated
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
        name = "raze__anyhow__1_0_31",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/anyhow/anyhow-1.0.31.crate",
        type = "tar.gz",
        sha256 = "85bb70cc08ec97ca5450e6eba421deeea5f172c0fc61f78b5357b2a8e8be195f",
        strip_prefix = "anyhow-1.0.31",
        build_file = Label("//proto/prostgen/raze/remote:anyhow-1.0.31.BUILD"),
    )

    _new_http_archive(
        name = "raze__async_stream__0_2_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/async-stream/async-stream-0.2.1.crate",
        type = "tar.gz",
        sha256 = "22068c0c19514942eefcfd4daf8976ef1aad84e61539f95cd200c35202f80af5",
        strip_prefix = "async-stream-0.2.1",
        build_file = Label("//proto/prostgen/raze/remote:async-stream-0.2.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__async_stream_impl__0_2_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/async-stream-impl/async-stream-impl-0.2.1.crate",
        type = "tar.gz",
        sha256 = "25f9db3b38af870bf7e5cc649167533b493928e50744e2c30ae350230b414670",
        strip_prefix = "async-stream-impl-0.2.1",
        build_file = Label("//proto/prostgen/raze/remote:async-stream-impl-0.2.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__async_trait__0_1_40",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/async-trait/async-trait-0.1.40.crate",
        type = "tar.gz",
        sha256 = "687c230d85c0a52504709705fc8a53e4a692b83a2184f03dae73e38e1e93a783",
        strip_prefix = "async-trait-0.1.40",
        build_file = Label("//proto/prostgen/raze/remote:async-trait-0.1.40.BUILD"),
    )

    _new_http_archive(
        name = "raze__autocfg__1_0_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/autocfg/autocfg-1.0.1.crate",
        type = "tar.gz",
        sha256 = "cdb031dd78e28731d87d56cc8ffef4a8f36ca26c38fe2de700543e627f8a464a",
        strip_prefix = "autocfg-1.0.1",
        build_file = Label("//proto/prostgen/raze/remote:autocfg-1.0.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__base64__0_12_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/base64/base64-0.12.3.crate",
        type = "tar.gz",
        sha256 = "3441f0f7b02788e948e47f457ca01f1d7e6d92c693bc132c22b087d3141c03ff",
        strip_prefix = "base64-0.12.3",
        build_file = Label("//proto/prostgen/raze/remote:base64-0.12.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__bitflags__1_2_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/bitflags/bitflags-1.2.1.crate",
        type = "tar.gz",
        sha256 = "cf1de2fe8c75bc145a2f577add951f8134889b4795d47466a54a5c846d691693",
        strip_prefix = "bitflags-1.2.1",
        build_file = Label("//proto/prostgen/raze/remote:bitflags-1.2.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__bumpalo__3_4_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/bumpalo/bumpalo-3.4.0.crate",
        type = "tar.gz",
        sha256 = "2e8c087f005730276d1096a652e92a8bacee2e2472bcc9715a74d2bec38b5820",
        strip_prefix = "bumpalo-3.4.0",
        build_file = Label("//proto/prostgen/raze/remote:bumpalo-3.4.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__bytes__0_5_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/bytes/bytes-0.5.6.crate",
        type = "tar.gz",
        sha256 = "0e4cec68f03f32e44924783795810fa50a7035d8c8ebe78580ad7e6c703fba38",
        strip_prefix = "bytes-0.5.6",
        build_file = Label("//proto/prostgen/raze/remote:bytes-0.5.6.BUILD"),
    )

    _new_http_archive(
        name = "raze__cc__1_0_60",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/cc/cc-1.0.60.crate",
        type = "tar.gz",
        sha256 = "ef611cc68ff783f18535d77ddd080185275713d852c4f5cbb6122c462a7a825c",
        strip_prefix = "cc-1.0.60",
        build_file = Label("//proto/prostgen/raze/remote:cc-1.0.60.BUILD"),
    )

    _new_http_archive(
        name = "raze__cfg_if__0_1_10",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/cfg-if/cfg-if-0.1.10.crate",
        type = "tar.gz",
        sha256 = "4785bdd1c96b2a846b2bd7cc02e86b6b3dbf14e7e53446c4f54c92a361040822",
        strip_prefix = "cfg-if-0.1.10",
        build_file = Label("//proto/prostgen/raze/remote:cfg-if-0.1.10.BUILD"),
    )

    _new_http_archive(
        name = "raze__clap__2_33_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/clap/clap-2.33.3.crate",
        type = "tar.gz",
        sha256 = "37e58ac78573c40708d45522f0d80fa2f01cc4f9b4e2bf749807255454312002",
        strip_prefix = "clap-2.33.3",
        build_file = Label("//proto/prostgen/raze/remote:clap-2.33.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__core_foundation__0_7_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/core-foundation/core-foundation-0.7.0.crate",
        type = "tar.gz",
        sha256 = "57d24c7a13c43e870e37c1556b74555437870a04514f7685f5b354e090567171",
        strip_prefix = "core-foundation-0.7.0",
        build_file = Label("//proto/prostgen/raze/remote:core-foundation-0.7.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__core_foundation_sys__0_7_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/core-foundation-sys/core-foundation-sys-0.7.0.crate",
        type = "tar.gz",
        sha256 = "b3a71ab494c0b5b860bdc8407ae08978052417070c2ced38573a9157ad75b8ac",
        strip_prefix = "core-foundation-sys-0.7.0",
        build_file = Label("//proto/prostgen/raze/remote:core-foundation-sys-0.7.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__either__1_6_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/either/either-1.6.1.crate",
        type = "tar.gz",
        sha256 = "e78d4f1cc4ae33bbfc157ed5d5a5ef3bc29227303d595861deb238fcec4e9457",
        strip_prefix = "either-1.6.1",
        build_file = Label("//proto/prostgen/raze/remote:either-1.6.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__fixedbitset__0_2_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/fixedbitset/fixedbitset-0.2.0.crate",
        type = "tar.gz",
        sha256 = "37ab347416e802de484e4d03c7316c48f1ecb56574dfd4a46a80f173ce1de04d",
        strip_prefix = "fixedbitset-0.2.0",
        build_file = Label("//proto/prostgen/raze/remote:fixedbitset-0.2.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__fnv__1_0_7",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/fnv/fnv-1.0.7.crate",
        type = "tar.gz",
        sha256 = "3f9eec918d3f24069decb9af1554cad7c880e2da24a9afd88aca000531ab82c1",
        strip_prefix = "fnv-1.0.7",
        build_file = Label("//proto/prostgen/raze/remote:fnv-1.0.7.BUILD"),
    )

    _new_http_archive(
        name = "raze__fuchsia_zircon__0_3_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/fuchsia-zircon/fuchsia-zircon-0.3.3.crate",
        type = "tar.gz",
        sha256 = "2e9763c69ebaae630ba35f74888db465e49e259ba1bc0eda7d06f4a067615d82",
        strip_prefix = "fuchsia-zircon-0.3.3",
        build_file = Label("//proto/prostgen/raze/remote:fuchsia-zircon-0.3.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__fuchsia_zircon_sys__0_3_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/fuchsia-zircon-sys/fuchsia-zircon-sys-0.3.3.crate",
        type = "tar.gz",
        sha256 = "3dcaa9ae7725d12cdb85b3ad99a434db70b468c09ded17e012d86b5c1010f7a7",
        strip_prefix = "fuchsia-zircon-sys-0.3.3",
        build_file = Label("//proto/prostgen/raze/remote:fuchsia-zircon-sys-0.3.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__futures_channel__0_3_5",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/futures-channel/futures-channel-0.3.5.crate",
        type = "tar.gz",
        sha256 = "f366ad74c28cca6ba456d95e6422883cfb4b252a83bed929c83abfdbbf2967d5",
        strip_prefix = "futures-channel-0.3.5",
        build_file = Label("//proto/prostgen/raze/remote:futures-channel-0.3.5.BUILD"),
    )

    _new_http_archive(
        name = "raze__futures_core__0_3_5",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/futures-core/futures-core-0.3.5.crate",
        type = "tar.gz",
        sha256 = "59f5fff90fd5d971f936ad674802482ba441b6f09ba5e15fd8b39145582ca399",
        strip_prefix = "futures-core-0.3.5",
        build_file = Label("//proto/prostgen/raze/remote:futures-core-0.3.5.BUILD"),
    )

    _new_http_archive(
        name = "raze__futures_sink__0_3_5",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/futures-sink/futures-sink-0.3.5.crate",
        type = "tar.gz",
        sha256 = "3f2032893cb734c7a05d85ce0cc8b8c4075278e93b24b66f9de99d6eb0fa8acc",
        strip_prefix = "futures-sink-0.3.5",
        build_file = Label("//proto/prostgen/raze/remote:futures-sink-0.3.5.BUILD"),
    )

    _new_http_archive(
        name = "raze__futures_task__0_3_5",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/futures-task/futures-task-0.3.5.crate",
        type = "tar.gz",
        sha256 = "bdb66b5f09e22019b1ab0830f7785bcea8e7a42148683f99214f73f8ec21a626",
        strip_prefix = "futures-task-0.3.5",
        build_file = Label("//proto/prostgen/raze/remote:futures-task-0.3.5.BUILD"),
    )

    _new_http_archive(
        name = "raze__futures_util__0_3_5",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/futures-util/futures-util-0.3.5.crate",
        type = "tar.gz",
        sha256 = "8764574ff08b701a084482c3c7031349104b07ac897393010494beaa18ce32c6",
        strip_prefix = "futures-util-0.3.5",
        build_file = Label("//proto/prostgen/raze/remote:futures-util-0.3.5.BUILD"),
    )

    _new_http_archive(
        name = "raze__getrandom__0_1_15",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/getrandom/getrandom-0.1.15.crate",
        type = "tar.gz",
        sha256 = "fc587bc0ec293155d5bfa6b9891ec18a1e330c234f896ea47fbada4cadbe47e6",
        strip_prefix = "getrandom-0.1.15",
        build_file = Label("//proto/prostgen/raze/remote:getrandom-0.1.15.BUILD"),
    )

    _new_http_archive(
        name = "raze__h2__0_2_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/h2/h2-0.2.6.crate",
        type = "tar.gz",
        sha256 = "993f9e0baeed60001cf565546b0d3dbe6a6ad23f2bd31644a133c641eccf6d53",
        strip_prefix = "h2-0.2.6",
        build_file = Label("//proto/prostgen/raze/remote:h2-0.2.6.BUILD"),
    )

    _new_http_archive(
        name = "raze__hashbrown__0_9_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/hashbrown/hashbrown-0.9.0.crate",
        type = "tar.gz",
        sha256 = "00d63df3d41950fb462ed38308eea019113ad1508da725bbedcd0fa5a85ef5f7",
        strip_prefix = "hashbrown-0.9.0",
        build_file = Label("//proto/prostgen/raze/remote:hashbrown-0.9.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__heck__0_3_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/heck/heck-0.3.1.crate",
        type = "tar.gz",
        sha256 = "20564e78d53d2bb135c343b3f47714a56af2061f1c928fdb541dc7b9fdd94205",
        strip_prefix = "heck-0.3.1",
        build_file = Label("//proto/prostgen/raze/remote:heck-0.3.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__http__0_2_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/http/http-0.2.1.crate",
        type = "tar.gz",
        sha256 = "28d569972648b2c512421b5f2a405ad6ac9666547189d0c5477a3f200f3e02f9",
        strip_prefix = "http-0.2.1",
        build_file = Label("//proto/prostgen/raze/remote:http-0.2.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__http_body__0_3_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/http-body/http-body-0.3.1.crate",
        type = "tar.gz",
        sha256 = "13d5ff830006f7646652e057693569bfe0d51760c0085a071769d142a205111b",
        strip_prefix = "http-body-0.3.1",
        build_file = Label("//proto/prostgen/raze/remote:http-body-0.3.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__httparse__1_3_4",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/httparse/httparse-1.3.4.crate",
        type = "tar.gz",
        sha256 = "cd179ae861f0c2e53da70d892f5f3029f9594be0c41dc5269cd371691b1dc2f9",
        strip_prefix = "httparse-1.3.4",
        build_file = Label("//proto/prostgen/raze/remote:httparse-1.3.4.BUILD"),
    )

    _new_http_archive(
        name = "raze__hyper__0_13_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/hyper/hyper-0.13.6.crate",
        type = "tar.gz",
        sha256 = "a6e7655b9594024ad0ee439f3b5a7299369dc2a3f459b47c696f9ff676f9aa1f",
        strip_prefix = "hyper-0.13.6",
        build_file = Label("//proto/prostgen/raze/remote:hyper-0.13.6.BUILD"),
    )

    _new_http_archive(
        name = "raze__indexmap__1_6_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/indexmap/indexmap-1.6.0.crate",
        type = "tar.gz",
        sha256 = "55e2e4c765aa53a0424761bf9f41aa7a6ac1efa87238f59560640e27fca028f2",
        strip_prefix = "indexmap-1.6.0",
        build_file = Label("//proto/prostgen/raze/remote:indexmap-1.6.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__iovec__0_1_4",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/iovec/iovec-0.1.4.crate",
        type = "tar.gz",
        sha256 = "b2b3ea6ff95e175473f8ffe6a7eb7c00d054240321b84c57051175fe3c1e075e",
        strip_prefix = "iovec-0.1.4",
        build_file = Label("//proto/prostgen/raze/remote:iovec-0.1.4.BUILD"),
    )

    _new_http_archive(
        name = "raze__itertools__0_8_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/itertools/itertools-0.8.2.crate",
        type = "tar.gz",
        sha256 = "f56a2d0bc861f9165be4eb3442afd3c236d8a98afd426f65d92324ae1091a484",
        strip_prefix = "itertools-0.8.2",
        build_file = Label("//proto/prostgen/raze/remote:itertools-0.8.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__itoa__0_4_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/itoa/itoa-0.4.6.crate",
        type = "tar.gz",
        sha256 = "dc6f3ad7b9d11a0c00842ff8de1b60ee58661048eb8049ed33c73594f359d7e6",
        strip_prefix = "itoa-0.4.6",
        build_file = Label("//proto/prostgen/raze/remote:itoa-0.4.6.BUILD"),
    )

    _new_http_archive(
        name = "raze__js_sys__0_3_45",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/js-sys/js-sys-0.3.45.crate",
        type = "tar.gz",
        sha256 = "ca059e81d9486668f12d455a4ea6daa600bd408134cd17e3d3fb5a32d1f016f8",
        strip_prefix = "js-sys-0.3.45",
        build_file = Label("//proto/prostgen/raze/remote:js-sys-0.3.45.BUILD"),
    )

    _new_http_archive(
        name = "raze__kernel32_sys__0_2_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/kernel32-sys/kernel32-sys-0.2.2.crate",
        type = "tar.gz",
        sha256 = "7507624b29483431c0ba2d82aece8ca6cdba9382bff4ddd0f7490560c056098d",
        strip_prefix = "kernel32-sys-0.2.2",
        build_file = Label("//proto/prostgen/raze/remote:kernel32-sys-0.2.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__lazy_static__1_4_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/lazy_static/lazy_static-1.4.0.crate",
        type = "tar.gz",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        strip_prefix = "lazy_static-1.4.0",
        build_file = Label("//proto/prostgen/raze/remote:lazy_static-1.4.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__libc__0_2_77",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/libc/libc-0.2.77.crate",
        type = "tar.gz",
        sha256 = "f2f96b10ec2560088a8e76961b00d47107b3a625fecb76dedb29ee7ccbf98235",
        strip_prefix = "libc-0.2.77",
        build_file = Label("//proto/prostgen/raze/remote:libc-0.2.77.BUILD"),
    )

    _new_http_archive(
        name = "raze__log__0_4_11",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/log/log-0.4.11.crate",
        type = "tar.gz",
        sha256 = "4fabed175da42fed1fa0746b0ea71f412aa9d35e76e95e59b192c64b9dc2bf8b",
        strip_prefix = "log-0.4.11",
        build_file = Label("//proto/prostgen/raze/remote:log-0.4.11.BUILD"),
    )

    _new_http_archive(
        name = "raze__memchr__2_3_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/memchr/memchr-2.3.3.crate",
        type = "tar.gz",
        sha256 = "3728d817d99e5ac407411fa471ff9800a778d88a24685968b36824eaf4bee400",
        strip_prefix = "memchr-2.3.3",
        build_file = Label("//proto/prostgen/raze/remote:memchr-2.3.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__mio__0_6_22",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/mio/mio-0.6.22.crate",
        type = "tar.gz",
        sha256 = "fce347092656428bc8eaf6201042cb551b8d67855af7374542a92a0fbfcac430",
        strip_prefix = "mio-0.6.22",
        build_file = Label("//proto/prostgen/raze/remote:mio-0.6.22.BUILD"),
    )

    _new_http_archive(
        name = "raze__miow__0_2_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/miow/miow-0.2.1.crate",
        type = "tar.gz",
        sha256 = "8c1f2f3b1cf331de6896aabf6e9d55dca90356cc9960cca7eaaf408a355ae919",
        strip_prefix = "miow-0.2.1",
        build_file = Label("//proto/prostgen/raze/remote:miow-0.2.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__multimap__0_8_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/multimap/multimap-0.8.2.crate",
        type = "tar.gz",
        sha256 = "1255076139a83bb467426e7f8d0134968a8118844faa755985e077cf31850333",
        strip_prefix = "multimap-0.8.2",
        build_file = Label("//proto/prostgen/raze/remote:multimap-0.8.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__net2__0_2_35",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/net2/net2-0.2.35.crate",
        type = "tar.gz",
        sha256 = "3ebc3ec692ed7c9a255596c67808dee269f64655d8baf7b4f0638e51ba1d6853",
        strip_prefix = "net2-0.2.35",
        build_file = Label("//proto/prostgen/raze/remote:net2-0.2.35.BUILD"),
    )

    _new_http_archive(
        name = "raze__once_cell__1_4_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/once_cell/once_cell-1.4.1.crate",
        type = "tar.gz",
        sha256 = "260e51e7efe62b592207e9e13a68e43692a7a279171d6ba57abd208bf23645ad",
        strip_prefix = "once_cell-1.4.1",
        build_file = Label("//proto/prostgen/raze/remote:once_cell-1.4.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__openssl_probe__0_1_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/openssl-probe/openssl-probe-0.1.2.crate",
        type = "tar.gz",
        sha256 = "77af24da69f9d9341038eba93a073b1fdaaa1b788221b00a69bce9e762cb32de",
        strip_prefix = "openssl-probe-0.1.2",
        build_file = Label("//proto/prostgen/raze/remote:openssl-probe-0.1.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__percent_encoding__2_1_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/percent-encoding/percent-encoding-2.1.0.crate",
        type = "tar.gz",
        sha256 = "d4fd5641d01c8f18a23da7b6fe29298ff4b55afcccdf78973b24cf3175fee32e",
        strip_prefix = "percent-encoding-2.1.0",
        build_file = Label("//proto/prostgen/raze/remote:percent-encoding-2.1.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__petgraph__0_5_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/petgraph/petgraph-0.5.1.crate",
        type = "tar.gz",
        sha256 = "467d164a6de56270bd7c4d070df81d07beace25012d5103ced4e9ff08d6afdb7",
        strip_prefix = "petgraph-0.5.1",
        build_file = Label("//proto/prostgen/raze/remote:petgraph-0.5.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__pin_project__0_4_23",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/pin-project/pin-project-0.4.23.crate",
        type = "tar.gz",
        sha256 = "ca4433fff2ae79342e497d9f8ee990d174071408f28f726d6d83af93e58e48aa",
        strip_prefix = "pin-project-0.4.23",
        build_file = Label("//proto/prostgen/raze/remote:pin-project-0.4.23.BUILD"),
    )

    _new_http_archive(
        name = "raze__pin_project_internal__0_4_23",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/pin-project-internal/pin-project-internal-0.4.23.crate",
        type = "tar.gz",
        sha256 = "2c0e815c3ee9a031fdf5af21c10aa17c573c9c6a566328d99e3936c34e36461f",
        strip_prefix = "pin-project-internal-0.4.23",
        build_file = Label("//proto/prostgen/raze/remote:pin-project-internal-0.4.23.BUILD"),
    )

    _new_http_archive(
        name = "raze__pin_project_lite__0_1_7",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/pin-project-lite/pin-project-lite-0.1.7.crate",
        type = "tar.gz",
        sha256 = "282adbf10f2698a7a77f8e983a74b2d18176c19a7fd32a45446139ae7b02b715",
        strip_prefix = "pin-project-lite-0.1.7",
        build_file = Label("//proto/prostgen/raze/remote:pin-project-lite-0.1.7.BUILD"),
    )

    _new_http_archive(
        name = "raze__pin_utils__0_1_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/pin-utils/pin-utils-0.1.0.crate",
        type = "tar.gz",
        sha256 = "8b870d8c151b6f2fb93e84a13146138f05d02ed11c7e7c54f8826aaaf7c9f184",
        strip_prefix = "pin-utils-0.1.0",
        build_file = Label("//proto/prostgen/raze/remote:pin-utils-0.1.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__ppv_lite86__0_2_9",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/ppv-lite86/ppv-lite86-0.2.9.crate",
        type = "tar.gz",
        sha256 = "c36fa947111f5c62a733b652544dd0016a43ce89619538a8ef92724a6f501a20",
        strip_prefix = "ppv-lite86-0.2.9",
        build_file = Label("//proto/prostgen/raze/remote:ppv-lite86-0.2.9.BUILD"),
    )

    _new_http_archive(
        name = "raze__proc_macro_error__1_0_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/proc-macro-error/proc-macro-error-1.0.2.crate",
        type = "tar.gz",
        sha256 = "98e9e4b82e0ef281812565ea4751049f1bdcdfccda7d3f459f2e138a40c08678",
        strip_prefix = "proc-macro-error-1.0.2",
        build_file = Label("//proto/prostgen/raze/remote:proc-macro-error-1.0.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__proc_macro_error_attr__1_0_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/proc-macro-error-attr/proc-macro-error-attr-1.0.2.crate",
        type = "tar.gz",
        sha256 = "4f5444ead4e9935abd7f27dc51f7e852a0569ac888096d5ec2499470794e2e53",
        strip_prefix = "proc-macro-error-attr-1.0.2",
        build_file = Label("//proto/prostgen/raze/remote:proc-macro-error-attr-1.0.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__proc_macro2__1_0_18",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/proc-macro2/proc-macro2-1.0.18.crate",
        type = "tar.gz",
        sha256 = "beae6331a816b1f65d04c45b078fd8e6c93e8071771f41b8163255bbd8d7c8fa",
        strip_prefix = "proc-macro2-1.0.18",
        build_file = Label("//proto/prostgen/raze/remote:proc-macro2-1.0.18.BUILD"),
    )

    _new_http_archive(
        name = "raze__prost__0_6_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/prost/prost-0.6.1.crate",
        type = "tar.gz",
        sha256 = "ce49aefe0a6144a45de32927c77bd2859a5f7677b55f220ae5b744e87389c212",
        strip_prefix = "prost-0.6.1",
        build_file = Label("//proto/prostgen/raze/remote:prost-0.6.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__prost_build__0_6_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/prost-build/prost-build-0.6.1.crate",
        type = "tar.gz",
        sha256 = "02b10678c913ecbd69350e8535c3aef91a8676c0773fc1d7b95cdd196d7f2f26",
        strip_prefix = "prost-build-0.6.1",
        patches = [
            "//proto/prostgen/raze/patches:prost-build-0.6.1.patch",
        ],
        patch_args = [
            "-p1",
        ],
        build_file = Label("//proto/prostgen/raze/remote:prost-build-0.6.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__prost_derive__0_6_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/prost-derive/prost-derive-0.6.1.crate",
        type = "tar.gz",
        sha256 = "537aa19b95acde10a12fec4301466386f757403de4cd4e5b4fa78fb5ecb18f72",
        strip_prefix = "prost-derive-0.6.1",
        build_file = Label("//proto/prostgen/raze/remote:prost-derive-0.6.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__prost_types__0_6_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/prost-types/prost-types-0.6.1.crate",
        type = "tar.gz",
        sha256 = "1834f67c0697c001304b75be76f67add9c89742eda3a085ad8ee0bb38c3417aa",
        strip_prefix = "prost-types-0.6.1",
        build_file = Label("//proto/prostgen/raze/remote:prost-types-0.6.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__quote__1_0_7",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/quote/quote-1.0.7.crate",
        type = "tar.gz",
        sha256 = "aa563d17ecb180e500da1cfd2b028310ac758de548efdd203e18f283af693f37",
        strip_prefix = "quote-1.0.7",
        build_file = Label("//proto/prostgen/raze/remote:quote-1.0.7.BUILD"),
    )

    _new_http_archive(
        name = "raze__rand__0_7_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rand/rand-0.7.3.crate",
        type = "tar.gz",
        sha256 = "6a6b1679d49b24bbfe0c803429aa1874472f50d9b363131f0e89fc356b544d03",
        strip_prefix = "rand-0.7.3",
        build_file = Label("//proto/prostgen/raze/remote:rand-0.7.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__rand_chacha__0_2_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rand_chacha/rand_chacha-0.2.2.crate",
        type = "tar.gz",
        sha256 = "f4c8ed856279c9737206bf725bf36935d8666ead7aa69b52be55af369d193402",
        strip_prefix = "rand_chacha-0.2.2",
        build_file = Label("//proto/prostgen/raze/remote:rand_chacha-0.2.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__rand_core__0_5_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rand_core/rand_core-0.5.1.crate",
        type = "tar.gz",
        sha256 = "90bde5296fc891b0cef12a6d03ddccc162ce7b2aff54160af9338f8d40df6d19",
        strip_prefix = "rand_core-0.5.1",
        build_file = Label("//proto/prostgen/raze/remote:rand_core-0.5.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__rand_hc__0_2_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rand_hc/rand_hc-0.2.0.crate",
        type = "tar.gz",
        sha256 = "ca3129af7b92a17112d59ad498c6f81eaf463253766b90396d39ea7a39d6613c",
        strip_prefix = "rand_hc-0.2.0",
        build_file = Label("//proto/prostgen/raze/remote:rand_hc-0.2.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__rand_pcg__0_2_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rand_pcg/rand_pcg-0.2.1.crate",
        type = "tar.gz",
        sha256 = "16abd0c1b639e9eb4d7c50c0b8100b0d0f849be2349829c740fe8e6eb4816429",
        strip_prefix = "rand_pcg-0.2.1",
        build_file = Label("//proto/prostgen/raze/remote:rand_pcg-0.2.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__redox_syscall__0_1_57",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/redox_syscall/redox_syscall-0.1.57.crate",
        type = "tar.gz",
        sha256 = "41cc0f7e4d5d4544e8861606a285bb08d3e70712ccc7d2b84d7c0ccfaf4b05ce",
        strip_prefix = "redox_syscall-0.1.57",
        build_file = Label("//proto/prostgen/raze/remote:redox_syscall-0.1.57.BUILD"),
    )

    _new_http_archive(
        name = "raze__remove_dir_all__0_5_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/remove_dir_all/remove_dir_all-0.5.3.crate",
        type = "tar.gz",
        sha256 = "3acd125665422973a33ac9d3dd2df85edad0f4ae9b00dafb1a05e43a9f5ef8e7",
        strip_prefix = "remove_dir_all-0.5.3",
        build_file = Label("//proto/prostgen/raze/remote:remove_dir_all-0.5.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__ring__0_16_15",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/ring/ring-0.16.15.crate",
        type = "tar.gz",
        sha256 = "952cd6b98c85bbc30efa1ba5783b8abf12fec8b3287ffa52605b9432313e34e4",
        strip_prefix = "ring-0.16.15",
        build_file = Label("//proto/prostgen/raze/remote:ring-0.16.15.BUILD"),
    )

    _new_http_archive(
        name = "raze__rustls__0_18_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rustls/rustls-0.18.1.crate",
        type = "tar.gz",
        sha256 = "5d1126dcf58e93cee7d098dbda643b5f92ed724f1f6a63007c1116eed6700c81",
        strip_prefix = "rustls-0.18.1",
        build_file = Label("//proto/prostgen/raze/remote:rustls-0.18.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__rustls_native_certs__0_4_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rustls-native-certs/rustls-native-certs-0.4.0.crate",
        type = "tar.gz",
        sha256 = "629d439a7672da82dd955498445e496ee2096fe2117b9f796558a43fdb9e59b8",
        strip_prefix = "rustls-native-certs-0.4.0",
        build_file = Label("//proto/prostgen/raze/remote:rustls-native-certs-0.4.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__schannel__0_1_19",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/schannel/schannel-0.1.19.crate",
        type = "tar.gz",
        sha256 = "8f05ba609c234e60bee0d547fe94a4c7e9da733d1c962cf6e59efa4cd9c8bc75",
        strip_prefix = "schannel-0.1.19",
        build_file = Label("//proto/prostgen/raze/remote:schannel-0.1.19.BUILD"),
    )

    _new_http_archive(
        name = "raze__sct__0_6_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/sct/sct-0.6.0.crate",
        type = "tar.gz",
        sha256 = "e3042af939fca8c3453b7af0f1c66e533a15a86169e39de2657310ade8f98d3c",
        strip_prefix = "sct-0.6.0",
        build_file = Label("//proto/prostgen/raze/remote:sct-0.6.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__security_framework__1_0_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/security-framework/security-framework-1.0.0.crate",
        type = "tar.gz",
        sha256 = "ad502866817f0575705bd7be36e2b2535cc33262d493aa733a2ec862baa2bc2b",
        strip_prefix = "security-framework-1.0.0",
        build_file = Label("//proto/prostgen/raze/remote:security-framework-1.0.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__security_framework_sys__1_0_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/security-framework-sys/security-framework-sys-1.0.0.crate",
        type = "tar.gz",
        sha256 = "51ceb04988b17b6d1dcd555390fa822ca5637b4a14e1f5099f13d351bed4d6c7",
        strip_prefix = "security-framework-sys-1.0.0",
        build_file = Label("//proto/prostgen/raze/remote:security-framework-sys-1.0.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__slab__0_4_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/slab/slab-0.4.2.crate",
        type = "tar.gz",
        sha256 = "c111b5bd5695e56cffe5129854aa230b39c93a305372fdbb2668ca2394eea9f8",
        strip_prefix = "slab-0.4.2",
        build_file = Label("//proto/prostgen/raze/remote:slab-0.4.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__socket2__0_3_15",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/socket2/socket2-0.3.15.crate",
        type = "tar.gz",
        sha256 = "b1fa70dc5c8104ec096f4fe7ede7a221d35ae13dcd19ba1ad9a81d2cab9a1c44",
        strip_prefix = "socket2-0.3.15",
        build_file = Label("//proto/prostgen/raze/remote:socket2-0.3.15.BUILD"),
    )

    _new_http_archive(
        name = "raze__spin__0_5_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/spin/spin-0.5.2.crate",
        type = "tar.gz",
        sha256 = "6e63cff320ae2c57904679ba7cb63280a3dc4613885beafb148ee7bf9aa9042d",
        strip_prefix = "spin-0.5.2",
        build_file = Label("//proto/prostgen/raze/remote:spin-0.5.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__structopt__0_3_13",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/structopt/structopt-0.3.13.crate",
        type = "tar.gz",
        sha256 = "ff6da2e8d107dfd7b74df5ef4d205c6aebee0706c647f6bc6a2d5789905c00fb",
        strip_prefix = "structopt-0.3.13",
        build_file = Label("//proto/prostgen/raze/remote:structopt-0.3.13.BUILD"),
    )

    _new_http_archive(
        name = "raze__structopt_derive__0_4_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/structopt-derive/structopt-derive-0.4.6.crate",
        type = "tar.gz",
        sha256 = "a489c87c08fbaf12e386665109dd13470dcc9c4583ea3e10dd2b4523e5ebd9ac",
        strip_prefix = "structopt-derive-0.4.6",
        build_file = Label("//proto/prostgen/raze/remote:structopt-derive-0.4.6.BUILD"),
    )

    _new_http_archive(
        name = "raze__syn__1_0_31",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/syn/syn-1.0.31.crate",
        type = "tar.gz",
        sha256 = "b5304cfdf27365b7585c25d4af91b35016ed21ef88f17ced89c7093b43dba8b6",
        strip_prefix = "syn-1.0.31",
        build_file = Label("//proto/prostgen/raze/remote:syn-1.0.31.BUILD"),
    )

    _new_http_archive(
        name = "raze__syn_mid__0_5_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/syn-mid/syn-mid-0.5.0.crate",
        type = "tar.gz",
        sha256 = "7be3539f6c128a931cf19dcee741c1af532c7fd387baa739c03dd2e96479338a",
        strip_prefix = "syn-mid-0.5.0",
        build_file = Label("//proto/prostgen/raze/remote:syn-mid-0.5.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__tempfile__3_1_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tempfile/tempfile-3.1.0.crate",
        type = "tar.gz",
        sha256 = "7a6e24d9338a0a5be79593e2fa15a648add6138caa803e2d5bc782c371732ca9",
        strip_prefix = "tempfile-3.1.0",
        build_file = Label("//proto/prostgen/raze/remote:tempfile-3.1.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__textwrap__0_11_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/textwrap/textwrap-0.11.0.crate",
        type = "tar.gz",
        sha256 = "d326610f408c7a4eb6f51c37c330e496b08506c9457c9d34287ecc38809fb060",
        strip_prefix = "textwrap-0.11.0",
        build_file = Label("//proto/prostgen/raze/remote:textwrap-0.11.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__thiserror__1_0_18",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/thiserror/thiserror-1.0.18.crate",
        type = "tar.gz",
        sha256 = "5976891d6950b4f68477850b5b9e5aa64d955961466f9e174363f573e54e8ca7",
        strip_prefix = "thiserror-1.0.18",
        build_file = Label("//proto/prostgen/raze/remote:thiserror-1.0.18.BUILD"),
    )

    _new_http_archive(
        name = "raze__thiserror_impl__1_0_18",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/thiserror-impl/thiserror-impl-1.0.18.crate",
        type = "tar.gz",
        sha256 = "ab81dbd1cd69cd2ce22ecfbdd3bdb73334ba25350649408cc6c085f46d89573d",
        strip_prefix = "thiserror-impl-1.0.18",
        build_file = Label("//proto/prostgen/raze/remote:thiserror-impl-1.0.18.BUILD"),
    )

    _new_http_archive(
        name = "raze__time__0_1_44",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/time/time-0.1.44.crate",
        type = "tar.gz",
        sha256 = "6db9e6914ab8b1ae1c260a4ae7a49b6c5611b40328a735b21862567685e73255",
        strip_prefix = "time-0.1.44",
        build_file = Label("//proto/prostgen/raze/remote:time-0.1.44.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio__0_2_22",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio/tokio-0.2.22.crate",
        type = "tar.gz",
        sha256 = "5d34ca54d84bf2b5b4d7d31e901a8464f7b60ac145a284fba25ceb801f2ddccd",
        strip_prefix = "tokio-0.2.22",
        build_file = Label("//proto/prostgen/raze/remote:tokio-0.2.22.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_rustls__0_14_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-rustls/tokio-rustls-0.14.1.crate",
        type = "tar.gz",
        sha256 = "e12831b255bcfa39dc0436b01e19fea231a37db570686c06ee72c423479f889a",
        strip_prefix = "tokio-rustls-0.14.1",
        build_file = Label("//proto/prostgen/raze/remote:tokio-rustls-0.14.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_util__0_3_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-util/tokio-util-0.3.1.crate",
        type = "tar.gz",
        sha256 = "be8242891f2b6cbef26a2d7e8605133c2c554cd35b3e4948ea892d6d68436499",
        strip_prefix = "tokio-util-0.3.1",
        build_file = Label("//proto/prostgen/raze/remote:tokio-util-0.3.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__tonic__0_3_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tonic/tonic-0.3.0.crate",
        type = "tar.gz",
        sha256 = "b13b102a19758191af97cff34c6785dffd6610f68de5ab1c4bb8378638e4ef90",
        strip_prefix = "tonic-0.3.0",
        build_file = Label("//proto/prostgen/raze/remote:tonic-0.3.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__tonic_build__0_3_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tonic-build/tonic-build-0.3.0.crate",
        type = "tar.gz",
        sha256 = "daec8b14e55497072204b53d5c0b1eb0a6ad1cd8301d6d4c079d4aeec35b21e9",
        strip_prefix = "tonic-build-0.3.0",
        build_file = Label("//proto/prostgen/raze/remote:tonic-build-0.3.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__tower__0_3_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tower/tower-0.3.1.crate",
        type = "tar.gz",
        sha256 = "fd3169017c090b7a28fce80abaad0ab4f5566423677c9331bb320af7e49cfe62",
        strip_prefix = "tower-0.3.1",
        build_file = Label("//proto/prostgen/raze/remote:tower-0.3.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__tower_balance__0_3_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tower-balance/tower-balance-0.3.0.crate",
        type = "tar.gz",
        sha256 = "a792277613b7052448851efcf98a2c433e6f1d01460832dc60bef676bc275d4c",
        strip_prefix = "tower-balance-0.3.0",
        build_file = Label("//proto/prostgen/raze/remote:tower-balance-0.3.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__tower_buffer__0_3_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tower-buffer/tower-buffer-0.3.0.crate",
        type = "tar.gz",
        sha256 = "c4887dc2a65d464c8b9b66e0e4d51c2fd6cf5b3373afc72805b0a60bce00446a",
        strip_prefix = "tower-buffer-0.3.0",
        build_file = Label("//proto/prostgen/raze/remote:tower-buffer-0.3.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__tower_discover__0_3_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tower-discover/tower-discover-0.3.0.crate",
        type = "tar.gz",
        sha256 = "0f6b5000c3c54d269cc695dff28136bb33d08cbf1df2c48129e143ab65bf3c2a",
        strip_prefix = "tower-discover-0.3.0",
        build_file = Label("//proto/prostgen/raze/remote:tower-discover-0.3.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__tower_layer__0_3_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tower-layer/tower-layer-0.3.0.crate",
        type = "tar.gz",
        sha256 = "a35d656f2638b288b33495d1053ea74c40dc05ec0b92084dd71ca5566c4ed1dc",
        strip_prefix = "tower-layer-0.3.0",
        build_file = Label("//proto/prostgen/raze/remote:tower-layer-0.3.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__tower_limit__0_3_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tower-limit/tower-limit-0.3.1.crate",
        type = "tar.gz",
        sha256 = "92c3040c5dbed68abffaa0d4517ac1a454cd741044f33ab0eefab6b8d1361404",
        strip_prefix = "tower-limit-0.3.1",
        build_file = Label("//proto/prostgen/raze/remote:tower-limit-0.3.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__tower_load__0_3_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tower-load/tower-load-0.3.0.crate",
        type = "tar.gz",
        sha256 = "8cc79fc3afd07492b7966d7efa7c6c50f8ed58d768a6075dd7ae6591c5d2017b",
        strip_prefix = "tower-load-0.3.0",
        build_file = Label("//proto/prostgen/raze/remote:tower-load-0.3.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__tower_load_shed__0_3_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tower-load-shed/tower-load-shed-0.3.0.crate",
        type = "tar.gz",
        sha256 = "9f021e23900173dc315feb4b6922510dae3e79c689b74c089112066c11f0ae4e",
        strip_prefix = "tower-load-shed-0.3.0",
        build_file = Label("//proto/prostgen/raze/remote:tower-load-shed-0.3.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__tower_make__0_3_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tower-make/tower-make-0.3.0.crate",
        type = "tar.gz",
        sha256 = "ce50370d644a0364bf4877ffd4f76404156a248d104e2cc234cd391ea5cdc965",
        strip_prefix = "tower-make-0.3.0",
        build_file = Label("//proto/prostgen/raze/remote:tower-make-0.3.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__tower_ready_cache__0_3_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tower-ready-cache/tower-ready-cache-0.3.1.crate",
        type = "tar.gz",
        sha256 = "4eabb6620e5481267e2ec832c780b31cad0c15dcb14ed825df5076b26b591e1f",
        strip_prefix = "tower-ready-cache-0.3.1",
        build_file = Label("//proto/prostgen/raze/remote:tower-ready-cache-0.3.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__tower_retry__0_3_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tower-retry/tower-retry-0.3.0.crate",
        type = "tar.gz",
        sha256 = "e6727956aaa2f8957d4d9232b308fe8e4e65d99db30f42b225646e86c9b6a952",
        strip_prefix = "tower-retry-0.3.0",
        build_file = Label("//proto/prostgen/raze/remote:tower-retry-0.3.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__tower_service__0_3_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tower-service/tower-service-0.3.0.crate",
        type = "tar.gz",
        sha256 = "e987b6bf443f4b5b3b6f38704195592cca41c5bb7aedd3c3693c7081f8289860",
        strip_prefix = "tower-service-0.3.0",
        build_file = Label("//proto/prostgen/raze/remote:tower-service-0.3.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__tower_timeout__0_3_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tower-timeout/tower-timeout-0.3.0.crate",
        type = "tar.gz",
        sha256 = "127b8924b357be938823eaaec0608c482d40add25609481027b96198b2e4b31e",
        strip_prefix = "tower-timeout-0.3.0",
        build_file = Label("//proto/prostgen/raze/remote:tower-timeout-0.3.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__tower_util__0_3_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tower-util/tower-util-0.3.1.crate",
        type = "tar.gz",
        sha256 = "d1093c19826d33807c72511e68f73b4a0469a3f22c2bd5f7d5212178b4b89674",
        strip_prefix = "tower-util-0.3.1",
        build_file = Label("//proto/prostgen/raze/remote:tower-util-0.3.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__tracing__0_1_19",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tracing/tracing-0.1.19.crate",
        type = "tar.gz",
        sha256 = "6d79ca061b032d6ce30c660fded31189ca0b9922bf483cd70759f13a2d86786c",
        strip_prefix = "tracing-0.1.19",
        build_file = Label("//proto/prostgen/raze/remote:tracing-0.1.19.BUILD"),
    )

    _new_http_archive(
        name = "raze__tracing_attributes__0_1_11",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tracing-attributes/tracing-attributes-0.1.11.crate",
        type = "tar.gz",
        sha256 = "80e0ccfc3378da0cce270c946b676a376943f5cd16aeba64568e7939806f4ada",
        strip_prefix = "tracing-attributes-0.1.11",
        build_file = Label("//proto/prostgen/raze/remote:tracing-attributes-0.1.11.BUILD"),
    )

    _new_http_archive(
        name = "raze__tracing_core__0_1_16",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tracing-core/tracing-core-0.1.16.crate",
        type = "tar.gz",
        sha256 = "5bcf46c1f1f06aeea2d6b81f3c863d0930a596c86ad1920d4e5bad6dd1d7119a",
        strip_prefix = "tracing-core-0.1.16",
        build_file = Label("//proto/prostgen/raze/remote:tracing-core-0.1.16.BUILD"),
    )

    _new_http_archive(
        name = "raze__tracing_futures__0_2_4",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tracing-futures/tracing-futures-0.2.4.crate",
        type = "tar.gz",
        sha256 = "ab7bb6f14721aa00656086e9335d363c5c8747bae02ebe32ea2c7dece5689b4c",
        strip_prefix = "tracing-futures-0.2.4",
        build_file = Label("//proto/prostgen/raze/remote:tracing-futures-0.2.4.BUILD"),
    )

    _new_http_archive(
        name = "raze__try_lock__0_2_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/try-lock/try-lock-0.2.3.crate",
        type = "tar.gz",
        sha256 = "59547bce71d9c38b83d9c0e92b6066c4253371f15005def0c30d9657f50c7642",
        strip_prefix = "try-lock-0.2.3",
        build_file = Label("//proto/prostgen/raze/remote:try-lock-0.2.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__unicode_segmentation__1_6_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/unicode-segmentation/unicode-segmentation-1.6.0.crate",
        type = "tar.gz",
        sha256 = "e83e153d1053cbb5a118eeff7fd5be06ed99153f00dbcd8ae310c5fb2b22edc0",
        strip_prefix = "unicode-segmentation-1.6.0",
        build_file = Label("//proto/prostgen/raze/remote:unicode-segmentation-1.6.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__unicode_width__0_1_8",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/unicode-width/unicode-width-0.1.8.crate",
        type = "tar.gz",
        sha256 = "9337591893a19b88d8d87f2cec1e73fad5cdfd10e5a6f349f498ad6ea2ffb1e3",
        strip_prefix = "unicode-width-0.1.8",
        build_file = Label("//proto/prostgen/raze/remote:unicode-width-0.1.8.BUILD"),
    )

    _new_http_archive(
        name = "raze__unicode_xid__0_2_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/unicode-xid/unicode-xid-0.2.1.crate",
        type = "tar.gz",
        sha256 = "f7fe0bb3479651439c9112f72b6c505038574c9fbb575ed1bf3b797fa39dd564",
        strip_prefix = "unicode-xid-0.2.1",
        build_file = Label("//proto/prostgen/raze/remote:unicode-xid-0.2.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__untrusted__0_7_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/untrusted/untrusted-0.7.1.crate",
        type = "tar.gz",
        sha256 = "a156c684c91ea7d62626509bce3cb4e1d9ed5c4d978f7b4352658f96a4c26b4a",
        strip_prefix = "untrusted-0.7.1",
        build_file = Label("//proto/prostgen/raze/remote:untrusted-0.7.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__version_check__0_9_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/version_check/version_check-0.9.2.crate",
        type = "tar.gz",
        sha256 = "b5a972e5669d67ba988ce3dc826706fb0a8b01471c088cb0b6110b805cc36aed",
        strip_prefix = "version_check-0.9.2",
        build_file = Label("//proto/prostgen/raze/remote:version_check-0.9.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__want__0_3_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/want/want-0.3.0.crate",
        type = "tar.gz",
        sha256 = "1ce8a968cb1cd110d136ff8b819a556d6fb6d919363c61534f6860c7eb172ba0",
        strip_prefix = "want-0.3.0",
        build_file = Label("//proto/prostgen/raze/remote:want-0.3.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__wasi__0_10_0_wasi_snapshot_preview1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/wasi/wasi-0.10.0+wasi-snapshot-preview1.crate",
        type = "tar.gz",
        sha256 = "1a143597ca7c7793eff794def352d41792a93c481eb1042423ff7ff72ba2c31f",
        strip_prefix = "wasi-0.10.0+wasi-snapshot-preview1",
        build_file = Label("//proto/prostgen/raze/remote:wasi-0.10.0+wasi-snapshot-preview1.BUILD"),
    )

    _new_http_archive(
        name = "raze__wasi__0_9_0_wasi_snapshot_preview1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/wasi/wasi-0.9.0+wasi-snapshot-preview1.crate",
        type = "tar.gz",
        sha256 = "cccddf32554fecc6acb585f82a32a72e28b48f8c4c1883ddfeeeaa96f7d8e519",
        strip_prefix = "wasi-0.9.0+wasi-snapshot-preview1",
        build_file = Label("//proto/prostgen/raze/remote:wasi-0.9.0+wasi-snapshot-preview1.BUILD"),
    )

    _new_http_archive(
        name = "raze__wasm_bindgen__0_2_68",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/wasm-bindgen/wasm-bindgen-0.2.68.crate",
        type = "tar.gz",
        sha256 = "1ac64ead5ea5f05873d7c12b545865ca2b8d28adfc50a49b84770a3a97265d42",
        strip_prefix = "wasm-bindgen-0.2.68",
        build_file = Label("//proto/prostgen/raze/remote:wasm-bindgen-0.2.68.BUILD"),
    )

    _new_http_archive(
        name = "raze__wasm_bindgen_backend__0_2_68",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/wasm-bindgen-backend/wasm-bindgen-backend-0.2.68.crate",
        type = "tar.gz",
        sha256 = "f22b422e2a757c35a73774860af8e112bff612ce6cb604224e8e47641a9e4f68",
        strip_prefix = "wasm-bindgen-backend-0.2.68",
        build_file = Label("//proto/prostgen/raze/remote:wasm-bindgen-backend-0.2.68.BUILD"),
    )

    _new_http_archive(
        name = "raze__wasm_bindgen_macro__0_2_68",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/wasm-bindgen-macro/wasm-bindgen-macro-0.2.68.crate",
        type = "tar.gz",
        sha256 = "6b13312a745c08c469f0b292dd2fcd6411dba5f7160f593da6ef69b64e407038",
        strip_prefix = "wasm-bindgen-macro-0.2.68",
        build_file = Label("//proto/prostgen/raze/remote:wasm-bindgen-macro-0.2.68.BUILD"),
    )

    _new_http_archive(
        name = "raze__wasm_bindgen_macro_support__0_2_68",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/wasm-bindgen-macro-support/wasm-bindgen-macro-support-0.2.68.crate",
        type = "tar.gz",
        sha256 = "f249f06ef7ee334cc3b8ff031bfc11ec99d00f34d86da7498396dc1e3b1498fe",
        strip_prefix = "wasm-bindgen-macro-support-0.2.68",
        build_file = Label("//proto/prostgen/raze/remote:wasm-bindgen-macro-support-0.2.68.BUILD"),
    )

    _new_http_archive(
        name = "raze__wasm_bindgen_shared__0_2_68",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/wasm-bindgen-shared/wasm-bindgen-shared-0.2.68.crate",
        type = "tar.gz",
        sha256 = "1d649a3145108d7d3fbcde896a468d1bd636791823c9921135218ad89be08307",
        strip_prefix = "wasm-bindgen-shared-0.2.68",
        build_file = Label("//proto/prostgen/raze/remote:wasm-bindgen-shared-0.2.68.BUILD"),
    )

    _new_http_archive(
        name = "raze__web_sys__0_3_45",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/web-sys/web-sys-0.3.45.crate",
        type = "tar.gz",
        sha256 = "4bf6ef87ad7ae8008e15a355ce696bed26012b7caa21605188cfd8214ab51e2d",
        strip_prefix = "web-sys-0.3.45",
        build_file = Label("//proto/prostgen/raze/remote:web-sys-0.3.45.BUILD"),
    )

    _new_http_archive(
        name = "raze__webpki__0_21_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/webpki/webpki-0.21.3.crate",
        type = "tar.gz",
        sha256 = "ab146130f5f790d45f82aeeb09e55a256573373ec64409fc19a6fb82fb1032ae",
        strip_prefix = "webpki-0.21.3",
        build_file = Label("//proto/prostgen/raze/remote:webpki-0.21.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__which__3_1_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/which/which-3.1.1.crate",
        type = "tar.gz",
        sha256 = "d011071ae14a2f6671d0b74080ae0cd8ebf3a6f8c9589a2cd45f23126fe29724",
        strip_prefix = "which-3.1.1",
        build_file = Label("//proto/prostgen/raze/remote:which-3.1.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__winapi__0_2_8",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi/winapi-0.2.8.crate",
        type = "tar.gz",
        sha256 = "167dc9d6949a9b857f3451275e911c3f44255842c1f7a76f33c55103a909087a",
        strip_prefix = "winapi-0.2.8",
        build_file = Label("//proto/prostgen/raze/remote:winapi-0.2.8.BUILD"),
    )

    _new_http_archive(
        name = "raze__winapi__0_3_9",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi/winapi-0.3.9.crate",
        type = "tar.gz",
        sha256 = "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419",
        strip_prefix = "winapi-0.3.9",
        build_file = Label("//proto/prostgen/raze/remote:winapi-0.3.9.BUILD"),
    )

    _new_http_archive(
        name = "raze__winapi_build__0_1_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi-build/winapi-build-0.1.1.crate",
        type = "tar.gz",
        sha256 = "2d315eee3b34aca4797b2da6b13ed88266e6d612562a0c46390af8299fc699bc",
        strip_prefix = "winapi-build-0.1.1",
        build_file = Label("//proto/prostgen/raze/remote:winapi-build-0.1.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__winapi_i686_pc_windows_gnu__0_4_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi-i686-pc-windows-gnu/winapi-i686-pc-windows-gnu-0.4.0.crate",
        type = "tar.gz",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("//proto/prostgen/raze/remote:winapi-i686-pc-windows-gnu-0.4.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__winapi_x86_64_pc_windows_gnu__0_4_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi-x86_64-pc-windows-gnu/winapi-x86_64-pc-windows-gnu-0.4.0.crate",
        type = "tar.gz",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("//proto/prostgen/raze/remote:winapi-x86_64-pc-windows-gnu-0.4.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__ws2_32_sys__0_2_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/ws2_32-sys/ws2_32-sys-0.2.1.crate",
        type = "tar.gz",
        sha256 = "d59cefebd0c892fa2dd6de581e937301d8552cb44489cdff035c6187cb63fa5e",
        strip_prefix = "ws2_32-sys-0.2.1",
        build_file = Label("//proto/prostgen/raze/remote:ws2_32-sys-0.2.1.BUILD"),
    )

