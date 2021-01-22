"""
@generated
cargo-raze generated Bazel file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

def rules_rust_proto_fetch_remote_crates():
    """This function defines a collection of repos and should be called in a WORKSPACE file"""
    maybe(
        http_archive,
        name = "rules_rust_proto__autocfg__1_0_0",
        url = "https://crates.io/api/v1/crates/autocfg/1.0.0/download",
        type = "tar.gz",
        sha256 = "f8aac770f1885fd7e387acedd76065302551364496e46b3dd00860b2f8359b9d",
        strip_prefix = "autocfg-1.0.0",
        build_file = Label("//proto/raze/remote:BUILD.autocfg-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__base64__0_9_3",
        url = "https://crates.io/api/v1/crates/base64/0.9.3/download",
        type = "tar.gz",
        sha256 = "489d6c0ed21b11d038c31b6ceccca973e65d73ba3bd8ecb9a2babf5546164643",
        strip_prefix = "base64-0.9.3",
        build_file = Label("//proto/raze/remote:BUILD.base64-0.9.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__bitflags__1_2_1",
        url = "https://crates.io/api/v1/crates/bitflags/1.2.1/download",
        type = "tar.gz",
        sha256 = "cf1de2fe8c75bc145a2f577add951f8134889b4795d47466a54a5c846d691693",
        strip_prefix = "bitflags-1.2.1",
        build_file = Label("//proto/raze/remote:BUILD.bitflags-1.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__byteorder__1_3_4",
        url = "https://crates.io/api/v1/crates/byteorder/1.3.4/download",
        type = "tar.gz",
        sha256 = "08c48aae112d48ed9f069b33538ea9e3e90aa263cfa3d1c24309612b1f7472de",
        strip_prefix = "byteorder-1.3.4",
        build_file = Label("//proto/raze/remote:BUILD.byteorder-1.3.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__bytes__0_4_12",
        url = "https://crates.io/api/v1/crates/bytes/0.4.12/download",
        type = "tar.gz",
        sha256 = "206fdffcfa2df7cbe15601ef46c813fce0965eb3286db6b56c583b814b51c81c",
        strip_prefix = "bytes-0.4.12",
        build_file = Label("//proto/raze/remote:BUILD.bytes-0.4.12.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__cfg_if__0_1_10",
        url = "https://crates.io/api/v1/crates/cfg-if/0.1.10/download",
        type = "tar.gz",
        sha256 = "4785bdd1c96b2a846b2bd7cc02e86b6b3dbf14e7e53446c4f54c92a361040822",
        strip_prefix = "cfg-if-0.1.10",
        build_file = Label("//proto/raze/remote:BUILD.cfg-if-0.1.10.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__cloudabi__0_0_3",
        url = "https://crates.io/api/v1/crates/cloudabi/0.0.3/download",
        type = "tar.gz",
        sha256 = "ddfc5b9aa5d4507acaf872de71051dfd0e309860e88966e1051e462a077aac4f",
        strip_prefix = "cloudabi-0.0.3",
        build_file = Label("//proto/raze/remote:BUILD.cloudabi-0.0.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__crossbeam_deque__0_7_3",
        url = "https://crates.io/api/v1/crates/crossbeam-deque/0.7.3/download",
        type = "tar.gz",
        sha256 = "9f02af974daeee82218205558e51ec8768b48cf524bd01d550abe5573a608285",
        strip_prefix = "crossbeam-deque-0.7.3",
        build_file = Label("//proto/raze/remote:BUILD.crossbeam-deque-0.7.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__crossbeam_epoch__0_8_2",
        url = "https://crates.io/api/v1/crates/crossbeam-epoch/0.8.2/download",
        type = "tar.gz",
        sha256 = "058ed274caafc1f60c4997b5fc07bf7dc7cca454af7c6e81edffe5f33f70dace",
        strip_prefix = "crossbeam-epoch-0.8.2",
        build_file = Label("//proto/raze/remote:BUILD.crossbeam-epoch-0.8.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__crossbeam_queue__0_2_1",
        url = "https://crates.io/api/v1/crates/crossbeam-queue/0.2.1/download",
        type = "tar.gz",
        sha256 = "c695eeca1e7173472a32221542ae469b3e9aac3a4fc81f7696bcad82029493db",
        strip_prefix = "crossbeam-queue-0.2.1",
        build_file = Label("//proto/raze/remote:BUILD.crossbeam-queue-0.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__crossbeam_utils__0_7_2",
        url = "https://crates.io/api/v1/crates/crossbeam-utils/0.7.2/download",
        type = "tar.gz",
        sha256 = "c3c7c73a2d1e9fc0886a08b93e98eb643461230d5f1925e4036204d5f2e261a8",
        strip_prefix = "crossbeam-utils-0.7.2",
        build_file = Label("//proto/raze/remote:BUILD.crossbeam-utils-0.7.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__fnv__1_0_6",
        url = "https://crates.io/api/v1/crates/fnv/1.0.6/download",
        type = "tar.gz",
        sha256 = "2fad85553e09a6f881f739c29f0b00b0f01357c743266d478b68951ce23285f3",
        strip_prefix = "fnv-1.0.6",
        build_file = Label("//proto/raze/remote:BUILD.fnv-1.0.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__fuchsia_zircon__0_3_3",
        url = "https://crates.io/api/v1/crates/fuchsia-zircon/0.3.3/download",
        type = "tar.gz",
        sha256 = "2e9763c69ebaae630ba35f74888db465e49e259ba1bc0eda7d06f4a067615d82",
        strip_prefix = "fuchsia-zircon-0.3.3",
        build_file = Label("//proto/raze/remote:BUILD.fuchsia-zircon-0.3.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__fuchsia_zircon_sys__0_3_3",
        url = "https://crates.io/api/v1/crates/fuchsia-zircon-sys/0.3.3/download",
        type = "tar.gz",
        sha256 = "3dcaa9ae7725d12cdb85b3ad99a434db70b468c09ded17e012d86b5c1010f7a7",
        strip_prefix = "fuchsia-zircon-sys-0.3.3",
        build_file = Label("//proto/raze/remote:BUILD.fuchsia-zircon-sys-0.3.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__futures__0_1_29",
        url = "https://crates.io/api/v1/crates/futures/0.1.29/download",
        type = "tar.gz",
        sha256 = "1b980f2816d6ee8673b6517b52cb0e808a180efc92e5c19d02cdda79066703ef",
        strip_prefix = "futures-0.1.29",
        build_file = Label("//proto/raze/remote:BUILD.futures-0.1.29.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__futures_cpupool__0_1_8",
        url = "https://crates.io/api/v1/crates/futures-cpupool/0.1.8/download",
        type = "tar.gz",
        sha256 = "ab90cde24b3319636588d0c35fe03b1333857621051837ed769faefb4c2162e4",
        strip_prefix = "futures-cpupool-0.1.8",
        build_file = Label("//proto/raze/remote:BUILD.futures-cpupool-0.1.8.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__grpc__0_6_2",
        url = "https://crates.io/api/v1/crates/grpc/0.6.2/download",
        type = "tar.gz",
        sha256 = "2aaf1d741fe6f3413f1f9f71b99f5e4e26776d563475a8a53ce53a73a8534c1d",
        strip_prefix = "grpc-0.6.2",
        build_file = Label("//proto/raze/remote:BUILD.grpc-0.6.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__grpc_compiler__0_6_2",
        url = "https://crates.io/api/v1/crates/grpc-compiler/0.6.2/download",
        type = "tar.gz",
        sha256 = "907274ce8ee7b40a0d0b0db09022ea22846a47cfb1fc8ad2c983c70001b4ffb1",
        strip_prefix = "grpc-compiler-0.6.2",
        build_file = Label("//proto/raze/remote:BUILD.grpc-compiler-0.6.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__hermit_abi__0_1_11",
        url = "https://crates.io/api/v1/crates/hermit-abi/0.1.11/download",
        type = "tar.gz",
        sha256 = "8a0d737e0f947a1864e93d33fdef4af8445a00d1ed8dc0c8ddb73139ea6abf15",
        strip_prefix = "hermit-abi-0.1.11",
        build_file = Label("//proto/raze/remote:BUILD.hermit-abi-0.1.11.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__httpbis__0_7_0",
        url = "https://crates.io/api/v1/crates/httpbis/0.7.0/download",
        type = "tar.gz",
        sha256 = "7689cfa896b2a71da4f16206af167542b75d242b6906313e53857972a92d5614",
        strip_prefix = "httpbis-0.7.0",
        build_file = Label("//proto/raze/remote:BUILD.httpbis-0.7.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__iovec__0_1_4",
        url = "https://crates.io/api/v1/crates/iovec/0.1.4/download",
        type = "tar.gz",
        sha256 = "b2b3ea6ff95e175473f8ffe6a7eb7c00d054240321b84c57051175fe3c1e075e",
        strip_prefix = "iovec-0.1.4",
        build_file = Label("//proto/raze/remote:BUILD.iovec-0.1.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__kernel32_sys__0_2_2",
        url = "https://crates.io/api/v1/crates/kernel32-sys/0.2.2/download",
        type = "tar.gz",
        sha256 = "7507624b29483431c0ba2d82aece8ca6cdba9382bff4ddd0f7490560c056098d",
        strip_prefix = "kernel32-sys-0.2.2",
        build_file = Label("//proto/raze/remote:BUILD.kernel32-sys-0.2.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__lazy_static__1_4_0",
        url = "https://crates.io/api/v1/crates/lazy_static/1.4.0/download",
        type = "tar.gz",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        strip_prefix = "lazy_static-1.4.0",
        build_file = Label("//proto/raze/remote:BUILD.lazy_static-1.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__libc__0_2_69",
        url = "https://crates.io/api/v1/crates/libc/0.2.69/download",
        type = "tar.gz",
        sha256 = "99e85c08494b21a9054e7fe1374a732aeadaff3980b6990b94bfd3a70f690005",
        strip_prefix = "libc-0.2.69",
        build_file = Label("//proto/raze/remote:BUILD.libc-0.2.69.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__lock_api__0_3_4",
        url = "https://crates.io/api/v1/crates/lock_api/0.3.4/download",
        type = "tar.gz",
        sha256 = "c4da24a77a3d8a6d4862d95f72e6fdb9c09a643ecdb402d754004a557f2bec75",
        strip_prefix = "lock_api-0.3.4",
        build_file = Label("//proto/raze/remote:BUILD.lock_api-0.3.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__log__0_3_9",
        url = "https://crates.io/api/v1/crates/log/0.3.9/download",
        type = "tar.gz",
        sha256 = "e19e8d5c34a3e0e2223db8e060f9e8264aeeb5c5fc64a4ee9965c062211c024b",
        strip_prefix = "log-0.3.9",
        build_file = Label("//proto/raze/remote:BUILD.log-0.3.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__log__0_4_6",
        url = "https://crates.io/api/v1/crates/log/0.4.6/download",
        type = "tar.gz",
        sha256 = "c84ec4b527950aa83a329754b01dbe3f58361d1c5efacd1f6d68c494d08a17c6",
        strip_prefix = "log-0.4.6",
        build_file = Label("//proto/raze/remote:BUILD.log-0.4.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__maybe_uninit__2_0_0",
        url = "https://crates.io/api/v1/crates/maybe-uninit/2.0.0/download",
        type = "tar.gz",
        sha256 = "60302e4db3a61da70c0cb7991976248362f30319e88850c487b9b95bbf059e00",
        strip_prefix = "maybe-uninit-2.0.0",
        build_file = Label("//proto/raze/remote:BUILD.maybe-uninit-2.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__memoffset__0_5_4",
        url = "https://crates.io/api/v1/crates/memoffset/0.5.4/download",
        type = "tar.gz",
        sha256 = "b4fc2c02a7e374099d4ee95a193111f72d2110197fe200272371758f6c3643d8",
        strip_prefix = "memoffset-0.5.4",
        build_file = Label("//proto/raze/remote:BUILD.memoffset-0.5.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__mio__0_6_21",
        url = "https://crates.io/api/v1/crates/mio/0.6.21/download",
        type = "tar.gz",
        sha256 = "302dec22bcf6bae6dfb69c647187f4b4d0fb6f535521f7bc022430ce8e12008f",
        strip_prefix = "mio-0.6.21",
        build_file = Label("//proto/raze/remote:BUILD.mio-0.6.21.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__mio_uds__0_6_7",
        url = "https://crates.io/api/v1/crates/mio-uds/0.6.7/download",
        type = "tar.gz",
        sha256 = "966257a94e196b11bb43aca423754d87429960a768de9414f3691d6957abf125",
        strip_prefix = "mio-uds-0.6.7",
        build_file = Label("//proto/raze/remote:BUILD.mio-uds-0.6.7.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__miow__0_2_1",
        url = "https://crates.io/api/v1/crates/miow/0.2.1/download",
        type = "tar.gz",
        sha256 = "8c1f2f3b1cf331de6896aabf6e9d55dca90356cc9960cca7eaaf408a355ae919",
        strip_prefix = "miow-0.2.1",
        build_file = Label("//proto/raze/remote:BUILD.miow-0.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__net2__0_2_33",
        url = "https://crates.io/api/v1/crates/net2/0.2.33/download",
        type = "tar.gz",
        sha256 = "42550d9fb7b6684a6d404d9fa7250c2eb2646df731d1c06afc06dcee9e1bcf88",
        strip_prefix = "net2-0.2.33",
        build_file = Label("//proto/raze/remote:BUILD.net2-0.2.33.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__num_cpus__1_13_0",
        url = "https://crates.io/api/v1/crates/num_cpus/1.13.0/download",
        type = "tar.gz",
        sha256 = "05499f3756671c15885fee9034446956fff3f243d6077b91e5767df161f766b3",
        strip_prefix = "num_cpus-1.13.0",
        build_file = Label("//proto/raze/remote:BUILD.num_cpus-1.13.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__parking_lot__0_9_0",
        url = "https://crates.io/api/v1/crates/parking_lot/0.9.0/download",
        type = "tar.gz",
        sha256 = "f842b1982eb6c2fe34036a4fbfb06dd185a3f5c8edfaacdf7d1ea10b07de6252",
        strip_prefix = "parking_lot-0.9.0",
        build_file = Label("//proto/raze/remote:BUILD.parking_lot-0.9.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__parking_lot_core__0_6_2",
        url = "https://crates.io/api/v1/crates/parking_lot_core/0.6.2/download",
        type = "tar.gz",
        sha256 = "b876b1b9e7ac6e1a74a6da34d25c42e17e8862aa409cbbbdcfc8d86c6f3bc62b",
        strip_prefix = "parking_lot_core-0.6.2",
        build_file = Label("//proto/raze/remote:BUILD.parking_lot_core-0.6.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__protobuf__2_8_2",
        url = "https://crates.io/api/v1/crates/protobuf/2.8.2/download",
        type = "tar.gz",
        sha256 = "70731852eec72c56d11226c8a5f96ad5058a3dab73647ca5f7ee351e464f2571",
        strip_prefix = "protobuf-2.8.2",
        patches = [
            "@rules_rust//proto/raze/patch:protobuf-2.8.2.patch",
        ],
        patch_args = [
            "-p1",
        ],
        build_file = Label("//proto/raze/remote:BUILD.protobuf-2.8.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__protobuf_codegen__2_8_2",
        url = "https://crates.io/api/v1/crates/protobuf-codegen/2.8.2/download",
        type = "tar.gz",
        sha256 = "3d74b9cbbf2ac9a7169c85a3714ec16c51ee9ec7cfd511549527e9a7df720795",
        strip_prefix = "protobuf-codegen-2.8.2",
        build_file = Label("//proto/raze/remote:BUILD.protobuf-codegen-2.8.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__redox_syscall__0_1_56",
        url = "https://crates.io/api/v1/crates/redox_syscall/0.1.56/download",
        type = "tar.gz",
        sha256 = "2439c63f3f6139d1b57529d16bc3b8bb855230c8efcc5d3a896c8bea7c3b1e84",
        strip_prefix = "redox_syscall-0.1.56",
        build_file = Label("//proto/raze/remote:BUILD.redox_syscall-0.1.56.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__rustc_version__0_2_3",
        url = "https://crates.io/api/v1/crates/rustc_version/0.2.3/download",
        type = "tar.gz",
        sha256 = "138e3e0acb6c9fb258b19b67cb8abd63c00679d2851805ea151465464fe9030a",
        strip_prefix = "rustc_version-0.2.3",
        build_file = Label("//proto/raze/remote:BUILD.rustc_version-0.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__safemem__0_3_3",
        url = "https://crates.io/api/v1/crates/safemem/0.3.3/download",
        type = "tar.gz",
        sha256 = "ef703b7cb59335eae2eb93ceb664c0eb7ea6bf567079d843e09420219668e072",
        strip_prefix = "safemem-0.3.3",
        build_file = Label("//proto/raze/remote:BUILD.safemem-0.3.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__scoped_tls__0_1_2",
        url = "https://crates.io/api/v1/crates/scoped-tls/0.1.2/download",
        type = "tar.gz",
        sha256 = "332ffa32bf586782a3efaeb58f127980944bbc8c4d6913a86107ac2a5ab24b28",
        strip_prefix = "scoped-tls-0.1.2",
        build_file = Label("//proto/raze/remote:BUILD.scoped-tls-0.1.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__scopeguard__1_1_0",
        url = "https://crates.io/api/v1/crates/scopeguard/1.1.0/download",
        type = "tar.gz",
        sha256 = "d29ab0c6d3fc0ee92fe66e2d99f700eab17a8d57d1c1d3b748380fb20baa78cd",
        strip_prefix = "scopeguard-1.1.0",
        build_file = Label("//proto/raze/remote:BUILD.scopeguard-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__semver__0_9_0",
        url = "https://crates.io/api/v1/crates/semver/0.9.0/download",
        type = "tar.gz",
        sha256 = "1d7eb9ef2c18661902cc47e535f9bc51b78acd254da71d375c2f6720d9a40403",
        strip_prefix = "semver-0.9.0",
        build_file = Label("//proto/raze/remote:BUILD.semver-0.9.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__semver_parser__0_7_0",
        url = "https://crates.io/api/v1/crates/semver-parser/0.7.0/download",
        type = "tar.gz",
        sha256 = "388a1df253eca08550bef6c72392cfe7c30914bf41df5269b68cbd6ff8f570a3",
        strip_prefix = "semver-parser-0.7.0",
        build_file = Label("//proto/raze/remote:BUILD.semver-parser-0.7.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__slab__0_3_0",
        url = "https://crates.io/api/v1/crates/slab/0.3.0/download",
        type = "tar.gz",
        sha256 = "17b4fcaed89ab08ef143da37bc52adbcc04d4a69014f4c1208d6b51f0c47bc23",
        strip_prefix = "slab-0.3.0",
        build_file = Label("//proto/raze/remote:BUILD.slab-0.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__slab__0_4_2",
        url = "https://crates.io/api/v1/crates/slab/0.4.2/download",
        type = "tar.gz",
        sha256 = "c111b5bd5695e56cffe5129854aa230b39c93a305372fdbb2668ca2394eea9f8",
        strip_prefix = "slab-0.4.2",
        build_file = Label("//proto/raze/remote:BUILD.slab-0.4.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__smallvec__0_6_13",
        url = "https://crates.io/api/v1/crates/smallvec/0.6.13/download",
        type = "tar.gz",
        sha256 = "f7b0758c52e15a8b5e3691eae6cc559f08eee9406e548a4477ba4e67770a82b6",
        strip_prefix = "smallvec-0.6.13",
        build_file = Label("//proto/raze/remote:BUILD.smallvec-0.6.13.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__tls_api__0_1_22",
        url = "https://crates.io/api/v1/crates/tls-api/0.1.22/download",
        type = "tar.gz",
        sha256 = "049c03787a0595182357fbd487577947f4351b78ce20c3668f6d49f17feb13d1",
        strip_prefix = "tls-api-0.1.22",
        build_file = Label("//proto/raze/remote:BUILD.tls-api-0.1.22.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__tls_api_stub__0_1_22",
        url = "https://crates.io/api/v1/crates/tls-api-stub/0.1.22/download",
        type = "tar.gz",
        sha256 = "c9a0cc8c149724db9de7d73a0e1bc80b1a74f5394f08c6f301e11f9c35fa061e",
        strip_prefix = "tls-api-stub-0.1.22",
        build_file = Label("//proto/raze/remote:BUILD.tls-api-stub-0.1.22.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__tokio__0_1_22",
        url = "https://crates.io/api/v1/crates/tokio/0.1.22/download",
        type = "tar.gz",
        sha256 = "5a09c0b5bb588872ab2f09afa13ee6e9dac11e10a0ec9e8e3ba39a5a5d530af6",
        strip_prefix = "tokio-0.1.22",
        build_file = Label("//proto/raze/remote:BUILD.tokio-0.1.22.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__tokio_codec__0_1_2",
        url = "https://crates.io/api/v1/crates/tokio-codec/0.1.2/download",
        type = "tar.gz",
        sha256 = "25b2998660ba0e70d18684de5d06b70b70a3a747469af9dea7618cc59e75976b",
        strip_prefix = "tokio-codec-0.1.2",
        build_file = Label("//proto/raze/remote:BUILD.tokio-codec-0.1.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__tokio_core__0_1_17",
        url = "https://crates.io/api/v1/crates/tokio-core/0.1.17/download",
        type = "tar.gz",
        sha256 = "aeeffbbb94209023feaef3c196a41cbcdafa06b4a6f893f68779bb5e53796f71",
        strip_prefix = "tokio-core-0.1.17",
        build_file = Label("//proto/raze/remote:BUILD.tokio-core-0.1.17.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__tokio_current_thread__0_1_7",
        url = "https://crates.io/api/v1/crates/tokio-current-thread/0.1.7/download",
        type = "tar.gz",
        sha256 = "b1de0e32a83f131e002238d7ccde18211c0a5397f60cbfffcb112868c2e0e20e",
        strip_prefix = "tokio-current-thread-0.1.7",
        build_file = Label("//proto/raze/remote:BUILD.tokio-current-thread-0.1.7.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__tokio_executor__0_1_10",
        url = "https://crates.io/api/v1/crates/tokio-executor/0.1.10/download",
        type = "tar.gz",
        sha256 = "fb2d1b8f4548dbf5e1f7818512e9c406860678f29c300cdf0ebac72d1a3a1671",
        strip_prefix = "tokio-executor-0.1.10",
        build_file = Label("//proto/raze/remote:BUILD.tokio-executor-0.1.10.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__tokio_fs__0_1_7",
        url = "https://crates.io/api/v1/crates/tokio-fs/0.1.7/download",
        type = "tar.gz",
        sha256 = "297a1206e0ca6302a0eed35b700d292b275256f596e2f3fea7729d5e629b6ff4",
        strip_prefix = "tokio-fs-0.1.7",
        build_file = Label("//proto/raze/remote:BUILD.tokio-fs-0.1.7.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__tokio_io__0_1_13",
        url = "https://crates.io/api/v1/crates/tokio-io/0.1.13/download",
        type = "tar.gz",
        sha256 = "57fc868aae093479e3131e3d165c93b1c7474109d13c90ec0dda2a1bbfff0674",
        strip_prefix = "tokio-io-0.1.13",
        build_file = Label("//proto/raze/remote:BUILD.tokio-io-0.1.13.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__tokio_reactor__0_1_12",
        url = "https://crates.io/api/v1/crates/tokio-reactor/0.1.12/download",
        type = "tar.gz",
        sha256 = "09bc590ec4ba8ba87652da2068d150dcada2cfa2e07faae270a5e0409aa51351",
        strip_prefix = "tokio-reactor-0.1.12",
        build_file = Label("//proto/raze/remote:BUILD.tokio-reactor-0.1.12.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__tokio_sync__0_1_8",
        url = "https://crates.io/api/v1/crates/tokio-sync/0.1.8/download",
        type = "tar.gz",
        sha256 = "edfe50152bc8164fcc456dab7891fa9bf8beaf01c5ee7e1dd43a397c3cf87dee",
        strip_prefix = "tokio-sync-0.1.8",
        build_file = Label("//proto/raze/remote:BUILD.tokio-sync-0.1.8.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__tokio_tcp__0_1_4",
        url = "https://crates.io/api/v1/crates/tokio-tcp/0.1.4/download",
        type = "tar.gz",
        sha256 = "98df18ed66e3b72e742f185882a9e201892407957e45fbff8da17ae7a7c51f72",
        strip_prefix = "tokio-tcp-0.1.4",
        build_file = Label("//proto/raze/remote:BUILD.tokio-tcp-0.1.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__tokio_threadpool__0_1_18",
        url = "https://crates.io/api/v1/crates/tokio-threadpool/0.1.18/download",
        type = "tar.gz",
        sha256 = "df720b6581784c118f0eb4310796b12b1d242a7eb95f716a8367855325c25f89",
        strip_prefix = "tokio-threadpool-0.1.18",
        build_file = Label("//proto/raze/remote:BUILD.tokio-threadpool-0.1.18.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__tokio_timer__0_1_2",
        url = "https://crates.io/api/v1/crates/tokio-timer/0.1.2/download",
        type = "tar.gz",
        sha256 = "6131e780037787ff1b3f8aad9da83bca02438b72277850dd6ad0d455e0e20efc",
        strip_prefix = "tokio-timer-0.1.2",
        build_file = Label("//proto/raze/remote:BUILD.tokio-timer-0.1.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__tokio_timer__0_2_13",
        url = "https://crates.io/api/v1/crates/tokio-timer/0.2.13/download",
        type = "tar.gz",
        sha256 = "93044f2d313c95ff1cb7809ce9a7a05735b012288a888b62d4434fd58c94f296",
        strip_prefix = "tokio-timer-0.2.13",
        build_file = Label("//proto/raze/remote:BUILD.tokio-timer-0.2.13.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__tokio_tls_api__0_1_22",
        url = "https://crates.io/api/v1/crates/tokio-tls-api/0.1.22/download",
        type = "tar.gz",
        sha256 = "68d0e040d5b1f4cfca70ec4f371229886a5de5bb554d272a4a8da73004a7b2c9",
        strip_prefix = "tokio-tls-api-0.1.22",
        build_file = Label("//proto/raze/remote:BUILD.tokio-tls-api-0.1.22.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__tokio_udp__0_1_6",
        url = "https://crates.io/api/v1/crates/tokio-udp/0.1.6/download",
        type = "tar.gz",
        sha256 = "e2a0b10e610b39c38b031a2fcab08e4b82f16ece36504988dcbd81dbba650d82",
        strip_prefix = "tokio-udp-0.1.6",
        build_file = Label("//proto/raze/remote:BUILD.tokio-udp-0.1.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__tokio_uds__0_1_7",
        url = "https://crates.io/api/v1/crates/tokio-uds/0.1.7/download",
        type = "tar.gz",
        sha256 = "65ae5d255ce739e8537221ed2942e0445f4b3b813daebac1c0050ddaaa3587f9",
        strip_prefix = "tokio-uds-0.1.7",
        build_file = Label("//proto/raze/remote:BUILD.tokio-uds-0.1.7.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__tokio_uds__0_2_6",
        url = "https://crates.io/api/v1/crates/tokio-uds/0.2.6/download",
        type = "tar.gz",
        sha256 = "5076db410d6fdc6523df7595447629099a1fdc47b3d9f896220780fa48faf798",
        strip_prefix = "tokio-uds-0.2.6",
        build_file = Label("//proto/raze/remote:BUILD.tokio-uds-0.2.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__unix_socket__0_5_0",
        url = "https://crates.io/api/v1/crates/unix_socket/0.5.0/download",
        type = "tar.gz",
        sha256 = "6aa2700417c405c38f5e6902d699345241c28c0b7ade4abaad71e35a87eb1564",
        strip_prefix = "unix_socket-0.5.0",
        build_file = Label("//proto/raze/remote:BUILD.unix_socket-0.5.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__void__1_0_2",
        url = "https://crates.io/api/v1/crates/void/1.0.2/download",
        type = "tar.gz",
        sha256 = "6a02e4885ed3bc0f2de90ea6dd45ebcbb66dacffe03547fadbb0eeae2770887d",
        strip_prefix = "void-1.0.2",
        build_file = Label("//proto/raze/remote:BUILD.void-1.0.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__winapi__0_2_8",
        url = "https://crates.io/api/v1/crates/winapi/0.2.8/download",
        type = "tar.gz",
        sha256 = "167dc9d6949a9b857f3451275e911c3f44255842c1f7a76f33c55103a909087a",
        strip_prefix = "winapi-0.2.8",
        build_file = Label("//proto/raze/remote:BUILD.winapi-0.2.8.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__winapi__0_3_8",
        url = "https://crates.io/api/v1/crates/winapi/0.3.8/download",
        type = "tar.gz",
        sha256 = "8093091eeb260906a183e6ae1abdba2ef5ef2257a21801128899c3fc699229c6",
        strip_prefix = "winapi-0.3.8",
        build_file = Label("//proto/raze/remote:BUILD.winapi-0.3.8.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__winapi_build__0_1_1",
        url = "https://crates.io/api/v1/crates/winapi-build/0.1.1/download",
        type = "tar.gz",
        sha256 = "2d315eee3b34aca4797b2da6b13ed88266e6d612562a0c46390af8299fc699bc",
        strip_prefix = "winapi-build-0.1.1",
        build_file = Label("//proto/raze/remote:BUILD.winapi-build-0.1.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__winapi_i686_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-i686-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("//proto/raze/remote:BUILD.winapi-i686-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__winapi_x86_64_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-x86_64-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("//proto/raze/remote:BUILD.winapi-x86_64-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_proto__ws2_32_sys__0_2_1",
        url = "https://crates.io/api/v1/crates/ws2_32-sys/0.2.1/download",
        type = "tar.gz",
        sha256 = "d59cefebd0c892fa2dd6de581e937301d8552cb44489cdff035c6187cb63fa5e",
        strip_prefix = "ws2_32-sys-0.2.1",
        build_file = Label("//proto/raze/remote:BUILD.ws2_32-sys-0.2.1.bazel"),
    )
