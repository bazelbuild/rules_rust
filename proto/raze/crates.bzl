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
        name = "raze__arrayvec__0_4_7",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/arrayvec/arrayvec-0.4.7.crate",
        type = "tar.gz",
        sha256 = "a1e964f9e24d588183fcb43503abda40d288c8657dfc27311516ce2f05675aef",
        strip_prefix = "arrayvec-0.4.7",
        build_file = Label("//proto/raze/remote:arrayvec-0.4.7.BUILD"),
    )

    _new_http_archive(
        name = "raze__base64__0_9_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/base64/base64-0.9.3.crate",
        type = "tar.gz",
        sha256 = "489d6c0ed21b11d038c31b6ceccca973e65d73ba3bd8ecb9a2babf5546164643",
        strip_prefix = "base64-0.9.3",
        build_file = Label("//proto/raze/remote:base64-0.9.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__bitflags__1_0_4",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/bitflags/bitflags-1.0.4.crate",
        type = "tar.gz",
        sha256 = "228047a76f468627ca71776ecdebd732a3423081fcf5125585bcd7c49886ce12",
        strip_prefix = "bitflags-1.0.4",
        build_file = Label("//proto/raze/remote:bitflags-1.0.4.BUILD"),
    )

    _new_http_archive(
        name = "raze__byteorder__1_2_7",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/byteorder/byteorder-1.2.7.crate",
        type = "tar.gz",
        sha256 = "94f88df23a25417badc922ab0f5716cc1330e87f71ddd9203b3a3ccd9cedf75d",
        strip_prefix = "byteorder-1.2.7",
        build_file = Label("//proto/raze/remote:byteorder-1.2.7.BUILD"),
    )

    _new_http_archive(
        name = "raze__bytes__0_4_10",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/bytes/bytes-0.4.10.crate",
        type = "tar.gz",
        sha256 = "0ce55bd354b095246fc34caf4e9e242f5297a7fd938b090cadfea6eee614aa62",
        strip_prefix = "bytes-0.4.10",
        build_file = Label("//proto/raze/remote:bytes-0.4.10.BUILD"),
    )

    _new_http_archive(
        name = "raze__cfg_if__0_1_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/cfg-if/cfg-if-0.1.6.crate",
        type = "tar.gz",
        sha256 = "082bb9b28e00d3c9d39cc03e64ce4cea0f1bb9b3fde493f0cbc008472d22bdf4",
        strip_prefix = "cfg-if-0.1.6",
        build_file = Label("//proto/raze/remote:cfg-if-0.1.6.BUILD"),
    )

    _new_http_archive(
        name = "raze__cloudabi__0_0_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/cloudabi/cloudabi-0.0.3.crate",
        type = "tar.gz",
        sha256 = "ddfc5b9aa5d4507acaf872de71051dfd0e309860e88966e1051e462a077aac4f",
        strip_prefix = "cloudabi-0.0.3",
        build_file = Label("//proto/raze/remote:cloudabi-0.0.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__crossbeam_deque__0_6_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crossbeam-deque/crossbeam-deque-0.6.2.crate",
        type = "tar.gz",
        sha256 = "4fe1b6f945f824c7a25afe44f62e25d714c0cc523f8e99d8db5cd1026e1269d3",
        strip_prefix = "crossbeam-deque-0.6.2",
        build_file = Label("//proto/raze/remote:crossbeam-deque-0.6.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__crossbeam_epoch__0_6_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crossbeam-epoch/crossbeam-epoch-0.6.1.crate",
        type = "tar.gz",
        sha256 = "2449aaa4ec7ef96e5fb24db16024b935df718e9ae1cec0a1e68feeca2efca7b8",
        strip_prefix = "crossbeam-epoch-0.6.1",
        build_file = Label("//proto/raze/remote:crossbeam-epoch-0.6.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__crossbeam_utils__0_5_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crossbeam-utils/crossbeam-utils-0.5.0.crate",
        type = "tar.gz",
        sha256 = "677d453a17e8bd2b913fa38e8b9cf04bcdbb5be790aa294f2389661d72036015",
        strip_prefix = "crossbeam-utils-0.5.0",
        build_file = Label("//proto/raze/remote:crossbeam-utils-0.5.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__crossbeam_utils__0_6_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crossbeam-utils/crossbeam-utils-0.6.0.crate",
        type = "tar.gz",
        sha256 = "6efda20eef4ccf2a862d442a1e0319d568f9133e16a085a1f8126fe9b6da852d",
        strip_prefix = "crossbeam-utils-0.6.0",
        build_file = Label("//proto/raze/remote:crossbeam-utils-0.6.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__fuchsia_zircon__0_3_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/fuchsia-zircon/fuchsia-zircon-0.3.3.crate",
        type = "tar.gz",
        sha256 = "2e9763c69ebaae630ba35f74888db465e49e259ba1bc0eda7d06f4a067615d82",
        strip_prefix = "fuchsia-zircon-0.3.3",
        build_file = Label("//proto/raze/remote:fuchsia-zircon-0.3.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__fuchsia_zircon_sys__0_3_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/fuchsia-zircon-sys/fuchsia-zircon-sys-0.3.3.crate",
        type = "tar.gz",
        sha256 = "3dcaa9ae7725d12cdb85b3ad99a434db70b468c09ded17e012d86b5c1010f7a7",
        strip_prefix = "fuchsia-zircon-sys-0.3.3",
        build_file = Label("//proto/raze/remote:fuchsia-zircon-sys-0.3.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__futures__0_1_25",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/futures/futures-0.1.25.crate",
        type = "tar.gz",
        sha256 = "49e7653e374fe0d0c12de4250f0bdb60680b8c80eed558c5c7538eec9c89e21b",
        strip_prefix = "futures-0.1.25",
        build_file = Label("//proto/raze/remote:futures-0.1.25.BUILD"),
    )

    _new_http_archive(
        name = "raze__futures_cpupool__0_1_8",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/futures-cpupool/futures-cpupool-0.1.8.crate",
        type = "tar.gz",
        sha256 = "ab90cde24b3319636588d0c35fe03b1333857621051837ed769faefb4c2162e4",
        strip_prefix = "futures-cpupool-0.1.8",
        build_file = Label("//proto/raze/remote:futures-cpupool-0.1.8.BUILD"),
    )

    _new_http_archive(
        name = "raze__grpc__0_4_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/grpc/grpc-0.4.0.crate",
        type = "tar.gz",
        sha256 = "3ec0a20eaa2682f7efe0ed9bf749a8264d1da9df9375ddfcec1643f21a4a5ec9",
        strip_prefix = "grpc-0.4.0",
        build_file = Label("//proto/raze/remote:grpc-0.4.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__grpc_compiler__0_4_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/grpc-compiler/grpc-compiler-0.4.0.crate",
        type = "tar.gz",
        sha256 = "ae0ed7696fcbc435a4c7eb90573ea4211a2fb27d74b9a38f784bb0de025a1f18",
        strip_prefix = "grpc-compiler-0.4.0",
        build_file = Label("//proto/raze/remote:grpc-compiler-0.4.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__httpbis__0_6_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/httpbis/httpbis-0.6.1.crate",
        type = "tar.gz",
        sha256 = "08dd97d857b9c194e7bff2e046f5711fa95f2532945497eca6913640eb664060",
        strip_prefix = "httpbis-0.6.1",
        build_file = Label("//proto/raze/remote:httpbis-0.6.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__iovec__0_1_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/iovec/iovec-0.1.2.crate",
        type = "tar.gz",
        sha256 = "dbe6e417e7d0975db6512b90796e8ce223145ac4e33c377e4a42882a0e88bb08",
        strip_prefix = "iovec-0.1.2",
        build_file = Label("//proto/raze/remote:iovec-0.1.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__kernel32_sys__0_2_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/kernel32-sys/kernel32-sys-0.2.2.crate",
        type = "tar.gz",
        sha256 = "7507624b29483431c0ba2d82aece8ca6cdba9382bff4ddd0f7490560c056098d",
        strip_prefix = "kernel32-sys-0.2.2",
        build_file = Label("//proto/raze/remote:kernel32-sys-0.2.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__lazy_static__1_2_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/lazy_static/lazy_static-1.2.0.crate",
        type = "tar.gz",
        sha256 = "a374c89b9db55895453a74c1e38861d9deec0b01b405a82516e9d5de4820dea1",
        strip_prefix = "lazy_static-1.2.0",
        build_file = Label("//proto/raze/remote:lazy_static-1.2.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__lazycell__1_2_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/lazycell/lazycell-1.2.0.crate",
        type = "tar.gz",
        sha256 = "ddba4c30a78328befecec92fc94970e53b3ae385827d28620f0f5bb2493081e0",
        strip_prefix = "lazycell-1.2.0",
        build_file = Label("//proto/raze/remote:lazycell-1.2.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__libc__0_2_43",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/libc/libc-0.2.43.crate",
        type = "tar.gz",
        sha256 = "76e3a3ef172f1a0b9a9ff0dd1491ae5e6c948b94479a3021819ba7d860c8645d",
        strip_prefix = "libc-0.2.43",
        build_file = Label("//proto/raze/remote:libc-0.2.43.BUILD"),
    )

    _new_http_archive(
        name = "raze__lock_api__0_1_4",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/lock_api/lock_api-0.1.4.crate",
        type = "tar.gz",
        sha256 = "775751a3e69bde4df9b38dd00a1b5d6ac13791e4223d4a0506577f0dd27cfb7a",
        strip_prefix = "lock_api-0.1.4",
        build_file = Label("//proto/raze/remote:lock_api-0.1.4.BUILD"),
    )

    _new_http_archive(
        name = "raze__log__0_3_9",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/log/log-0.3.9.crate",
        type = "tar.gz",
        sha256 = "e19e8d5c34a3e0e2223db8e060f9e8264aeeb5c5fc64a4ee9965c062211c024b",
        strip_prefix = "log-0.3.9",
        build_file = Label("//proto/raze/remote:log-0.3.9.BUILD"),
    )

    _new_http_archive(
        name = "raze__log__0_4_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/log/log-0.4.6.crate",
        type = "tar.gz",
        sha256 = "c84ec4b527950aa83a329754b01dbe3f58361d1c5efacd1f6d68c494d08a17c6",
        strip_prefix = "log-0.4.6",
        build_file = Label("//proto/raze/remote:log-0.4.6.BUILD"),
    )

    _new_http_archive(
        name = "raze__memoffset__0_2_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/memoffset/memoffset-0.2.1.crate",
        type = "tar.gz",
        sha256 = "0f9dc261e2b62d7a622bf416ea3c5245cdd5d9a7fcc428c0d06804dfce1775b3",
        strip_prefix = "memoffset-0.2.1",
        build_file = Label("//proto/raze/remote:memoffset-0.2.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__mio__0_6_16",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/mio/mio-0.6.16.crate",
        type = "tar.gz",
        sha256 = "71646331f2619b1026cc302f87a2b8b648d5c6dd6937846a16cc8ce0f347f432",
        strip_prefix = "mio-0.6.16",
        build_file = Label("//proto/raze/remote:mio-0.6.16.BUILD"),
    )

    _new_http_archive(
        name = "raze__mio_uds__0_6_7",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/mio-uds/mio-uds-0.6.7.crate",
        type = "tar.gz",
        sha256 = "966257a94e196b11bb43aca423754d87429960a768de9414f3691d6957abf125",
        strip_prefix = "mio-uds-0.6.7",
        build_file = Label("//proto/raze/remote:mio-uds-0.6.7.BUILD"),
    )

    _new_http_archive(
        name = "raze__miow__0_2_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/miow/miow-0.2.1.crate",
        type = "tar.gz",
        sha256 = "8c1f2f3b1cf331de6896aabf6e9d55dca90356cc9960cca7eaaf408a355ae919",
        strip_prefix = "miow-0.2.1",
        build_file = Label("//proto/raze/remote:miow-0.2.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__net2__0_2_33",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/net2/net2-0.2.33.crate",
        type = "tar.gz",
        sha256 = "42550d9fb7b6684a6d404d9fa7250c2eb2646df731d1c06afc06dcee9e1bcf88",
        strip_prefix = "net2-0.2.33",
        build_file = Label("//proto/raze/remote:net2-0.2.33.BUILD"),
    )

    _new_http_archive(
        name = "raze__nodrop__0_1_12",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/nodrop/nodrop-0.1.12.crate",
        type = "tar.gz",
        sha256 = "9a2228dca57108069a5262f2ed8bd2e82496d2e074a06d1ccc7ce1687b6ae0a2",
        strip_prefix = "nodrop-0.1.12",
        build_file = Label("//proto/raze/remote:nodrop-0.1.12.BUILD"),
    )

    _new_http_archive(
        name = "raze__num_cpus__1_8_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/num_cpus/num_cpus-1.8.0.crate",
        type = "tar.gz",
        sha256 = "c51a3322e4bca9d212ad9a158a02abc6934d005490c054a2778df73a70aa0a30",
        strip_prefix = "num_cpus-1.8.0",
        build_file = Label("//proto/raze/remote:num_cpus-1.8.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__owning_ref__0_3_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/owning_ref/owning_ref-0.3.3.crate",
        type = "tar.gz",
        sha256 = "cdf84f41639e037b484f93433aa3897863b561ed65c6e59c7073d7c561710f37",
        strip_prefix = "owning_ref-0.3.3",
        build_file = Label("//proto/raze/remote:owning_ref-0.3.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__parking_lot__0_6_4",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/parking_lot/parking_lot-0.6.4.crate",
        type = "tar.gz",
        sha256 = "f0802bff09003b291ba756dc7e79313e51cc31667e94afbe847def490424cde5",
        strip_prefix = "parking_lot-0.6.4",
        build_file = Label("//proto/raze/remote:parking_lot-0.6.4.BUILD"),
    )

    _new_http_archive(
        name = "raze__parking_lot_core__0_3_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/parking_lot_core/parking_lot_core-0.3.1.crate",
        type = "tar.gz",
        sha256 = "ad7f7e6ebdc79edff6fdcb87a55b620174f7a989e3eb31b65231f4af57f00b8c",
        strip_prefix = "parking_lot_core-0.3.1",
        build_file = Label("//proto/raze/remote:parking_lot_core-0.3.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__protobuf__1_6_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/protobuf/protobuf-1.6.0.crate",
        type = "tar.gz",
        sha256 = "63af89a2e832acba65595d0fc9b8444f5b014356c2a7ad759d6b846c4fa52efb",
        strip_prefix = "protobuf-1.6.0",
        build_file = Label("//proto/raze/remote:protobuf-1.6.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__protobuf_codegen__1_6_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/protobuf-codegen/protobuf-codegen-1.6.0.crate",
        type = "tar.gz",
        sha256 = "89f7524bbb8c6796a164d29cbd8aae51ece80e4ae2040ffb2faa875b2f6823b4",
        strip_prefix = "protobuf-codegen-1.6.0",
        build_file = Label("//proto/raze/remote:protobuf-codegen-1.6.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__rand__0_5_5",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rand/rand-0.5.5.crate",
        type = "tar.gz",
        sha256 = "e464cd887e869cddcae8792a4ee31d23c7edd516700695608f5b98c67ee0131c",
        strip_prefix = "rand-0.5.5",
        build_file = Label("//proto/raze/remote:rand-0.5.5.BUILD"),
    )

    _new_http_archive(
        name = "raze__rand_core__0_2_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rand_core/rand_core-0.2.2.crate",
        type = "tar.gz",
        sha256 = "1961a422c4d189dfb50ffa9320bf1f2a9bd54ecb92792fb9477f99a1045f3372",
        strip_prefix = "rand_core-0.2.2",
        build_file = Label("//proto/raze/remote:rand_core-0.2.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__rand_core__0_3_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rand_core/rand_core-0.3.0.crate",
        type = "tar.gz",
        sha256 = "0905b6b7079ec73b314d4c748701f6931eb79fd97c668caa3f1899b22b32c6db",
        strip_prefix = "rand_core-0.3.0",
        build_file = Label("//proto/raze/remote:rand_core-0.3.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__rustc_version__0_2_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/rustc_version/rustc_version-0.2.3.crate",
        type = "tar.gz",
        sha256 = "138e3e0acb6c9fb258b19b67cb8abd63c00679d2851805ea151465464fe9030a",
        strip_prefix = "rustc_version-0.2.3",
        build_file = Label("//proto/raze/remote:rustc_version-0.2.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__safemem__0_3_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/safemem/safemem-0.3.0.crate",
        type = "tar.gz",
        sha256 = "8dca453248a96cb0749e36ccdfe2b0b4e54a61bfef89fb97ec621eb8e0a93dd9",
        strip_prefix = "safemem-0.3.0",
        build_file = Label("//proto/raze/remote:safemem-0.3.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__scoped_tls__0_1_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/scoped-tls/scoped-tls-0.1.2.crate",
        type = "tar.gz",
        sha256 = "332ffa32bf586782a3efaeb58f127980944bbc8c4d6913a86107ac2a5ab24b28",
        strip_prefix = "scoped-tls-0.1.2",
        build_file = Label("//proto/raze/remote:scoped-tls-0.1.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__scopeguard__0_3_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/scopeguard/scopeguard-0.3.3.crate",
        type = "tar.gz",
        sha256 = "94258f53601af11e6a49f722422f6e3425c52b06245a5cf9bc09908b174f5e27",
        strip_prefix = "scopeguard-0.3.3",
        build_file = Label("//proto/raze/remote:scopeguard-0.3.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__semver__0_9_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/semver/semver-0.9.0.crate",
        type = "tar.gz",
        sha256 = "1d7eb9ef2c18661902cc47e535f9bc51b78acd254da71d375c2f6720d9a40403",
        strip_prefix = "semver-0.9.0",
        build_file = Label("//proto/raze/remote:semver-0.9.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__semver_parser__0_7_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/semver-parser/semver-parser-0.7.0.crate",
        type = "tar.gz",
        sha256 = "388a1df253eca08550bef6c72392cfe7c30914bf41df5269b68cbd6ff8f570a3",
        strip_prefix = "semver-parser-0.7.0",
        build_file = Label("//proto/raze/remote:semver-parser-0.7.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__slab__0_3_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/slab/slab-0.3.0.crate",
        type = "tar.gz",
        sha256 = "17b4fcaed89ab08ef143da37bc52adbcc04d4a69014f4c1208d6b51f0c47bc23",
        strip_prefix = "slab-0.3.0",
        build_file = Label("//proto/raze/remote:slab-0.3.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__slab__0_4_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/slab/slab-0.4.1.crate",
        type = "tar.gz",
        sha256 = "5f9776d6b986f77b35c6cf846c11ad986ff128fe0b2b63a3628e3755e8d3102d",
        strip_prefix = "slab-0.4.1",
        build_file = Label("//proto/raze/remote:slab-0.4.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__smallvec__0_6_5",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/smallvec/smallvec-0.6.5.crate",
        type = "tar.gz",
        sha256 = "153ffa32fd170e9944f7e0838edf824a754ec4c1fc64746fcc9fe1f8fa602e5d",
        strip_prefix = "smallvec-0.6.5",
        build_file = Label("//proto/raze/remote:smallvec-0.6.5.BUILD"),
    )

    _new_http_archive(
        name = "raze__stable_deref_trait__1_1_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/stable_deref_trait/stable_deref_trait-1.1.1.crate",
        type = "tar.gz",
        sha256 = "dba1a27d3efae4351c8051072d619e3ade2820635c3958d826bfea39d59b54c8",
        strip_prefix = "stable_deref_trait-1.1.1",
        build_file = Label("//proto/raze/remote:stable_deref_trait-1.1.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__tls_api__0_1_20",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tls-api/tls-api-0.1.20.crate",
        type = "tar.gz",
        sha256 = "e452fe2fdf40a10715adb3a5f244c7411cdf2ecc887b07160310939785db9182",
        strip_prefix = "tls-api-0.1.20",
        build_file = Label("//proto/raze/remote:tls-api-0.1.20.BUILD"),
    )

    _new_http_archive(
        name = "raze__tls_api_stub__0_1_20",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tls-api-stub/tls-api-stub-0.1.20.crate",
        type = "tar.gz",
        sha256 = "25a2dcddd0fd52bdbedf9b4f0fd1cb884abfa0984e6a54121d4cefdf3d234e4c",
        strip_prefix = "tls-api-stub-0.1.20",
        build_file = Label("//proto/raze/remote:tls-api-stub-0.1.20.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio__0_1_11",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio/tokio-0.1.11.crate",
        type = "tar.gz",
        sha256 = "6e93c78d23cc61aa245a8acd2c4a79c4d7fa7fb5c3ca90d5737029f043a84895",
        strip_prefix = "tokio-0.1.11",
        build_file = Label("//proto/raze/remote:tokio-0.1.11.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_codec__0_1_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-codec/tokio-codec-0.1.1.crate",
        type = "tar.gz",
        sha256 = "5c501eceaf96f0e1793cf26beb63da3d11c738c4a943fdf3746d81d64684c39f",
        strip_prefix = "tokio-codec-0.1.1",
        build_file = Label("//proto/raze/remote:tokio-codec-0.1.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_core__0_1_17",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-core/tokio-core-0.1.17.crate",
        type = "tar.gz",
        sha256 = "aeeffbbb94209023feaef3c196a41cbcdafa06b4a6f893f68779bb5e53796f71",
        strip_prefix = "tokio-core-0.1.17",
        build_file = Label("//proto/raze/remote:tokio-core-0.1.17.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_current_thread__0_1_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-current-thread/tokio-current-thread-0.1.3.crate",
        type = "tar.gz",
        sha256 = "f90fcd90952f0a496d438a976afba8e5c205fb12123f813d8ab3aa1c8436638c",
        strip_prefix = "tokio-current-thread-0.1.3",
        build_file = Label("//proto/raze/remote:tokio-current-thread-0.1.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_executor__0_1_5",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-executor/tokio-executor-0.1.5.crate",
        type = "tar.gz",
        sha256 = "c117b6cf86bb730aab4834f10df96e4dd586eff2c3c27d3781348da49e255bde",
        strip_prefix = "tokio-executor-0.1.5",
        build_file = Label("//proto/raze/remote:tokio-executor-0.1.5.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_fs__0_1_4",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-fs/tokio-fs-0.1.4.crate",
        type = "tar.gz",
        sha256 = "60ae25f6b17d25116d2cba342083abe5255d3c2c79cb21ea11aa049c53bf7c75",
        strip_prefix = "tokio-fs-0.1.4",
        build_file = Label("//proto/raze/remote:tokio-fs-0.1.4.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_io__0_1_10",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-io/tokio-io-0.1.10.crate",
        type = "tar.gz",
        sha256 = "7392fe0a70d5ce0c882c4778116c519bd5dbaa8a7c3ae3d04578b3afafdcda21",
        strip_prefix = "tokio-io-0.1.10",
        build_file = Label("//proto/raze/remote:tokio-io-0.1.10.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_reactor__0_1_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-reactor/tokio-reactor-0.1.6.crate",
        type = "tar.gz",
        sha256 = "4b26fd37f1125738b2170c80b551f69ff6fecb277e6e5ca885e53eec2b005018",
        strip_prefix = "tokio-reactor-0.1.6",
        build_file = Label("//proto/raze/remote:tokio-reactor-0.1.6.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_tcp__0_1_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-tcp/tokio-tcp-0.1.2.crate",
        type = "tar.gz",
        sha256 = "7ad235e9dadd126b2d47f6736f65aa1fdcd6420e66ca63f44177bc78df89f912",
        strip_prefix = "tokio-tcp-0.1.2",
        build_file = Label("//proto/raze/remote:tokio-tcp-0.1.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_threadpool__0_1_8",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-threadpool/tokio-threadpool-0.1.8.crate",
        type = "tar.gz",
        sha256 = "3929aee321c9220ed838ed6c3928be7f9b69986b0e3c22c972a66dbf8a298c68",
        strip_prefix = "tokio-threadpool-0.1.8",
        build_file = Label("//proto/raze/remote:tokio-threadpool-0.1.8.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_timer__0_1_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-timer/tokio-timer-0.1.2.crate",
        type = "tar.gz",
        sha256 = "6131e780037787ff1b3f8aad9da83bca02438b72277850dd6ad0d455e0e20efc",
        strip_prefix = "tokio-timer-0.1.2",
        build_file = Label("//proto/raze/remote:tokio-timer-0.1.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_timer__0_2_7",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-timer/tokio-timer-0.2.7.crate",
        type = "tar.gz",
        sha256 = "3a52f00c97fedb6d535d27f65cccb7181c8dd4c6edc3eda9ea93f6d45d05168e",
        strip_prefix = "tokio-timer-0.2.7",
        build_file = Label("//proto/raze/remote:tokio-timer-0.2.7.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_tls_api__0_1_20",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-tls-api/tokio-tls-api-0.1.20.crate",
        type = "tar.gz",
        sha256 = "c7ac6ebb2f40e7e068cb43e1f3b09b40d7869bcc7e49e7f50610d4e0e75a18d7",
        strip_prefix = "tokio-tls-api-0.1.20",
        build_file = Label("//proto/raze/remote:tokio-tls-api-0.1.20.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_udp__0_1_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-udp/tokio-udp-0.1.2.crate",
        type = "tar.gz",
        sha256 = "da941144b816d0dcda4db3a1ba87596e4df5e860a72b70783fe435891f80601c",
        strip_prefix = "tokio-udp-0.1.2",
        build_file = Label("//proto/raze/remote:tokio-udp-0.1.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_uds__0_1_7",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-uds/tokio-uds-0.1.7.crate",
        type = "tar.gz",
        sha256 = "65ae5d255ce739e8537221ed2942e0445f4b3b813daebac1c0050ddaaa3587f9",
        strip_prefix = "tokio-uds-0.1.7",
        build_file = Label("//proto/raze/remote:tokio-uds-0.1.7.BUILD"),
    )

    _new_http_archive(
        name = "raze__tokio_uds__0_2_3",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/tokio-uds/tokio-uds-0.2.3.crate",
        type = "tar.gz",
        sha256 = "df195376b43508f01570bacc73e13a1de0854dc59e79d1ec09913e8db6dd2a70",
        strip_prefix = "tokio-uds-0.2.3",
        build_file = Label("//proto/raze/remote:tokio-uds-0.2.3.BUILD"),
    )

    _new_http_archive(
        name = "raze__unix_socket__0_5_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/unix_socket/unix_socket-0.5.0.crate",
        type = "tar.gz",
        sha256 = "6aa2700417c405c38f5e6902d699345241c28c0b7ade4abaad71e35a87eb1564",
        strip_prefix = "unix_socket-0.5.0",
        build_file = Label("//proto/raze/remote:unix_socket-0.5.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__unreachable__1_0_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/unreachable/unreachable-1.0.0.crate",
        type = "tar.gz",
        sha256 = "382810877fe448991dfc7f0dd6e3ae5d58088fd0ea5e35189655f84e6814fa56",
        strip_prefix = "unreachable-1.0.0",
        build_file = Label("//proto/raze/remote:unreachable-1.0.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__void__1_0_2",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/void/void-1.0.2.crate",
        type = "tar.gz",
        sha256 = "6a02e4885ed3bc0f2de90ea6dd45ebcbb66dacffe03547fadbb0eeae2770887d",
        strip_prefix = "void-1.0.2",
        build_file = Label("//proto/raze/remote:void-1.0.2.BUILD"),
    )

    _new_http_archive(
        name = "raze__winapi__0_2_8",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi/winapi-0.2.8.crate",
        type = "tar.gz",
        sha256 = "167dc9d6949a9b857f3451275e911c3f44255842c1f7a76f33c55103a909087a",
        strip_prefix = "winapi-0.2.8",
        build_file = Label("//proto/raze/remote:winapi-0.2.8.BUILD"),
    )

    _new_http_archive(
        name = "raze__winapi__0_3_6",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi/winapi-0.3.6.crate",
        type = "tar.gz",
        sha256 = "92c1eb33641e276cfa214a0522acad57be5c56b10cb348b3c5117db75f3ac4b0",
        strip_prefix = "winapi-0.3.6",
        build_file = Label("//proto/raze/remote:winapi-0.3.6.BUILD"),
    )

    _new_http_archive(
        name = "raze__winapi_build__0_1_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi-build/winapi-build-0.1.1.crate",
        type = "tar.gz",
        sha256 = "2d315eee3b34aca4797b2da6b13ed88266e6d612562a0c46390af8299fc699bc",
        strip_prefix = "winapi-build-0.1.1",
        build_file = Label("//proto/raze/remote:winapi-build-0.1.1.BUILD"),
    )

    _new_http_archive(
        name = "raze__winapi_i686_pc_windows_gnu__0_4_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi-i686-pc-windows-gnu/winapi-i686-pc-windows-gnu-0.4.0.crate",
        type = "tar.gz",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("//proto/raze/remote:winapi-i686-pc-windows-gnu-0.4.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__winapi_x86_64_pc_windows_gnu__0_4_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/winapi-x86_64-pc-windows-gnu/winapi-x86_64-pc-windows-gnu-0.4.0.crate",
        type = "tar.gz",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("//proto/raze/remote:winapi-x86_64-pc-windows-gnu-0.4.0.BUILD"),
    )

    _new_http_archive(
        name = "raze__ws2_32_sys__0_2_1",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/ws2_32-sys/ws2_32-sys-0.2.1.crate",
        type = "tar.gz",
        sha256 = "d59cefebd0c892fa2dd6de581e937301d8552cb44489cdff035c6187cb63fa5e",
        strip_prefix = "ws2_32-sys-0.2.1",
        build_file = Label("//proto/raze/remote:ws2_32-sys-0.2.1.BUILD"),
    )
