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
        name = "raze__autocfg__1_0_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/autocfg/autocfg-1.0.0.crate",
        type = "tar.gz",
        strip_prefix = "autocfg-1.0.0",
        sha256 = "f8aac770f1885fd7e387acedd76065302551364496e46b3dd00860b2f8359b9d",
        build_file = Label("//proto/raze/remote:autocfg-1.0.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__base64__0_9_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/base64/base64-0.9.3.crate",
        type = "tar.gz",
        strip_prefix = "base64-0.9.3",
        sha256 = "489d6c0ed21b11d038c31b6ceccca973e65d73ba3bd8ecb9a2babf5546164643",
        build_file = Label("//proto/raze/remote:base64-0.9.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__bitflags__1_2_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/bitflags/bitflags-1.2.1.crate",
        type = "tar.gz",
        strip_prefix = "bitflags-1.2.1",
        sha256 = "cf1de2fe8c75bc145a2f577add951f8134889b4795d47466a54a5c846d691693",
        build_file = Label("//proto/raze/remote:bitflags-1.2.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__byteorder__1_3_4",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/byteorder/byteorder-1.3.4.crate",
        type = "tar.gz",
        strip_prefix = "byteorder-1.3.4",
        sha256 = "08c48aae112d48ed9f069b33538ea9e3e90aa263cfa3d1c24309612b1f7472de",
        build_file = Label("//proto/raze/remote:byteorder-1.3.4.BUILD"),
    )

    _new_http_archive(
        name = "raze__bytes__0_4_12",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/bytes/bytes-0.4.12.crate",
        type = "tar.gz",
        strip_prefix = "bytes-0.4.12",
        sha256 = "206fdffcfa2df7cbe15601ef46c813fce0965eb3286db6b56c583b814b51c81c",
        build_file = Label("//proto/raze/remote:bytes-0.4.12.BUILD"),
    )

    _new_http_archive(
        name = "raze__cfg_if__0_1_10",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/cfg-if/cfg-if-0.1.10.crate",
        type = "tar.gz",
        strip_prefix = "cfg-if-0.1.10",
        sha256 = "4785bdd1c96b2a846b2bd7cc02e86b6b3dbf14e7e53446c4f54c92a361040822",
        build_file = Label("//proto/raze/remote:cfg-if-0.1.10.BUILD"),
    )

    _new_http_archive(
        name = "raze__cloudabi__0_0_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/cloudabi/cloudabi-0.0.3.crate",
        type = "tar.gz",
        strip_prefix = "cloudabi-0.0.3",
        sha256 = "ddfc5b9aa5d4507acaf872de71051dfd0e309860e88966e1051e462a077aac4f",
        build_file = Label("//proto/raze/remote:cloudabi-0.0.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__crossbeam_deque__0_7_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crossbeam-deque/crossbeam-deque-0.7.3.crate",
        type = "tar.gz",
        strip_prefix = "crossbeam-deque-0.7.3",
        sha256 = "9f02af974daeee82218205558e51ec8768b48cf524bd01d550abe5573a608285",
        build_file = Label("//proto/raze/remote:crossbeam-deque-0.7.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__crossbeam_epoch__0_8_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crossbeam-epoch/crossbeam-epoch-0.8.2.crate",
        type = "tar.gz",
        strip_prefix = "crossbeam-epoch-0.8.2",
        sha256 = "058ed274caafc1f60c4997b5fc07bf7dc7cca454af7c6e81edffe5f33f70dace",
        build_file = Label("//proto/raze/remote:crossbeam-epoch-0.8.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__crossbeam_queue__0_2_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crossbeam-queue/crossbeam-queue-0.2.1.crate",
        type = "tar.gz",
        strip_prefix = "crossbeam-queue-0.2.1",
        sha256 = "c695eeca1e7173472a32221542ae469b3e9aac3a4fc81f7696bcad82029493db",
        build_file = Label("//proto/raze/remote:crossbeam-queue-0.2.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__crossbeam_utils__0_7_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crossbeam-utils/crossbeam-utils-0.7.2.crate",
        type = "tar.gz",
        strip_prefix = "crossbeam-utils-0.7.2",
        sha256 = "c3c7c73a2d1e9fc0886a08b93e98eb643461230d5f1925e4036204d5f2e261a8",
        build_file = Label("//proto/raze/remote:crossbeam-utils-0.7.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__fnv__1_0_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/fnv/fnv-1.0.6.crate",
        type = "tar.gz",
        strip_prefix = "fnv-1.0.6",
        sha256 = "2fad85553e09a6f881f739c29f0b00b0f01357c743266d478b68951ce23285f3",
        build_file = Label("//proto/raze/remote:fnv-1.0.6.BUILD"),
    )

    _new_http_archive(
        name = "raze__fuchsia_zircon__0_3_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/fuchsia-zircon/fuchsia-zircon-0.3.3.crate",
        type = "tar.gz",
        strip_prefix = "fuchsia-zircon-0.3.3",
        sha256 = "2e9763c69ebaae630ba35f74888db465e49e259ba1bc0eda7d06f4a067615d82",
        build_file = Label("//proto/raze/remote:fuchsia-zircon-0.3.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__fuchsia_zircon_sys__0_3_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/fuchsia-zircon-sys/fuchsia-zircon-sys-0.3.3.crate",
        type = "tar.gz",
        strip_prefix = "fuchsia-zircon-sys-0.3.3",
        sha256 = "3dcaa9ae7725d12cdb85b3ad99a434db70b468c09ded17e012d86b5c1010f7a7",
        build_file = Label("//proto/raze/remote:fuchsia-zircon-sys-0.3.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__futures__0_1_29",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/futures/futures-0.1.29.crate",
        type = "tar.gz",
        strip_prefix = "futures-0.1.29",
        sha256 = "1b980f2816d6ee8673b6517b52cb0e808a180efc92e5c19d02cdda79066703ef",
        build_file = Label("//proto/raze/remote:futures-0.1.29.BUILD"),
    )

    _new_http_archive(
        name = "raze__futures_cpupool__0_1_8",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/futures-cpupool/futures-cpupool-0.1.8.crate",
        type = "tar.gz",
        strip_prefix = "futures-cpupool-0.1.8",
        sha256 = "ab90cde24b3319636588d0c35fe03b1333857621051837ed769faefb4c2162e4",
        build_file = Label("//proto/raze/remote:futures-cpupool-0.1.8.BUILD"),
    )

    _new_http_archive(
        name = "raze__grpc__0_6_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/grpc/grpc-0.6.2.crate",
        type = "tar.gz",
        strip_prefix = "grpc-0.6.2",
        sha256 = "2aaf1d741fe6f3413f1f9f71b99f5e4e26776d563475a8a53ce53a73a8534c1d",
        build_file = Label("//proto/raze/remote:grpc-0.6.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__grpc_compiler__0_6_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/grpc-compiler/grpc-compiler-0.6.2.crate",
        type = "tar.gz",
        strip_prefix = "grpc-compiler-0.6.2",
        sha256 = "907274ce8ee7b40a0d0b0db09022ea22846a47cfb1fc8ad2c983c70001b4ffb1",
        build_file = Label("//proto/raze/remote:grpc-compiler-0.6.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__hermit_abi__0_1_11",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/hermit-abi/hermit-abi-0.1.11.crate",
        type = "tar.gz",
        strip_prefix = "hermit-abi-0.1.11",
        sha256 = "8a0d737e0f947a1864e93d33fdef4af8445a00d1ed8dc0c8ddb73139ea6abf15",
        build_file = Label("//proto/raze/remote:hermit-abi-0.1.11.BUILD"),
    )

    _new_http_archive(
        name = "raze__httpbis__0_7_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/httpbis/httpbis-0.7.0.crate",
        type = "tar.gz",
        strip_prefix = "httpbis-0.7.0",
        sha256 = "7689cfa896b2a71da4f16206af167542b75d242b6906313e53857972a92d5614",
        build_file = Label("//proto/raze/remote:httpbis-0.7.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__iovec__0_1_4",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/iovec/iovec-0.1.4.crate",
        type = "tar.gz",
        strip_prefix = "iovec-0.1.4",
        sha256 = "b2b3ea6ff95e175473f8ffe6a7eb7c00d054240321b84c57051175fe3c1e075e",
        build_file = Label("//proto/raze/remote:iovec-0.1.4.BUILD"),
    )

    _new_http_archive(
        name = "raze__kernel32_sys__0_2_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/kernel32-sys/kernel32-sys-0.2.2.crate",
        type = "tar.gz",
        strip_prefix = "kernel32-sys-0.2.2",
        sha256 = "7507624b29483431c0ba2d82aece8ca6cdba9382bff4ddd0f7490560c056098d",
        build_file = Label("//proto/raze/remote:kernel32-sys-0.2.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__lazy_static__1_4_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/lazy_static/lazy_static-1.4.0.crate",
        type = "tar.gz",
        strip_prefix = "lazy_static-1.4.0",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        build_file = Label("//proto/raze/remote:lazy_static-1.4.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__libc__0_2_69",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/libc/libc-0.2.69.crate",
        type = "tar.gz",
        strip_prefix = "libc-0.2.69",
        sha256 = "99e85c08494b21a9054e7fe1374a732aeadaff3980b6990b94bfd3a70f690005",
        build_file = Label("//proto/raze/remote:libc-0.2.69.BUILD"),
    )

    _new_http_archive(
        name = "raze__lock_api__0_3_4",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/lock_api/lock_api-0.3.4.crate",
        type = "tar.gz",
        strip_prefix = "lock_api-0.3.4",
        sha256 = "c4da24a77a3d8a6d4862d95f72e6fdb9c09a643ecdb402d754004a557f2bec75",
        build_file = Label("//proto/raze/remote:lock_api-0.3.4.BUILD"),
    )

    _new_http_archive(
        name = "raze__log__0_3_9",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/log/log-0.3.9.crate",
        type = "tar.gz",
        strip_prefix = "log-0.3.9",
        sha256 = "e19e8d5c34a3e0e2223db8e060f9e8264aeeb5c5fc64a4ee9965c062211c024b",
        build_file = Label("//proto/raze/remote:log-0.3.9.BUILD"),
    )

    _new_http_archive(
        name = "raze__log__0_4_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/log/log-0.4.6.crate",
        type = "tar.gz",
        strip_prefix = "log-0.4.6",
        sha256 = "c84ec4b527950aa83a329754b01dbe3f58361d1c5efacd1f6d68c494d08a17c6",
        build_file = Label("//proto/raze/remote:log-0.4.6.BUILD"),
    )

    _new_http_archive(
        name = "raze__maybe_uninit__2_0_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/maybe-uninit/maybe-uninit-2.0.0.crate",
        type = "tar.gz",
        strip_prefix = "maybe-uninit-2.0.0",
        sha256 = "60302e4db3a61da70c0cb7991976248362f30319e88850c487b9b95bbf059e00",
        build_file = Label("//proto/raze/remote:maybe-uninit-2.0.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__memoffset__0_5_4",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/memoffset/memoffset-0.5.4.crate",
        type = "tar.gz",
        strip_prefix = "memoffset-0.5.4",
        sha256 = "b4fc2c02a7e374099d4ee95a193111f72d2110197fe200272371758f6c3643d8",
        build_file = Label("//proto/raze/remote:memoffset-0.5.4.BUILD"),
    )

    _new_http_archive(
        name = "raze__mio__0_6_21",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/mio/mio-0.6.21.crate",
        type = "tar.gz",
        strip_prefix = "mio-0.6.21",
        sha256 = "302dec22bcf6bae6dfb69c647187f4b4d0fb6f535521f7bc022430ce8e12008f",
        build_file = Label("//proto/raze/remote:mio-0.6.21.BUILD"),
    )

    _new_http_archive(
        name = "raze__mio_uds__0_6_7",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/mio-uds/mio-uds-0.6.7.crate",
        type = "tar.gz",
        strip_prefix = "mio-uds-0.6.7",
        sha256 = "966257a94e196b11bb43aca423754d87429960a768de9414f3691d6957abf125",
        build_file = Label("//proto/raze/remote:mio-uds-0.6.7.BUILD"),
    )

    _new_http_archive(
        name = "raze__miow__0_2_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/miow/miow-0.2.1.crate",
        type = "tar.gz",
        strip_prefix = "miow-0.2.1",
        sha256 = "8c1f2f3b1cf331de6896aabf6e9d55dca90356cc9960cca7eaaf408a355ae919",
        build_file = Label("//proto/raze/remote:miow-0.2.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__net2__0_2_33",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/net2/net2-0.2.33.crate",
        type = "tar.gz",
        strip_prefix = "net2-0.2.33",
        sha256 = "42550d9fb7b6684a6d404d9fa7250c2eb2646df731d1c06afc06dcee9e1bcf88",
        build_file = Label("//proto/raze/remote:net2-0.2.33.BUILD"),
    )

    _new_http_archive(
        name = "raze__num_cpus__1_13_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/num_cpus/num_cpus-1.13.0.crate",
        type = "tar.gz",
        strip_prefix = "num_cpus-1.13.0",
        sha256 = "05499f3756671c15885fee9034446956fff3f243d6077b91e5767df161f766b3",
        build_file = Label("//proto/raze/remote:num_cpus-1.13.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__parking_lot__0_9_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/parking_lot/parking_lot-0.9.0.crate",
        type = "tar.gz",
        strip_prefix = "parking_lot-0.9.0",
        sha256 = "f842b1982eb6c2fe34036a4fbfb06dd185a3f5c8edfaacdf7d1ea10b07de6252",
        build_file = Label("//proto/raze/remote:parking_lot-0.9.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__parking_lot_core__0_6_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/parking_lot_core/parking_lot_core-0.6.2.crate",
        type = "tar.gz",
        strip_prefix = "parking_lot_core-0.6.2",
        sha256 = "b876b1b9e7ac6e1a74a6da34d25c42e17e8862aa409cbbbdcfc8d86c6f3bc62b",
        build_file = Label("//proto/raze/remote:parking_lot_core-0.6.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__protobuf__2_8_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/protobuf/protobuf-2.8.2.crate",
        type = "tar.gz",
        strip_prefix = "protobuf-2.8.2",
        sha256 = "70731852eec72c56d11226c8a5f96ad5058a3dab73647ca5f7ee351e464f2571",
        patches = [
            "@io_bazel_rules_rust//proto/raze/patch:protobuf-2.8.2.patch",
        ],
        patch_args = [
            "-p1",
        ],
        build_file = Label("//proto/raze/remote:protobuf-2.8.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__protobuf_codegen__2_8_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/protobuf-codegen/protobuf-codegen-2.8.2.crate",
        type = "tar.gz",
        strip_prefix = "protobuf-codegen-2.8.2",
        sha256 = "3d74b9cbbf2ac9a7169c85a3714ec16c51ee9ec7cfd511549527e9a7df720795",
        build_file = Label("//proto/raze/remote:protobuf-codegen-2.8.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__redox_syscall__0_1_56",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/redox_syscall/redox_syscall-0.1.56.crate",
        type = "tar.gz",
        strip_prefix = "redox_syscall-0.1.56",
        sha256 = "2439c63f3f6139d1b57529d16bc3b8bb855230c8efcc5d3a896c8bea7c3b1e84",
        build_file = Label("//proto/raze/remote:redox_syscall-0.1.56.BUILD"),
    )

    _new_http_archive(
        name = "raze__rustc_version__0_2_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rustc_version/rustc_version-0.2.3.crate",
        type = "tar.gz",
        strip_prefix = "rustc_version-0.2.3",
        sha256 = "138e3e0acb6c9fb258b19b67cb8abd63c00679d2851805ea151465464fe9030a",
        build_file = Label("//proto/raze/remote:rustc_version-0.2.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__safemem__0_3_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/safemem/safemem-0.3.3.crate",
        type = "tar.gz",
        strip_prefix = "safemem-0.3.3",
        sha256 = "ef703b7cb59335eae2eb93ceb664c0eb7ea6bf567079d843e09420219668e072",
        build_file = Label("//proto/raze/remote:safemem-0.3.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__scoped_tls__0_1_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/scoped-tls/scoped-tls-0.1.2.crate",
        type = "tar.gz",
        strip_prefix = "scoped-tls-0.1.2",
        sha256 = "332ffa32bf586782a3efaeb58f127980944bbc8c4d6913a86107ac2a5ab24b28",
        build_file = Label("//proto/raze/remote:scoped-tls-0.1.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__scopeguard__1_1_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/scopeguard/scopeguard-1.1.0.crate",
        type = "tar.gz",
        strip_prefix = "scopeguard-1.1.0",
        sha256 = "d29ab0c6d3fc0ee92fe66e2d99f700eab17a8d57d1c1d3b748380fb20baa78cd",
        build_file = Label("//proto/raze/remote:scopeguard-1.1.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__semver__0_9_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/semver/semver-0.9.0.crate",
        type = "tar.gz",
        strip_prefix = "semver-0.9.0",
        sha256 = "1d7eb9ef2c18661902cc47e535f9bc51b78acd254da71d375c2f6720d9a40403",
        build_file = Label("//proto/raze/remote:semver-0.9.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__semver_parser__0_7_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/semver-parser/semver-parser-0.7.0.crate",
        type = "tar.gz",
        strip_prefix = "semver-parser-0.7.0",
        sha256 = "388a1df253eca08550bef6c72392cfe7c30914bf41df5269b68cbd6ff8f570a3",
        build_file = Label("//proto/raze/remote:semver-parser-0.7.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__slab__0_3_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/slab/slab-0.3.0.crate",
        type = "tar.gz",
        strip_prefix = "slab-0.3.0",
        sha256 = "17b4fcaed89ab08ef143da37bc52adbcc04d4a69014f4c1208d6b51f0c47bc23",
        build_file = Label("//proto/raze/remote:slab-0.3.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__slab__0_4_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/slab/slab-0.4.2.crate",
        type = "tar.gz",
        strip_prefix = "slab-0.4.2",
        sha256 = "c111b5bd5695e56cffe5129854aa230b39c93a305372fdbb2668ca2394eea9f8",
        build_file = Label("//proto/raze/remote:slab-0.4.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__smallvec__0_6_13",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/smallvec/smallvec-0.6.13.crate",
        type = "tar.gz",
        strip_prefix = "smallvec-0.6.13",
        sha256 = "f7b0758c52e15a8b5e3691eae6cc559f08eee9406e548a4477ba4e67770a82b6",
        build_file = Label("//proto/raze/remote:smallvec-0.6.13.BUILD"),
    )

    _new_http_archive(
        name = "raze__tls_api__0_1_22",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tls-api/tls-api-0.1.22.crate",
        type = "tar.gz",
        strip_prefix = "tls-api-0.1.22",
        sha256 = "049c03787a0595182357fbd487577947f4351b78ce20c3668f6d49f17feb13d1",
        build_file = Label("//proto/raze/remote:tls-api-0.1.22.BUILD"),
    )

    _new_http_archive(
        name = "raze__tls_api_stub__0_1_22",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tls-api-stub/tls-api-stub-0.1.22.crate",
        type = "tar.gz",
        strip_prefix = "tls-api-stub-0.1.22",
        sha256 = "c9a0cc8c149724db9de7d73a0e1bc80b1a74f5394f08c6f301e11f9c35fa061e",
        build_file = Label("//proto/raze/remote:tls-api-stub-0.1.22.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio__0_1_22",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio/tokio-0.1.22.crate",
        type = "tar.gz",
        strip_prefix = "tokio-0.1.22",
        sha256 = "5a09c0b5bb588872ab2f09afa13ee6e9dac11e10a0ec9e8e3ba39a5a5d530af6",
        build_file = Label("//proto/raze/remote:tokio-0.1.22.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_codec__0_1_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-codec/tokio-codec-0.1.2.crate",
        type = "tar.gz",
        strip_prefix = "tokio-codec-0.1.2",
        sha256 = "25b2998660ba0e70d18684de5d06b70b70a3a747469af9dea7618cc59e75976b",
        build_file = Label("//proto/raze/remote:tokio-codec-0.1.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_core__0_1_17",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-core/tokio-core-0.1.17.crate",
        type = "tar.gz",
        strip_prefix = "tokio-core-0.1.17",
        sha256 = "aeeffbbb94209023feaef3c196a41cbcdafa06b4a6f893f68779bb5e53796f71",
        build_file = Label("//proto/raze/remote:tokio-core-0.1.17.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_current_thread__0_1_7",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-current-thread/tokio-current-thread-0.1.7.crate",
        type = "tar.gz",
        strip_prefix = "tokio-current-thread-0.1.7",
        sha256 = "b1de0e32a83f131e002238d7ccde18211c0a5397f60cbfffcb112868c2e0e20e",
        build_file = Label("//proto/raze/remote:tokio-current-thread-0.1.7.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_executor__0_1_10",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-executor/tokio-executor-0.1.10.crate",
        type = "tar.gz",
        strip_prefix = "tokio-executor-0.1.10",
        sha256 = "fb2d1b8f4548dbf5e1f7818512e9c406860678f29c300cdf0ebac72d1a3a1671",
        build_file = Label("//proto/raze/remote:tokio-executor-0.1.10.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_fs__0_1_7",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-fs/tokio-fs-0.1.7.crate",
        type = "tar.gz",
        strip_prefix = "tokio-fs-0.1.7",
        sha256 = "297a1206e0ca6302a0eed35b700d292b275256f596e2f3fea7729d5e629b6ff4",
        build_file = Label("//proto/raze/remote:tokio-fs-0.1.7.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_io__0_1_13",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-io/tokio-io-0.1.13.crate",
        type = "tar.gz",
        strip_prefix = "tokio-io-0.1.13",
        sha256 = "57fc868aae093479e3131e3d165c93b1c7474109d13c90ec0dda2a1bbfff0674",
        build_file = Label("//proto/raze/remote:tokio-io-0.1.13.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_reactor__0_1_12",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-reactor/tokio-reactor-0.1.12.crate",
        type = "tar.gz",
        strip_prefix = "tokio-reactor-0.1.12",
        sha256 = "09bc590ec4ba8ba87652da2068d150dcada2cfa2e07faae270a5e0409aa51351",
        build_file = Label("//proto/raze/remote:tokio-reactor-0.1.12.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_sync__0_1_8",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-sync/tokio-sync-0.1.8.crate",
        type = "tar.gz",
        strip_prefix = "tokio-sync-0.1.8",
        sha256 = "edfe50152bc8164fcc456dab7891fa9bf8beaf01c5ee7e1dd43a397c3cf87dee",
        build_file = Label("//proto/raze/remote:tokio-sync-0.1.8.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_tcp__0_1_4",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-tcp/tokio-tcp-0.1.4.crate",
        type = "tar.gz",
        strip_prefix = "tokio-tcp-0.1.4",
        sha256 = "98df18ed66e3b72e742f185882a9e201892407957e45fbff8da17ae7a7c51f72",
        build_file = Label("//proto/raze/remote:tokio-tcp-0.1.4.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_threadpool__0_1_18",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-threadpool/tokio-threadpool-0.1.18.crate",
        type = "tar.gz",
        strip_prefix = "tokio-threadpool-0.1.18",
        sha256 = "df720b6581784c118f0eb4310796b12b1d242a7eb95f716a8367855325c25f89",
        build_file = Label("//proto/raze/remote:tokio-threadpool-0.1.18.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_timer__0_1_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-timer/tokio-timer-0.1.2.crate",
        type = "tar.gz",
        strip_prefix = "tokio-timer-0.1.2",
        sha256 = "6131e780037787ff1b3f8aad9da83bca02438b72277850dd6ad0d455e0e20efc",
        build_file = Label("//proto/raze/remote:tokio-timer-0.1.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_timer__0_2_13",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-timer/tokio-timer-0.2.13.crate",
        type = "tar.gz",
        strip_prefix = "tokio-timer-0.2.13",
        sha256 = "93044f2d313c95ff1cb7809ce9a7a05735b012288a888b62d4434fd58c94f296",
        build_file = Label("//proto/raze/remote:tokio-timer-0.2.13.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_tls_api__0_1_22",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-tls-api/tokio-tls-api-0.1.22.crate",
        type = "tar.gz",
        strip_prefix = "tokio-tls-api-0.1.22",
        sha256 = "68d0e040d5b1f4cfca70ec4f371229886a5de5bb554d272a4a8da73004a7b2c9",
        build_file = Label("//proto/raze/remote:tokio-tls-api-0.1.22.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_udp__0_1_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-udp/tokio-udp-0.1.6.crate",
        type = "tar.gz",
        strip_prefix = "tokio-udp-0.1.6",
        sha256 = "e2a0b10e610b39c38b031a2fcab08e4b82f16ece36504988dcbd81dbba650d82",
        build_file = Label("//proto/raze/remote:tokio-udp-0.1.6.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_uds__0_1_7",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-uds/tokio-uds-0.1.7.crate",
        type = "tar.gz",
        strip_prefix = "tokio-uds-0.1.7",
        sha256 = "65ae5d255ce739e8537221ed2942e0445f4b3b813daebac1c0050ddaaa3587f9",
        build_file = Label("//proto/raze/remote:tokio-uds-0.1.7.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_uds__0_2_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-uds/tokio-uds-0.2.6.crate",
        type = "tar.gz",
        strip_prefix = "tokio-uds-0.2.6",
        sha256 = "5076db410d6fdc6523df7595447629099a1fdc47b3d9f896220780fa48faf798",
        build_file = Label("//proto/raze/remote:tokio-uds-0.2.6.BUILD"),
    )

    _new_http_archive(
        name = "raze__unix_socket__0_5_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/unix_socket/unix_socket-0.5.0.crate",
        type = "tar.gz",
        strip_prefix = "unix_socket-0.5.0",
        sha256 = "6aa2700417c405c38f5e6902d699345241c28c0b7ade4abaad71e35a87eb1564",
        build_file = Label("//proto/raze/remote:unix_socket-0.5.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__void__1_0_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/void/void-1.0.2.crate",
        type = "tar.gz",
        strip_prefix = "void-1.0.2",
        sha256 = "6a02e4885ed3bc0f2de90ea6dd45ebcbb66dacffe03547fadbb0eeae2770887d",
        build_file = Label("//proto/raze/remote:void-1.0.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__winapi__0_2_8",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi/winapi-0.2.8.crate",
        type = "tar.gz",
        strip_prefix = "winapi-0.2.8",
        sha256 = "167dc9d6949a9b857f3451275e911c3f44255842c1f7a76f33c55103a909087a",
        build_file = Label("//proto/raze/remote:winapi-0.2.8.BUILD"),
    )

    _new_http_archive(
        name = "raze__winapi__0_3_8",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi/winapi-0.3.8.crate",
        type = "tar.gz",
        strip_prefix = "winapi-0.3.8",
        sha256 = "8093091eeb260906a183e6ae1abdba2ef5ef2257a21801128899c3fc699229c6",
        build_file = Label("//proto/raze/remote:winapi-0.3.8.BUILD"),
    )

    _new_http_archive(
        name = "raze__winapi_build__0_1_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi-build/winapi-build-0.1.1.crate",
        type = "tar.gz",
        strip_prefix = "winapi-build-0.1.1",
        sha256 = "2d315eee3b34aca4797b2da6b13ed88266e6d612562a0c46390af8299fc699bc",
        build_file = Label("//proto/raze/remote:winapi-build-0.1.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__winapi_i686_pc_windows_gnu__0_4_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi-i686-pc-windows-gnu/winapi-i686-pc-windows-gnu-0.4.0.crate",
        type = "tar.gz",
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        build_file = Label("//proto/raze/remote:winapi-i686-pc-windows-gnu-0.4.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__winapi_x86_64_pc_windows_gnu__0_4_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi-x86_64-pc-windows-gnu/winapi-x86_64-pc-windows-gnu-0.4.0.crate",
        type = "tar.gz",
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        build_file = Label("//proto/raze/remote:winapi-x86_64-pc-windows-gnu-0.4.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__ws2_32_sys__0_2_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/ws2_32-sys/ws2_32-sys-0.2.1.crate",
        type = "tar.gz",
        strip_prefix = "ws2_32-sys-0.2.1",
        sha256 = "d59cefebd0c892fa2dd6de581e937301d8552cb44489cdff035c6187cb63fa5e",
        build_file = Label("//proto/raze/remote:ws2_32-sys-0.2.1.BUILD"),
    )

