"""
@generated
cargo-raze generated Bazel file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

def rules_rust_prostgen_fetch_remote_crates():
    """This function defines a collection of repos and should be called in a WORKSPACE file"""
    maybe(
        http_archive,
        name = "rules_rust_prostgen__anyhow__1_0_38",
        url = "https://crates.io/api/v1/crates/anyhow/1.0.38/download",
        type = "tar.gz",
        sha256 = "afddf7f520a80dbf76e6f50a35bca42a2331ef227a28b3b6dc5c2e2338d114b1",
        strip_prefix = "anyhow-1.0.38",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.anyhow-1.0.38.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__async_stream__0_3_1",
        url = "https://crates.io/api/v1/crates/async-stream/0.3.1/download",
        type = "tar.gz",
        sha256 = "0a26cb53174ddd320edfff199a853f93d571f48eeb4dde75e67a9a3dbb7b7e5e",
        strip_prefix = "async-stream-0.3.1",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.async-stream-0.3.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__async_stream_impl__0_3_1",
        url = "https://crates.io/api/v1/crates/async-stream-impl/0.3.1/download",
        type = "tar.gz",
        sha256 = "db134ba52475c060f3329a8ef0f8786d6b872ed01515d4b79c162e5798da1340",
        strip_prefix = "async-stream-impl-0.3.1",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.async-stream-impl-0.3.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__async_trait__0_1_50",
        url = "https://crates.io/api/v1/crates/async-trait/0.1.50/download",
        type = "tar.gz",
        sha256 = "0b98e84bbb4cbcdd97da190ba0c58a1bb0de2c1fdf67d159e192ed766aeca722",
        strip_prefix = "async-trait-0.1.50",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.async-trait-0.1.50.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__autocfg__1_0_1",
        url = "https://crates.io/api/v1/crates/autocfg/1.0.1/download",
        type = "tar.gz",
        sha256 = "cdb031dd78e28731d87d56cc8ffef4a8f36ca26c38fe2de700543e627f8a464a",
        strip_prefix = "autocfg-1.0.1",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.autocfg-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__base64__0_13_0",
        url = "https://crates.io/api/v1/crates/base64/0.13.0/download",
        type = "tar.gz",
        sha256 = "904dfeac50f3cdaba28fc6f57fdcddb75f49ed61346676a78c4ffe55877802fd",
        strip_prefix = "base64-0.13.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.base64-0.13.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__bitflags__1_2_1",
        url = "https://crates.io/api/v1/crates/bitflags/1.2.1/download",
        type = "tar.gz",
        sha256 = "cf1de2fe8c75bc145a2f577add951f8134889b4795d47466a54a5c846d691693",
        strip_prefix = "bitflags-1.2.1",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.bitflags-1.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__bumpalo__3_6_1",
        url = "https://crates.io/api/v1/crates/bumpalo/3.6.1/download",
        type = "tar.gz",
        sha256 = "63396b8a4b9de3f4fdfb320ab6080762242f66a8ef174c49d8e19b674db4cdbe",
        strip_prefix = "bumpalo-3.6.1",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.bumpalo-3.6.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__bytes__1_0_1",
        url = "https://crates.io/api/v1/crates/bytes/1.0.1/download",
        type = "tar.gz",
        sha256 = "b700ce4376041dcd0a327fd0097c41095743c4c8af8887265942faf1100bd040",
        strip_prefix = "bytes-1.0.1",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.bytes-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__cc__1_0_67",
        url = "https://crates.io/api/v1/crates/cc/1.0.67/download",
        type = "tar.gz",
        sha256 = "e3c69b077ad434294d3ce9f1f6143a2a4b89a8a2d54ef813d85003a4fd1137fd",
        strip_prefix = "cc-1.0.67",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.cc-1.0.67.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__cfg_if__1_0_0",
        url = "https://crates.io/api/v1/crates/cfg-if/1.0.0/download",
        type = "tar.gz",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__clap__2_33_3",
        url = "https://crates.io/api/v1/crates/clap/2.33.3/download",
        type = "tar.gz",
        sha256 = "37e58ac78573c40708d45522f0d80fa2f01cc4f9b4e2bf749807255454312002",
        strip_prefix = "clap-2.33.3",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.clap-2.33.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__core_foundation__0_9_1",
        url = "https://crates.io/api/v1/crates/core-foundation/0.9.1/download",
        type = "tar.gz",
        sha256 = "0a89e2ae426ea83155dccf10c0fa6b1463ef6d5fcb44cee0b224a408fa640a62",
        strip_prefix = "core-foundation-0.9.1",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.core-foundation-0.9.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__core_foundation_sys__0_8_2",
        url = "https://crates.io/api/v1/crates/core-foundation-sys/0.8.2/download",
        type = "tar.gz",
        sha256 = "ea221b5284a47e40033bf9b66f35f984ec0ea2931eb03505246cd27a963f981b",
        strip_prefix = "core-foundation-sys-0.8.2",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.core-foundation-sys-0.8.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__either__1_6_1",
        url = "https://crates.io/api/v1/crates/either/1.6.1/download",
        type = "tar.gz",
        sha256 = "e78d4f1cc4ae33bbfc157ed5d5a5ef3bc29227303d595861deb238fcec4e9457",
        strip_prefix = "either-1.6.1",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.either-1.6.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__fixedbitset__0_2_0",
        url = "https://crates.io/api/v1/crates/fixedbitset/0.2.0/download",
        type = "tar.gz",
        sha256 = "37ab347416e802de484e4d03c7316c48f1ecb56574dfd4a46a80f173ce1de04d",
        strip_prefix = "fixedbitset-0.2.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.fixedbitset-0.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__fnv__1_0_7",
        url = "https://crates.io/api/v1/crates/fnv/1.0.7/download",
        type = "tar.gz",
        sha256 = "3f9eec918d3f24069decb9af1554cad7c880e2da24a9afd88aca000531ab82c1",
        strip_prefix = "fnv-1.0.7",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.fnv-1.0.7.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__futures_channel__0_3_14",
        url = "https://crates.io/api/v1/crates/futures-channel/0.3.14/download",
        type = "tar.gz",
        sha256 = "ce79c6a52a299137a6013061e0cf0e688fce5d7f1bc60125f520912fdb29ec25",
        strip_prefix = "futures-channel-0.3.14",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.futures-channel-0.3.14.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__futures_core__0_3_14",
        url = "https://crates.io/api/v1/crates/futures-core/0.3.14/download",
        type = "tar.gz",
        sha256 = "098cd1c6dda6ca01650f1a37a794245eb73181d0d4d4e955e2f3c37db7af1815",
        strip_prefix = "futures-core-0.3.14",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.futures-core-0.3.14.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__futures_sink__0_3_14",
        url = "https://crates.io/api/v1/crates/futures-sink/0.3.14/download",
        type = "tar.gz",
        sha256 = "5c5629433c555de3d82861a7a4e3794a4c40040390907cfbfd7143a92a426c23",
        strip_prefix = "futures-sink-0.3.14",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.futures-sink-0.3.14.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__futures_task__0_3_14",
        url = "https://crates.io/api/v1/crates/futures-task/0.3.14/download",
        type = "tar.gz",
        sha256 = "ba7aa51095076f3ba6d9a1f702f74bd05ec65f555d70d2033d55ba8d69f581bc",
        strip_prefix = "futures-task-0.3.14",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.futures-task-0.3.14.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__futures_util__0_3_14",
        url = "https://crates.io/api/v1/crates/futures-util/0.3.14/download",
        type = "tar.gz",
        sha256 = "3c144ad54d60f23927f0a6b6d816e4271278b64f005ad65e4e35291d2de9c025",
        strip_prefix = "futures-util-0.3.14",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.futures-util-0.3.14.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__getrandom__0_2_2",
        url = "https://crates.io/api/v1/crates/getrandom/0.2.2/download",
        type = "tar.gz",
        sha256 = "c9495705279e7140bf035dde1f6e750c162df8b625267cd52cc44e0b156732c8",
        strip_prefix = "getrandom-0.2.2",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.getrandom-0.2.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__h2__0_3_2",
        url = "https://crates.io/api/v1/crates/h2/0.3.2/download",
        type = "tar.gz",
        sha256 = "fc018e188373e2777d0ef2467ebff62a08e66c3f5857b23c8fbec3018210dc00",
        strip_prefix = "h2-0.3.2",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.h2-0.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__hashbrown__0_9_1",
        url = "https://crates.io/api/v1/crates/hashbrown/0.9.1/download",
        type = "tar.gz",
        sha256 = "d7afe4a420e3fe79967a00898cc1f4db7c8a49a9333a29f8a4bd76a253d5cd04",
        strip_prefix = "hashbrown-0.9.1",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.hashbrown-0.9.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__heck__0_3_2",
        url = "https://crates.io/api/v1/crates/heck/0.3.2/download",
        type = "tar.gz",
        sha256 = "87cbf45460356b7deeb5e3415b5563308c0a9b057c85e12b06ad551f98d0a6ac",
        strip_prefix = "heck-0.3.2",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.heck-0.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__http__0_2_4",
        url = "https://crates.io/api/v1/crates/http/0.2.4/download",
        type = "tar.gz",
        sha256 = "527e8c9ac747e28542699a951517aa9a6945af506cd1f2e1b53a576c17b6cc11",
        strip_prefix = "http-0.2.4",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.http-0.2.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__http_body__0_4_1",
        url = "https://crates.io/api/v1/crates/http-body/0.4.1/download",
        type = "tar.gz",
        sha256 = "5dfb77c123b4e2f72a2069aeae0b4b4949cc7e966df277813fc16347e7549737",
        strip_prefix = "http-body-0.4.1",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.http-body-0.4.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__httparse__1_4_0",
        url = "https://crates.io/api/v1/crates/httparse/1.4.0/download",
        type = "tar.gz",
        sha256 = "4a1ce40d6fc9764887c2fdc7305c3dcc429ba11ff981c1509416afd5697e4437",
        strip_prefix = "httparse-1.4.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.httparse-1.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__httpdate__1_0_0",
        url = "https://crates.io/api/v1/crates/httpdate/1.0.0/download",
        type = "tar.gz",
        sha256 = "05842d0d43232b23ccb7060ecb0f0626922c21f30012e97b767b30afd4a5d4b9",
        strip_prefix = "httpdate-1.0.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.httpdate-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__hyper__0_14_7",
        url = "https://crates.io/api/v1/crates/hyper/0.14.7/download",
        type = "tar.gz",
        sha256 = "1e5f105c494081baa3bf9e200b279e27ec1623895cd504c7dbef8d0b080fcf54",
        strip_prefix = "hyper-0.14.7",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.hyper-0.14.7.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__indexmap__1_6_2",
        url = "https://crates.io/api/v1/crates/indexmap/1.6.2/download",
        type = "tar.gz",
        sha256 = "824845a0bf897a9042383849b02c1bc219c2383772efcd5c6f9766fa4b81aef3",
        strip_prefix = "indexmap-1.6.2",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.indexmap-1.6.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__itertools__0_9_0",
        url = "https://crates.io/api/v1/crates/itertools/0.9.0/download",
        type = "tar.gz",
        sha256 = "284f18f85651fe11e8a991b2adb42cb078325c996ed026d994719efcfca1d54b",
        strip_prefix = "itertools-0.9.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.itertools-0.9.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__itoa__0_4_7",
        url = "https://crates.io/api/v1/crates/itoa/0.4.7/download",
        type = "tar.gz",
        sha256 = "dd25036021b0de88a0aff6b850051563c6516d0bf53f8638938edbb9de732736",
        strip_prefix = "itoa-0.4.7",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.itoa-0.4.7.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__js_sys__0_3_50",
        url = "https://crates.io/api/v1/crates/js-sys/0.3.50/download",
        type = "tar.gz",
        sha256 = "2d99f9e3e84b8f67f846ef5b4cbbc3b1c29f6c759fcbce6f01aa0e73d932a24c",
        strip_prefix = "js-sys-0.3.50",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.js-sys-0.3.50.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__lazy_static__1_4_0",
        url = "https://crates.io/api/v1/crates/lazy_static/1.4.0/download",
        type = "tar.gz",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        strip_prefix = "lazy_static-1.4.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.lazy_static-1.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__libc__0_2_94",
        url = "https://crates.io/api/v1/crates/libc/0.2.94/download",
        type = "tar.gz",
        sha256 = "18794a8ad5b29321f790b55d93dfba91e125cb1a9edbd4f8e3150acc771c1a5e",
        strip_prefix = "libc-0.2.94",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.libc-0.2.94.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__log__0_4_14",
        url = "https://crates.io/api/v1/crates/log/0.4.14/download",
        type = "tar.gz",
        sha256 = "51b9bbe6c47d51fc3e1a9b945965946b4c44142ab8792c50835a980d362c2710",
        strip_prefix = "log-0.4.14",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.log-0.4.14.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__memchr__2_3_4",
        url = "https://crates.io/api/v1/crates/memchr/2.3.4/download",
        type = "tar.gz",
        sha256 = "0ee1c47aaa256ecabcaea351eae4a9b01ef39ed810004e298d2511ed284b1525",
        strip_prefix = "memchr-2.3.4",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.memchr-2.3.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__mio__0_7_11",
        url = "https://crates.io/api/v1/crates/mio/0.7.11/download",
        type = "tar.gz",
        sha256 = "cf80d3e903b34e0bd7282b218398aec54e082c840d9baf8339e0080a0c542956",
        strip_prefix = "mio-0.7.11",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.mio-0.7.11.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__miow__0_3_7",
        url = "https://crates.io/api/v1/crates/miow/0.3.7/download",
        type = "tar.gz",
        sha256 = "b9f1c5b025cda876f66ef43a113f91ebc9f4ccef34843000e0adf6ebbab84e21",
        strip_prefix = "miow-0.3.7",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.miow-0.3.7.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__multimap__0_8_3",
        url = "https://crates.io/api/v1/crates/multimap/0.8.3/download",
        type = "tar.gz",
        sha256 = "e5ce46fe64a9d73be07dcbe690a38ce1b293be448fd8ce1e6c1b8062c9f72c6a",
        strip_prefix = "multimap-0.8.3",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.multimap-0.8.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__ntapi__0_3_6",
        url = "https://crates.io/api/v1/crates/ntapi/0.3.6/download",
        type = "tar.gz",
        sha256 = "3f6bb902e437b6d86e03cce10a7e2af662292c5dfef23b65899ea3ac9354ad44",
        strip_prefix = "ntapi-0.3.6",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.ntapi-0.3.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__once_cell__1_7_2",
        url = "https://crates.io/api/v1/crates/once_cell/1.7.2/download",
        type = "tar.gz",
        sha256 = "af8b08b04175473088b46763e51ee54da5f9a164bc162f615b91bc179dbf15a3",
        strip_prefix = "once_cell-1.7.2",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.once_cell-1.7.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__openssl_probe__0_1_2",
        url = "https://crates.io/api/v1/crates/openssl-probe/0.1.2/download",
        type = "tar.gz",
        sha256 = "77af24da69f9d9341038eba93a073b1fdaaa1b788221b00a69bce9e762cb32de",
        strip_prefix = "openssl-probe-0.1.2",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.openssl-probe-0.1.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__percent_encoding__2_1_0",
        url = "https://crates.io/api/v1/crates/percent-encoding/2.1.0/download",
        type = "tar.gz",
        sha256 = "d4fd5641d01c8f18a23da7b6fe29298ff4b55afcccdf78973b24cf3175fee32e",
        strip_prefix = "percent-encoding-2.1.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.percent-encoding-2.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__petgraph__0_5_1",
        url = "https://crates.io/api/v1/crates/petgraph/0.5.1/download",
        type = "tar.gz",
        sha256 = "467d164a6de56270bd7c4d070df81d07beace25012d5103ced4e9ff08d6afdb7",
        strip_prefix = "petgraph-0.5.1",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.petgraph-0.5.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__pin_project__1_0_7",
        url = "https://crates.io/api/v1/crates/pin-project/1.0.7/download",
        type = "tar.gz",
        sha256 = "c7509cc106041c40a4518d2af7a61530e1eed0e6285296a3d8c5472806ccc4a4",
        strip_prefix = "pin-project-1.0.7",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.pin-project-1.0.7.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__pin_project_internal__1_0_7",
        url = "https://crates.io/api/v1/crates/pin-project-internal/1.0.7/download",
        type = "tar.gz",
        sha256 = "48c950132583b500556b1efd71d45b319029f2b71518d979fcc208e16b42426f",
        strip_prefix = "pin-project-internal-1.0.7",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.pin-project-internal-1.0.7.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__pin_project_lite__0_2_6",
        url = "https://crates.io/api/v1/crates/pin-project-lite/0.2.6/download",
        type = "tar.gz",
        sha256 = "dc0e1f259c92177c30a4c9d177246edd0a3568b25756a977d0632cf8fa37e905",
        strip_prefix = "pin-project-lite-0.2.6",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.pin-project-lite-0.2.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__pin_utils__0_1_0",
        url = "https://crates.io/api/v1/crates/pin-utils/0.1.0/download",
        type = "tar.gz",
        sha256 = "8b870d8c151b6f2fb93e84a13146138f05d02ed11c7e7c54f8826aaaf7c9f184",
        strip_prefix = "pin-utils-0.1.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.pin-utils-0.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__ppv_lite86__0_2_10",
        url = "https://crates.io/api/v1/crates/ppv-lite86/0.2.10/download",
        type = "tar.gz",
        sha256 = "ac74c624d6b2d21f425f752262f42188365d7b8ff1aff74c82e45136510a4857",
        strip_prefix = "ppv-lite86-0.2.10",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.ppv-lite86-0.2.10.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__proc_macro_error__1_0_4",
        url = "https://crates.io/api/v1/crates/proc-macro-error/1.0.4/download",
        type = "tar.gz",
        sha256 = "da25490ff9892aab3fcf7c36f08cfb902dd3e71ca0f9f9517bea02a73a5ce38c",
        strip_prefix = "proc-macro-error-1.0.4",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.proc-macro-error-1.0.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__proc_macro_error_attr__1_0_4",
        url = "https://crates.io/api/v1/crates/proc-macro-error-attr/1.0.4/download",
        type = "tar.gz",
        sha256 = "a1be40180e52ecc98ad80b184934baf3d0d29f979574e439af5a55274b35f869",
        strip_prefix = "proc-macro-error-attr-1.0.4",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.proc-macro-error-attr-1.0.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__proc_macro2__1_0_26",
        url = "https://crates.io/api/v1/crates/proc-macro2/1.0.26/download",
        type = "tar.gz",
        sha256 = "a152013215dca273577e18d2bf00fa862b89b24169fb78c4c95aeb07992c9cec",
        strip_prefix = "proc-macro2-1.0.26",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.proc-macro2-1.0.26.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__prost__0_7_0",
        url = "https://crates.io/api/v1/crates/prost/0.7.0/download",
        type = "tar.gz",
        sha256 = "9e6984d2f1a23009bd270b8bb56d0926810a3d483f59c987d77969e9d8e840b2",
        strip_prefix = "prost-0.7.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.prost-0.7.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__prost_build__0_7_0",
        url = "https://crates.io/api/v1/crates/prost-build/0.7.0/download",
        type = "tar.gz",
        sha256 = "32d3ebd75ac2679c2af3a92246639f9fcc8a442ee420719cc4fe195b98dd5fa3",
        strip_prefix = "prost-build-0.7.0",
        patches = [
            "@rules_rust//proto/prostgen/raze/patches:prost-build-0.7.0.patch",
        ],
        patch_args = [
            "-p1",
        ],
        build_file = Label("//proto/prostgen/raze/remote:BUILD.prost-build-0.7.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__prost_derive__0_7_0",
        url = "https://crates.io/api/v1/crates/prost-derive/0.7.0/download",
        type = "tar.gz",
        sha256 = "169a15f3008ecb5160cba7d37bcd690a7601b6d30cfb87a117d45e59d52af5d4",
        strip_prefix = "prost-derive-0.7.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.prost-derive-0.7.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__prost_types__0_7_0",
        url = "https://crates.io/api/v1/crates/prost-types/0.7.0/download",
        type = "tar.gz",
        sha256 = "b518d7cdd93dab1d1122cf07fa9a60771836c668dde9d9e2a139f957f0d9f1bb",
        strip_prefix = "prost-types-0.7.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.prost-types-0.7.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__quote__1_0_9",
        url = "https://crates.io/api/v1/crates/quote/1.0.9/download",
        type = "tar.gz",
        sha256 = "c3d0b9745dc2debf507c8422de05d7226cc1f0644216dfdfead988f9b1ab32a7",
        strip_prefix = "quote-1.0.9",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.quote-1.0.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__rand__0_8_3",
        url = "https://crates.io/api/v1/crates/rand/0.8.3/download",
        type = "tar.gz",
        sha256 = "0ef9e7e66b4468674bfcb0c81af8b7fa0bb154fa9f28eb840da5c447baeb8d7e",
        strip_prefix = "rand-0.8.3",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.rand-0.8.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__rand_chacha__0_3_0",
        url = "https://crates.io/api/v1/crates/rand_chacha/0.3.0/download",
        type = "tar.gz",
        sha256 = "e12735cf05c9e10bf21534da50a147b924d555dc7a547c42e6bb2d5b6017ae0d",
        strip_prefix = "rand_chacha-0.3.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.rand_chacha-0.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__rand_core__0_6_2",
        url = "https://crates.io/api/v1/crates/rand_core/0.6.2/download",
        type = "tar.gz",
        sha256 = "34cf66eb183df1c5876e2dcf6b13d57340741e8dc255b48e40a26de954d06ae7",
        strip_prefix = "rand_core-0.6.2",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.rand_core-0.6.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__rand_hc__0_3_0",
        url = "https://crates.io/api/v1/crates/rand_hc/0.3.0/download",
        type = "tar.gz",
        sha256 = "3190ef7066a446f2e7f42e239d161e905420ccab01eb967c9eb27d21b2322a73",
        strip_prefix = "rand_hc-0.3.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.rand_hc-0.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__redox_syscall__0_2_7",
        url = "https://crates.io/api/v1/crates/redox_syscall/0.2.7/download",
        type = "tar.gz",
        sha256 = "85dd92e586f7355c633911e11f77f3d12f04b1b1bd76a198bd34ae3af8341ef2",
        strip_prefix = "redox_syscall-0.2.7",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.redox_syscall-0.2.7.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__remove_dir_all__0_5_3",
        url = "https://crates.io/api/v1/crates/remove_dir_all/0.5.3/download",
        type = "tar.gz",
        sha256 = "3acd125665422973a33ac9d3dd2df85edad0f4ae9b00dafb1a05e43a9f5ef8e7",
        strip_prefix = "remove_dir_all-0.5.3",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.remove_dir_all-0.5.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__ring__0_16_20",
        url = "https://crates.io/api/v1/crates/ring/0.16.20/download",
        type = "tar.gz",
        sha256 = "3053cf52e236a3ed746dfc745aa9cacf1b791d846bdaf412f60a8d7d6e17c8fc",
        strip_prefix = "ring-0.16.20",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.ring-0.16.20.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__rustls__0_19_1",
        url = "https://crates.io/api/v1/crates/rustls/0.19.1/download",
        type = "tar.gz",
        sha256 = "35edb675feee39aec9c99fa5ff985081995a06d594114ae14cbe797ad7b7a6d7",
        strip_prefix = "rustls-0.19.1",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.rustls-0.19.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__rustls_native_certs__0_5_0",
        url = "https://crates.io/api/v1/crates/rustls-native-certs/0.5.0/download",
        type = "tar.gz",
        sha256 = "5a07b7c1885bd8ed3831c289b7870b13ef46fe0e856d288c30d9cc17d75a2092",
        strip_prefix = "rustls-native-certs-0.5.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.rustls-native-certs-0.5.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__schannel__0_1_19",
        url = "https://crates.io/api/v1/crates/schannel/0.1.19/download",
        type = "tar.gz",
        sha256 = "8f05ba609c234e60bee0d547fe94a4c7e9da733d1c962cf6e59efa4cd9c8bc75",
        strip_prefix = "schannel-0.1.19",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.schannel-0.1.19.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__sct__0_6_1",
        url = "https://crates.io/api/v1/crates/sct/0.6.1/download",
        type = "tar.gz",
        sha256 = "b362b83898e0e69f38515b82ee15aa80636befe47c3b6d3d89a911e78fc228ce",
        strip_prefix = "sct-0.6.1",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.sct-0.6.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__security_framework__2_2_0",
        url = "https://crates.io/api/v1/crates/security-framework/2.2.0/download",
        type = "tar.gz",
        sha256 = "3670b1d2fdf6084d192bc71ead7aabe6c06aa2ea3fbd9cc3ac111fa5c2b1bd84",
        strip_prefix = "security-framework-2.2.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.security-framework-2.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__security_framework_sys__2_2_0",
        url = "https://crates.io/api/v1/crates/security-framework-sys/2.2.0/download",
        type = "tar.gz",
        sha256 = "3676258fd3cfe2c9a0ec99ce3038798d847ce3e4bb17746373eb9f0f1ac16339",
        strip_prefix = "security-framework-sys-2.2.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.security-framework-sys-2.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__slab__0_4_3",
        url = "https://crates.io/api/v1/crates/slab/0.4.3/download",
        type = "tar.gz",
        sha256 = "f173ac3d1a7e3b28003f40de0b5ce7fe2710f9b9dc3fc38664cebee46b3b6527",
        strip_prefix = "slab-0.4.3",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.slab-0.4.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__socket2__0_4_0",
        url = "https://crates.io/api/v1/crates/socket2/0.4.0/download",
        type = "tar.gz",
        sha256 = "9e3dfc207c526015c632472a77be09cf1b6e46866581aecae5cc38fb4235dea2",
        strip_prefix = "socket2-0.4.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.socket2-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__spin__0_5_2",
        url = "https://crates.io/api/v1/crates/spin/0.5.2/download",
        type = "tar.gz",
        sha256 = "6e63cff320ae2c57904679ba7cb63280a3dc4613885beafb148ee7bf9aa9042d",
        strip_prefix = "spin-0.5.2",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.spin-0.5.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__structopt__0_3_13",
        url = "https://crates.io/api/v1/crates/structopt/0.3.13/download",
        type = "tar.gz",
        sha256 = "ff6da2e8d107dfd7b74df5ef4d205c6aebee0706c647f6bc6a2d5789905c00fb",
        strip_prefix = "structopt-0.3.13",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.structopt-0.3.13.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__structopt_derive__0_4_6",
        url = "https://crates.io/api/v1/crates/structopt-derive/0.4.6/download",
        type = "tar.gz",
        sha256 = "a489c87c08fbaf12e386665109dd13470dcc9c4583ea3e10dd2b4523e5ebd9ac",
        strip_prefix = "structopt-derive-0.4.6",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.structopt-derive-0.4.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__syn__1_0_71",
        url = "https://crates.io/api/v1/crates/syn/1.0.71/download",
        type = "tar.gz",
        sha256 = "ad184cc9470f9117b2ac6817bfe297307418819ba40552f9b3846f05c33d5373",
        strip_prefix = "syn-1.0.71",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.syn-1.0.71.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__tempfile__3_2_0",
        url = "https://crates.io/api/v1/crates/tempfile/3.2.0/download",
        type = "tar.gz",
        sha256 = "dac1c663cfc93810f88aed9b8941d48cabf856a1b111c29a40439018d870eb22",
        strip_prefix = "tempfile-3.2.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.tempfile-3.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__textwrap__0_11_0",
        url = "https://crates.io/api/v1/crates/textwrap/0.11.0/download",
        type = "tar.gz",
        sha256 = "d326610f408c7a4eb6f51c37c330e496b08506c9457c9d34287ecc38809fb060",
        strip_prefix = "textwrap-0.11.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.textwrap-0.11.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__thiserror__1_0_18",
        url = "https://crates.io/api/v1/crates/thiserror/1.0.18/download",
        type = "tar.gz",
        sha256 = "5976891d6950b4f68477850b5b9e5aa64d955961466f9e174363f573e54e8ca7",
        strip_prefix = "thiserror-1.0.18",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.thiserror-1.0.18.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__thiserror_impl__1_0_18",
        url = "https://crates.io/api/v1/crates/thiserror-impl/1.0.18/download",
        type = "tar.gz",
        sha256 = "ab81dbd1cd69cd2ce22ecfbdd3bdb73334ba25350649408cc6c085f46d89573d",
        strip_prefix = "thiserror-impl-1.0.18",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.thiserror-impl-1.0.18.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__tokio__1_5_0",
        url = "https://crates.io/api/v1/crates/tokio/1.5.0/download",
        type = "tar.gz",
        sha256 = "83f0c8e7c0addab50b663055baf787d0af7f413a46e6e7fb9559a4e4db7137a5",
        strip_prefix = "tokio-1.5.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.tokio-1.5.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__tokio_macros__1_1_0",
        url = "https://crates.io/api/v1/crates/tokio-macros/1.1.0/download",
        type = "tar.gz",
        sha256 = "caf7b11a536f46a809a8a9f0bb4237020f70ecbf115b842360afb127ea2fda57",
        strip_prefix = "tokio-macros-1.1.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.tokio-macros-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__tokio_rustls__0_22_0",
        url = "https://crates.io/api/v1/crates/tokio-rustls/0.22.0/download",
        type = "tar.gz",
        sha256 = "bc6844de72e57df1980054b38be3a9f4702aba4858be64dd700181a8a6d0e1b6",
        strip_prefix = "tokio-rustls-0.22.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.tokio-rustls-0.22.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__tokio_stream__0_1_5",
        url = "https://crates.io/api/v1/crates/tokio-stream/0.1.5/download",
        type = "tar.gz",
        sha256 = "e177a5d8c3bf36de9ebe6d58537d8879e964332f93fb3339e43f618c81361af0",
        strip_prefix = "tokio-stream-0.1.5",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.tokio-stream-0.1.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__tokio_util__0_6_6",
        url = "https://crates.io/api/v1/crates/tokio-util/0.6.6/download",
        type = "tar.gz",
        sha256 = "940a12c99365c31ea8dd9ba04ec1be183ffe4920102bb7122c2f515437601e8e",
        strip_prefix = "tokio-util-0.6.6",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.tokio-util-0.6.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__tonic__0_4_0",
        url = "https://crates.io/api/v1/crates/tonic/0.4.0/download",
        type = "tar.gz",
        sha256 = "3ba8f479158947373b6df40cf48f4779bb25c99ca3c661bd95e0ab1963ad8b0e",
        strip_prefix = "tonic-0.4.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.tonic-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__tonic_build__0_4_0",
        url = "https://crates.io/api/v1/crates/tonic-build/0.4.0/download",
        type = "tar.gz",
        sha256 = "c1e8546fd40d56d28089835c0a81bb396848103b00f888aea42d46eb5974df07",
        strip_prefix = "tonic-build-0.4.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.tonic-build-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__tower__0_4_7",
        url = "https://crates.io/api/v1/crates/tower/0.4.7/download",
        type = "tar.gz",
        sha256 = "bf0aa6dfc29148c3826708dabbfa83c121eeb84df4d1468220825e3a33651687",
        strip_prefix = "tower-0.4.7",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.tower-0.4.7.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__tower_layer__0_3_1",
        url = "https://crates.io/api/v1/crates/tower-layer/0.3.1/download",
        type = "tar.gz",
        sha256 = "343bc9466d3fe6b0f960ef45960509f84480bf4fd96f92901afe7ff3df9d3a62",
        strip_prefix = "tower-layer-0.3.1",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.tower-layer-0.3.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__tower_service__0_3_1",
        url = "https://crates.io/api/v1/crates/tower-service/0.3.1/download",
        type = "tar.gz",
        sha256 = "360dfd1d6d30e05fda32ace2c8c70e9c0a9da713275777f5a4dbb8a1893930c6",
        strip_prefix = "tower-service-0.3.1",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.tower-service-0.3.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__tracing__0_1_25",
        url = "https://crates.io/api/v1/crates/tracing/0.1.25/download",
        type = "tar.gz",
        sha256 = "01ebdc2bb4498ab1ab5f5b73c5803825e60199229ccba0698170e3be0e7f959f",
        strip_prefix = "tracing-0.1.25",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.tracing-0.1.25.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__tracing_attributes__0_1_15",
        url = "https://crates.io/api/v1/crates/tracing-attributes/0.1.15/download",
        type = "tar.gz",
        sha256 = "c42e6fa53307c8a17e4ccd4dc81cf5ec38db9209f59b222210375b54ee40d1e2",
        strip_prefix = "tracing-attributes-0.1.15",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.tracing-attributes-0.1.15.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__tracing_core__0_1_17",
        url = "https://crates.io/api/v1/crates/tracing-core/0.1.17/download",
        type = "tar.gz",
        sha256 = "f50de3927f93d202783f4513cda820ab47ef17f624b03c096e86ef00c67e6b5f",
        strip_prefix = "tracing-core-0.1.17",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.tracing-core-0.1.17.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__tracing_futures__0_2_5",
        url = "https://crates.io/api/v1/crates/tracing-futures/0.2.5/download",
        type = "tar.gz",
        sha256 = "97d095ae15e245a057c8e8451bab9b3ee1e1f68e9ba2b4fbc18d0ac5237835f2",
        strip_prefix = "tracing-futures-0.2.5",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.tracing-futures-0.2.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__try_lock__0_2_3",
        url = "https://crates.io/api/v1/crates/try-lock/0.2.3/download",
        type = "tar.gz",
        sha256 = "59547bce71d9c38b83d9c0e92b6066c4253371f15005def0c30d9657f50c7642",
        strip_prefix = "try-lock-0.2.3",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.try-lock-0.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__unicode_segmentation__1_7_1",
        url = "https://crates.io/api/v1/crates/unicode-segmentation/1.7.1/download",
        type = "tar.gz",
        sha256 = "bb0d2e7be6ae3a5fa87eed5fb451aff96f2573d2694942e40543ae0bbe19c796",
        strip_prefix = "unicode-segmentation-1.7.1",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.unicode-segmentation-1.7.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__unicode_width__0_1_8",
        url = "https://crates.io/api/v1/crates/unicode-width/0.1.8/download",
        type = "tar.gz",
        sha256 = "9337591893a19b88d8d87f2cec1e73fad5cdfd10e5a6f349f498ad6ea2ffb1e3",
        strip_prefix = "unicode-width-0.1.8",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.unicode-width-0.1.8.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__unicode_xid__0_2_1",
        url = "https://crates.io/api/v1/crates/unicode-xid/0.2.1/download",
        type = "tar.gz",
        sha256 = "f7fe0bb3479651439c9112f72b6c505038574c9fbb575ed1bf3b797fa39dd564",
        strip_prefix = "unicode-xid-0.2.1",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.unicode-xid-0.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__untrusted__0_7_1",
        url = "https://crates.io/api/v1/crates/untrusted/0.7.1/download",
        type = "tar.gz",
        sha256 = "a156c684c91ea7d62626509bce3cb4e1d9ed5c4d978f7b4352658f96a4c26b4a",
        strip_prefix = "untrusted-0.7.1",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.untrusted-0.7.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__version_check__0_9_3",
        url = "https://crates.io/api/v1/crates/version_check/0.9.3/download",
        type = "tar.gz",
        sha256 = "5fecdca9a5291cc2b8dcf7dc02453fee791a280f3743cb0905f8822ae463b3fe",
        strip_prefix = "version_check-0.9.3",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.version_check-0.9.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__want__0_3_0",
        url = "https://crates.io/api/v1/crates/want/0.3.0/download",
        type = "tar.gz",
        sha256 = "1ce8a968cb1cd110d136ff8b819a556d6fb6d919363c61534f6860c7eb172ba0",
        strip_prefix = "want-0.3.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.want-0.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__wasi__0_10_2_wasi_snapshot_preview1",
        url = "https://crates.io/api/v1/crates/wasi/0.10.2+wasi-snapshot-preview1/download",
        type = "tar.gz",
        sha256 = "fd6fbd9a79829dd1ad0cc20627bf1ed606756a7f77edff7b66b7064f9cb327c6",
        strip_prefix = "wasi-0.10.2+wasi-snapshot-preview1",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.wasi-0.10.2+wasi-snapshot-preview1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__wasm_bindgen__0_2_73",
        url = "https://crates.io/api/v1/crates/wasm-bindgen/0.2.73/download",
        type = "tar.gz",
        sha256 = "83240549659d187488f91f33c0f8547cbfef0b2088bc470c116d1d260ef623d9",
        strip_prefix = "wasm-bindgen-0.2.73",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.wasm-bindgen-0.2.73.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__wasm_bindgen_backend__0_2_73",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-backend/0.2.73/download",
        type = "tar.gz",
        sha256 = "ae70622411ca953215ca6d06d3ebeb1e915f0f6613e3b495122878d7ebec7dae",
        strip_prefix = "wasm-bindgen-backend-0.2.73",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.wasm-bindgen-backend-0.2.73.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__wasm_bindgen_macro__0_2_73",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-macro/0.2.73/download",
        type = "tar.gz",
        sha256 = "3e734d91443f177bfdb41969de821e15c516931c3c3db3d318fa1b68975d0f6f",
        strip_prefix = "wasm-bindgen-macro-0.2.73",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.wasm-bindgen-macro-0.2.73.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__wasm_bindgen_macro_support__0_2_73",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-macro-support/0.2.73/download",
        type = "tar.gz",
        sha256 = "d53739ff08c8a68b0fdbcd54c372b8ab800b1449ab3c9d706503bc7dd1621b2c",
        strip_prefix = "wasm-bindgen-macro-support-0.2.73",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.wasm-bindgen-macro-support-0.2.73.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__wasm_bindgen_shared__0_2_73",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-shared/0.2.73/download",
        type = "tar.gz",
        sha256 = "d9a543ae66aa233d14bb765ed9af4a33e81b8b58d1584cf1b47ff8cd0b9e4489",
        strip_prefix = "wasm-bindgen-shared-0.2.73",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.wasm-bindgen-shared-0.2.73.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__web_sys__0_3_50",
        url = "https://crates.io/api/v1/crates/web-sys/0.3.50/download",
        type = "tar.gz",
        sha256 = "a905d57e488fec8861446d3393670fb50d27a262344013181c2cdf9fff5481be",
        strip_prefix = "web-sys-0.3.50",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.web-sys-0.3.50.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__webpki__0_21_4",
        url = "https://crates.io/api/v1/crates/webpki/0.21.4/download",
        type = "tar.gz",
        sha256 = "b8e38c0608262c46d4a56202ebabdeb094cef7e560ca7a226c6bf055188aa4ea",
        strip_prefix = "webpki-0.21.4",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.webpki-0.21.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__which__4_1_0",
        url = "https://crates.io/api/v1/crates/which/4.1.0/download",
        type = "tar.gz",
        sha256 = "b55551e42cbdf2ce2bedd2203d0cc08dba002c27510f86dab6d0ce304cba3dfe",
        strip_prefix = "which-4.1.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.which-4.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__winapi__0_3_9",
        url = "https://crates.io/api/v1/crates/winapi/0.3.9/download",
        type = "tar.gz",
        sha256 = "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419",
        strip_prefix = "winapi-0.3.9",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.winapi-0.3.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__winapi_i686_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-i686-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.winapi-i686-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_prostgen__winapi_x86_64_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-x86_64-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("//proto/prostgen/raze/remote:BUILD.winapi-x86_64-pc-windows-gnu-0.4.0.bazel"),
    )
