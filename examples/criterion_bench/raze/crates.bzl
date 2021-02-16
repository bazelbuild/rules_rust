"""
@generated
cargo-raze generated Bazel file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

def rules_rust_examples_criterion_bench_fetch_remote_crates():
    """This function defines a collection of repos and should be called in a WORKSPACE file"""
    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__atty__0_2_14",
        url = "https://crates.io/api/v1/crates/atty/0.2.14/download",
        type = "tar.gz",
        sha256 = "d9b39be18770d11421cdb1b9947a45dd3f37e93092cbf377614828a319d5fee8",
        strip_prefix = "atty-0.2.14",
        build_file = Label("//criterion_bench/raze/remote:BUILD.atty-0.2.14.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__autocfg__1_0_1",
        url = "https://crates.io/api/v1/crates/autocfg/1.0.1/download",
        type = "tar.gz",
        sha256 = "cdb031dd78e28731d87d56cc8ffef4a8f36ca26c38fe2de700543e627f8a464a",
        strip_prefix = "autocfg-1.0.1",
        build_file = Label("//criterion_bench/raze/remote:BUILD.autocfg-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__bitflags__1_2_1",
        url = "https://crates.io/api/v1/crates/bitflags/1.2.1/download",
        type = "tar.gz",
        sha256 = "cf1de2fe8c75bc145a2f577add951f8134889b4795d47466a54a5c846d691693",
        strip_prefix = "bitflags-1.2.1",
        build_file = Label("//criterion_bench/raze/remote:BUILD.bitflags-1.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__bstr__0_2_14",
        url = "https://crates.io/api/v1/crates/bstr/0.2.14/download",
        type = "tar.gz",
        sha256 = "473fc6b38233f9af7baa94fb5852dca389e3d95b8e21c8e3719301462c5d9faf",
        strip_prefix = "bstr-0.2.14",
        build_file = Label("//criterion_bench/raze/remote:BUILD.bstr-0.2.14.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__bumpalo__3_4_0",
        url = "https://crates.io/api/v1/crates/bumpalo/3.4.0/download",
        type = "tar.gz",
        sha256 = "2e8c087f005730276d1096a652e92a8bacee2e2472bcc9715a74d2bec38b5820",
        strip_prefix = "bumpalo-3.4.0",
        build_file = Label("//criterion_bench/raze/remote:BUILD.bumpalo-3.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__byteorder__1_3_4",
        url = "https://crates.io/api/v1/crates/byteorder/1.3.4/download",
        type = "tar.gz",
        sha256 = "08c48aae112d48ed9f069b33538ea9e3e90aa263cfa3d1c24309612b1f7472de",
        strip_prefix = "byteorder-1.3.4",
        build_file = Label("//criterion_bench/raze/remote:BUILD.byteorder-1.3.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__cast__0_2_3",
        url = "https://crates.io/api/v1/crates/cast/0.2.3/download",
        type = "tar.gz",
        sha256 = "4b9434b9a5aa1450faa3f9cb14ea0e8c53bb5d2b3c1bfd1ab4fc03e9f33fbfb0",
        strip_prefix = "cast-0.2.3",
        build_file = Label("//criterion_bench/raze/remote:BUILD.cast-0.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__cfg_if__0_1_10",
        url = "https://crates.io/api/v1/crates/cfg-if/0.1.10/download",
        type = "tar.gz",
        sha256 = "4785bdd1c96b2a846b2bd7cc02e86b6b3dbf14e7e53446c4f54c92a361040822",
        strip_prefix = "cfg-if-0.1.10",
        build_file = Label("//criterion_bench/raze/remote:BUILD.cfg-if-0.1.10.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__cfg_if__1_0_0",
        url = "https://crates.io/api/v1/crates/cfg-if/1.0.0/download",
        type = "tar.gz",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("//criterion_bench/raze/remote:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__clap__2_33_3",
        url = "https://crates.io/api/v1/crates/clap/2.33.3/download",
        type = "tar.gz",
        sha256 = "37e58ac78573c40708d45522f0d80fa2f01cc4f9b4e2bf749807255454312002",
        strip_prefix = "clap-2.33.3",
        build_file = Label("//criterion_bench/raze/remote:BUILD.clap-2.33.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__const_fn__0_4_4",
        url = "https://crates.io/api/v1/crates/const_fn/0.4.4/download",
        type = "tar.gz",
        sha256 = "cd51eab21ab4fd6a3bf889e2d0958c0a6e3a61ad04260325e919e652a2a62826",
        strip_prefix = "const_fn-0.4.4",
        build_file = Label("//criterion_bench/raze/remote:BUILD.const_fn-0.4.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__criterion__0_3_3",
        url = "https://crates.io/api/v1/crates/criterion/0.3.3/download",
        type = "tar.gz",
        sha256 = "70daa7ceec6cf143990669a04c7df13391d55fb27bd4079d252fca774ba244d8",
        strip_prefix = "criterion-0.3.3",
        build_file = Label("//criterion_bench/raze/remote:BUILD.criterion-0.3.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__criterion_plot__0_4_3",
        url = "https://crates.io/api/v1/crates/criterion-plot/0.4.3/download",
        type = "tar.gz",
        sha256 = "e022feadec601fba1649cfa83586381a4ad31c6bf3a9ab7d408118b05dd9889d",
        strip_prefix = "criterion-plot-0.4.3",
        build_file = Label("//criterion_bench/raze/remote:BUILD.criterion-plot-0.4.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__crossbeam_channel__0_5_0",
        url = "https://crates.io/api/v1/crates/crossbeam-channel/0.5.0/download",
        type = "tar.gz",
        sha256 = "dca26ee1f8d361640700bde38b2c37d8c22b3ce2d360e1fc1c74ea4b0aa7d775",
        strip_prefix = "crossbeam-channel-0.5.0",
        build_file = Label("//criterion_bench/raze/remote:BUILD.crossbeam-channel-0.5.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__crossbeam_deque__0_8_0",
        url = "https://crates.io/api/v1/crates/crossbeam-deque/0.8.0/download",
        type = "tar.gz",
        sha256 = "94af6efb46fef72616855b036a624cf27ba656ffc9be1b9a3c931cfc7749a9a9",
        strip_prefix = "crossbeam-deque-0.8.0",
        build_file = Label("//criterion_bench/raze/remote:BUILD.crossbeam-deque-0.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__crossbeam_epoch__0_9_1",
        url = "https://crates.io/api/v1/crates/crossbeam-epoch/0.9.1/download",
        type = "tar.gz",
        sha256 = "a1aaa739f95311c2c7887a76863f500026092fb1dce0161dab577e559ef3569d",
        strip_prefix = "crossbeam-epoch-0.9.1",
        build_file = Label("//criterion_bench/raze/remote:BUILD.crossbeam-epoch-0.9.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__crossbeam_utils__0_8_1",
        url = "https://crates.io/api/v1/crates/crossbeam-utils/0.8.1/download",
        type = "tar.gz",
        sha256 = "02d96d1e189ef58269ebe5b97953da3274d83a93af647c2ddd6f9dab28cedb8d",
        strip_prefix = "crossbeam-utils-0.8.1",
        build_file = Label("//criterion_bench/raze/remote:BUILD.crossbeam-utils-0.8.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__csv__1_1_5",
        url = "https://crates.io/api/v1/crates/csv/1.1.5/download",
        type = "tar.gz",
        sha256 = "f9d58633299b24b515ac72a3f869f8b91306a3cec616a602843a383acd6f9e97",
        strip_prefix = "csv-1.1.5",
        build_file = Label("//criterion_bench/raze/remote:BUILD.csv-1.1.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__csv_core__0_1_10",
        url = "https://crates.io/api/v1/crates/csv-core/0.1.10/download",
        type = "tar.gz",
        sha256 = "2b2466559f260f48ad25fe6317b3c8dac77b5bdb5763ac7d9d6103530663bc90",
        strip_prefix = "csv-core-0.1.10",
        build_file = Label("//criterion_bench/raze/remote:BUILD.csv-core-0.1.10.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__either__1_6_1",
        url = "https://crates.io/api/v1/crates/either/1.6.1/download",
        type = "tar.gz",
        sha256 = "e78d4f1cc4ae33bbfc157ed5d5a5ef3bc29227303d595861deb238fcec4e9457",
        strip_prefix = "either-1.6.1",
        build_file = Label("//criterion_bench/raze/remote:BUILD.either-1.6.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__half__1_6_0",
        url = "https://crates.io/api/v1/crates/half/1.6.0/download",
        type = "tar.gz",
        sha256 = "d36fab90f82edc3c747f9d438e06cf0a491055896f2a279638bb5beed6c40177",
        strip_prefix = "half-1.6.0",
        build_file = Label("//criterion_bench/raze/remote:BUILD.half-1.6.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__hermit_abi__0_1_17",
        url = "https://crates.io/api/v1/crates/hermit-abi/0.1.17/download",
        type = "tar.gz",
        sha256 = "5aca5565f760fb5b220e499d72710ed156fdb74e631659e99377d9ebfbd13ae8",
        strip_prefix = "hermit-abi-0.1.17",
        build_file = Label("//criterion_bench/raze/remote:BUILD.hermit-abi-0.1.17.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__itertools__0_9_0",
        url = "https://crates.io/api/v1/crates/itertools/0.9.0/download",
        type = "tar.gz",
        sha256 = "284f18f85651fe11e8a991b2adb42cb078325c996ed026d994719efcfca1d54b",
        strip_prefix = "itertools-0.9.0",
        build_file = Label("//criterion_bench/raze/remote:BUILD.itertools-0.9.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__itoa__0_4_6",
        url = "https://crates.io/api/v1/crates/itoa/0.4.6/download",
        type = "tar.gz",
        sha256 = "dc6f3ad7b9d11a0c00842ff8de1b60ee58661048eb8049ed33c73594f359d7e6",
        strip_prefix = "itoa-0.4.6",
        build_file = Label("//criterion_bench/raze/remote:BUILD.itoa-0.4.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__js_sys__0_3_46",
        url = "https://crates.io/api/v1/crates/js-sys/0.3.46/download",
        type = "tar.gz",
        sha256 = "cf3d7383929f7c9c7c2d0fa596f325832df98c3704f2c60553080f7127a58175",
        strip_prefix = "js-sys-0.3.46",
        build_file = Label("//criterion_bench/raze/remote:BUILD.js-sys-0.3.46.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__lazy_static__1_4_0",
        url = "https://crates.io/api/v1/crates/lazy_static/1.4.0/download",
        type = "tar.gz",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        strip_prefix = "lazy_static-1.4.0",
        build_file = Label("//criterion_bench/raze/remote:BUILD.lazy_static-1.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__libc__0_2_81",
        url = "https://crates.io/api/v1/crates/libc/0.2.81/download",
        type = "tar.gz",
        sha256 = "1482821306169ec4d07f6aca392a4681f66c75c9918aa49641a2595db64053cb",
        strip_prefix = "libc-0.2.81",
        build_file = Label("//criterion_bench/raze/remote:BUILD.libc-0.2.81.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__log__0_4_11",
        url = "https://crates.io/api/v1/crates/log/0.4.11/download",
        type = "tar.gz",
        sha256 = "4fabed175da42fed1fa0746b0ea71f412aa9d35e76e95e59b192c64b9dc2bf8b",
        strip_prefix = "log-0.4.11",
        build_file = Label("//criterion_bench/raze/remote:BUILD.log-0.4.11.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__memchr__2_3_4",
        url = "https://crates.io/api/v1/crates/memchr/2.3.4/download",
        type = "tar.gz",
        sha256 = "0ee1c47aaa256ecabcaea351eae4a9b01ef39ed810004e298d2511ed284b1525",
        strip_prefix = "memchr-2.3.4",
        build_file = Label("//criterion_bench/raze/remote:BUILD.memchr-2.3.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__memoffset__0_6_1",
        url = "https://crates.io/api/v1/crates/memoffset/0.6.1/download",
        type = "tar.gz",
        sha256 = "157b4208e3059a8f9e78d559edc658e13df41410cb3ae03979c83130067fdd87",
        strip_prefix = "memoffset-0.6.1",
        build_file = Label("//criterion_bench/raze/remote:BUILD.memoffset-0.6.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__num_traits__0_2_14",
        url = "https://crates.io/api/v1/crates/num-traits/0.2.14/download",
        type = "tar.gz",
        sha256 = "9a64b1ec5cda2586e284722486d802acf1f7dbdc623e2bfc57e65ca1cd099290",
        strip_prefix = "num-traits-0.2.14",
        build_file = Label("//criterion_bench/raze/remote:BUILD.num-traits-0.2.14.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__num_cpus__1_13_0",
        url = "https://crates.io/api/v1/crates/num_cpus/1.13.0/download",
        type = "tar.gz",
        sha256 = "05499f3756671c15885fee9034446956fff3f243d6077b91e5767df161f766b3",
        strip_prefix = "num_cpus-1.13.0",
        build_file = Label("//criterion_bench/raze/remote:BUILD.num_cpus-1.13.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__oorandom__11_1_3",
        url = "https://crates.io/api/v1/crates/oorandom/11.1.3/download",
        type = "tar.gz",
        sha256 = "0ab1bc2a289d34bd04a330323ac98a1b4bc82c9d9fcb1e66b63caa84da26b575",
        strip_prefix = "oorandom-11.1.3",
        build_file = Label("//criterion_bench/raze/remote:BUILD.oorandom-11.1.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__plotters__0_2_15",
        url = "https://crates.io/api/v1/crates/plotters/0.2.15/download",
        type = "tar.gz",
        sha256 = "0d1685fbe7beba33de0330629da9d955ac75bd54f33d7b79f9a895590124f6bb",
        strip_prefix = "plotters-0.2.15",
        build_file = Label("//criterion_bench/raze/remote:BUILD.plotters-0.2.15.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__proc_macro2__1_0_24",
        url = "https://crates.io/api/v1/crates/proc-macro2/1.0.24/download",
        type = "tar.gz",
        sha256 = "1e0704ee1a7e00d7bb417d0770ea303c1bccbabf0ef1667dae92b5967f5f8a71",
        strip_prefix = "proc-macro2-1.0.24",
        build_file = Label("//criterion_bench/raze/remote:BUILD.proc-macro2-1.0.24.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__quote__1_0_7",
        url = "https://crates.io/api/v1/crates/quote/1.0.7/download",
        type = "tar.gz",
        sha256 = "aa563d17ecb180e500da1cfd2b028310ac758de548efdd203e18f283af693f37",
        strip_prefix = "quote-1.0.7",
        build_file = Label("//criterion_bench/raze/remote:BUILD.quote-1.0.7.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__rayon__1_5_0",
        url = "https://crates.io/api/v1/crates/rayon/1.5.0/download",
        type = "tar.gz",
        sha256 = "8b0d8e0819fadc20c74ea8373106ead0600e3a67ef1fe8da56e39b9ae7275674",
        strip_prefix = "rayon-1.5.0",
        build_file = Label("//criterion_bench/raze/remote:BUILD.rayon-1.5.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__rayon_core__1_9_0",
        url = "https://crates.io/api/v1/crates/rayon-core/1.9.0/download",
        type = "tar.gz",
        sha256 = "9ab346ac5921dc62ffa9f89b7a773907511cdfa5490c572ae9be1be33e8afa4a",
        strip_prefix = "rayon-core-1.9.0",
        build_file = Label("//criterion_bench/raze/remote:BUILD.rayon-core-1.9.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__regex__1_4_2",
        url = "https://crates.io/api/v1/crates/regex/1.4.2/download",
        type = "tar.gz",
        sha256 = "38cf2c13ed4745de91a5eb834e11c00bcc3709e773173b2ce4c56c9fbde04b9c",
        strip_prefix = "regex-1.4.2",
        build_file = Label("//criterion_bench/raze/remote:BUILD.regex-1.4.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__regex_automata__0_1_9",
        url = "https://crates.io/api/v1/crates/regex-automata/0.1.9/download",
        type = "tar.gz",
        sha256 = "ae1ded71d66a4a97f5e961fd0cb25a5f366a42a41570d16a763a69c092c26ae4",
        strip_prefix = "regex-automata-0.1.9",
        build_file = Label("//criterion_bench/raze/remote:BUILD.regex-automata-0.1.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__regex_syntax__0_6_21",
        url = "https://crates.io/api/v1/crates/regex-syntax/0.6.21/download",
        type = "tar.gz",
        sha256 = "3b181ba2dcf07aaccad5448e8ead58db5b742cf85dfe035e2227f137a539a189",
        strip_prefix = "regex-syntax-0.6.21",
        build_file = Label("//criterion_bench/raze/remote:BUILD.regex-syntax-0.6.21.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__rustc_version__0_2_3",
        url = "https://crates.io/api/v1/crates/rustc_version/0.2.3/download",
        type = "tar.gz",
        sha256 = "138e3e0acb6c9fb258b19b67cb8abd63c00679d2851805ea151465464fe9030a",
        strip_prefix = "rustc_version-0.2.3",
        build_file = Label("//criterion_bench/raze/remote:BUILD.rustc_version-0.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__ryu__1_0_5",
        url = "https://crates.io/api/v1/crates/ryu/1.0.5/download",
        type = "tar.gz",
        sha256 = "71d301d4193d031abdd79ff7e3dd721168a9572ef3fe51a1517aba235bd8f86e",
        strip_prefix = "ryu-1.0.5",
        build_file = Label("//criterion_bench/raze/remote:BUILD.ryu-1.0.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__same_file__1_0_6",
        url = "https://crates.io/api/v1/crates/same-file/1.0.6/download",
        type = "tar.gz",
        sha256 = "93fc1dc3aaa9bfed95e02e6eadabb4baf7e3078b0bd1b4d7b6b0b68378900502",
        strip_prefix = "same-file-1.0.6",
        build_file = Label("//criterion_bench/raze/remote:BUILD.same-file-1.0.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__scopeguard__1_1_0",
        url = "https://crates.io/api/v1/crates/scopeguard/1.1.0/download",
        type = "tar.gz",
        sha256 = "d29ab0c6d3fc0ee92fe66e2d99f700eab17a8d57d1c1d3b748380fb20baa78cd",
        strip_prefix = "scopeguard-1.1.0",
        build_file = Label("//criterion_bench/raze/remote:BUILD.scopeguard-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__semver__0_9_0",
        url = "https://crates.io/api/v1/crates/semver/0.9.0/download",
        type = "tar.gz",
        sha256 = "1d7eb9ef2c18661902cc47e535f9bc51b78acd254da71d375c2f6720d9a40403",
        strip_prefix = "semver-0.9.0",
        build_file = Label("//criterion_bench/raze/remote:BUILD.semver-0.9.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__semver_parser__0_7_0",
        url = "https://crates.io/api/v1/crates/semver-parser/0.7.0/download",
        type = "tar.gz",
        sha256 = "388a1df253eca08550bef6c72392cfe7c30914bf41df5269b68cbd6ff8f570a3",
        strip_prefix = "semver-parser-0.7.0",
        build_file = Label("//criterion_bench/raze/remote:BUILD.semver-parser-0.7.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__serde__1_0_118",
        url = "https://crates.io/api/v1/crates/serde/1.0.118/download",
        type = "tar.gz",
        sha256 = "06c64263859d87aa2eb554587e2d23183398d617427327cf2b3d0ed8c69e4800",
        strip_prefix = "serde-1.0.118",
        build_file = Label("//criterion_bench/raze/remote:BUILD.serde-1.0.118.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__serde_cbor__0_11_1",
        url = "https://crates.io/api/v1/crates/serde_cbor/0.11.1/download",
        type = "tar.gz",
        sha256 = "1e18acfa2f90e8b735b2836ab8d538de304cbb6729a7360729ea5a895d15a622",
        strip_prefix = "serde_cbor-0.11.1",
        build_file = Label("//criterion_bench/raze/remote:BUILD.serde_cbor-0.11.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__serde_derive__1_0_118",
        url = "https://crates.io/api/v1/crates/serde_derive/1.0.118/download",
        type = "tar.gz",
        sha256 = "c84d3526699cd55261af4b941e4e725444df67aa4f9e6a3564f18030d12672df",
        strip_prefix = "serde_derive-1.0.118",
        build_file = Label("//criterion_bench/raze/remote:BUILD.serde_derive-1.0.118.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__serde_json__1_0_60",
        url = "https://crates.io/api/v1/crates/serde_json/1.0.60/download",
        type = "tar.gz",
        sha256 = "1500e84d27fe482ed1dc791a56eddc2f230046a040fa908c08bda1d9fb615779",
        strip_prefix = "serde_json-1.0.60",
        build_file = Label("//criterion_bench/raze/remote:BUILD.serde_json-1.0.60.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__syn__1_0_54",
        url = "https://crates.io/api/v1/crates/syn/1.0.54/download",
        type = "tar.gz",
        sha256 = "9a2af957a63d6bd42255c359c93d9bfdb97076bd3b820897ce55ffbfbf107f44",
        strip_prefix = "syn-1.0.54",
        build_file = Label("//criterion_bench/raze/remote:BUILD.syn-1.0.54.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__textwrap__0_11_0",
        url = "https://crates.io/api/v1/crates/textwrap/0.11.0/download",
        type = "tar.gz",
        sha256 = "d326610f408c7a4eb6f51c37c330e496b08506c9457c9d34287ecc38809fb060",
        strip_prefix = "textwrap-0.11.0",
        build_file = Label("//criterion_bench/raze/remote:BUILD.textwrap-0.11.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__tinytemplate__1_1_0",
        url = "https://crates.io/api/v1/crates/tinytemplate/1.1.0/download",
        type = "tar.gz",
        sha256 = "6d3dc76004a03cec1c5932bca4cdc2e39aaa798e3f82363dd94f9adf6098c12f",
        strip_prefix = "tinytemplate-1.1.0",
        build_file = Label("//criterion_bench/raze/remote:BUILD.tinytemplate-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__unicode_width__0_1_8",
        url = "https://crates.io/api/v1/crates/unicode-width/0.1.8/download",
        type = "tar.gz",
        sha256 = "9337591893a19b88d8d87f2cec1e73fad5cdfd10e5a6f349f498ad6ea2ffb1e3",
        strip_prefix = "unicode-width-0.1.8",
        build_file = Label("//criterion_bench/raze/remote:BUILD.unicode-width-0.1.8.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__unicode_xid__0_2_1",
        url = "https://crates.io/api/v1/crates/unicode-xid/0.2.1/download",
        type = "tar.gz",
        sha256 = "f7fe0bb3479651439c9112f72b6c505038574c9fbb575ed1bf3b797fa39dd564",
        strip_prefix = "unicode-xid-0.2.1",
        build_file = Label("//criterion_bench/raze/remote:BUILD.unicode-xid-0.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__walkdir__2_3_1",
        url = "https://crates.io/api/v1/crates/walkdir/2.3.1/download",
        type = "tar.gz",
        sha256 = "777182bc735b6424e1a57516d35ed72cb8019d85c8c9bf536dccb3445c1a2f7d",
        strip_prefix = "walkdir-2.3.1",
        build_file = Label("//criterion_bench/raze/remote:BUILD.walkdir-2.3.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__wasm_bindgen__0_2_69",
        url = "https://crates.io/api/v1/crates/wasm-bindgen/0.2.69/download",
        type = "tar.gz",
        sha256 = "3cd364751395ca0f68cafb17666eee36b63077fb5ecd972bbcd74c90c4bf736e",
        strip_prefix = "wasm-bindgen-0.2.69",
        build_file = Label("//criterion_bench/raze/remote:BUILD.wasm-bindgen-0.2.69.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__wasm_bindgen_backend__0_2_69",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-backend/0.2.69/download",
        type = "tar.gz",
        sha256 = "1114f89ab1f4106e5b55e688b828c0ab0ea593a1ea7c094b141b14cbaaec2d62",
        strip_prefix = "wasm-bindgen-backend-0.2.69",
        build_file = Label("//criterion_bench/raze/remote:BUILD.wasm-bindgen-backend-0.2.69.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__wasm_bindgen_macro__0_2_69",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-macro/0.2.69/download",
        type = "tar.gz",
        sha256 = "7a6ac8995ead1f084a8dea1e65f194d0973800c7f571f6edd70adf06ecf77084",
        strip_prefix = "wasm-bindgen-macro-0.2.69",
        build_file = Label("//criterion_bench/raze/remote:BUILD.wasm-bindgen-macro-0.2.69.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__wasm_bindgen_macro_support__0_2_69",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-macro-support/0.2.69/download",
        type = "tar.gz",
        sha256 = "b5a48c72f299d80557c7c62e37e7225369ecc0c963964059509fbafe917c7549",
        strip_prefix = "wasm-bindgen-macro-support-0.2.69",
        build_file = Label("//criterion_bench/raze/remote:BUILD.wasm-bindgen-macro-support-0.2.69.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__wasm_bindgen_shared__0_2_69",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-shared/0.2.69/download",
        type = "tar.gz",
        sha256 = "7e7811dd7f9398f14cc76efd356f98f03aa30419dea46aa810d71e819fc97158",
        strip_prefix = "wasm-bindgen-shared-0.2.69",
        build_file = Label("//criterion_bench/raze/remote:BUILD.wasm-bindgen-shared-0.2.69.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__web_sys__0_3_46",
        url = "https://crates.io/api/v1/crates/web-sys/0.3.46/download",
        type = "tar.gz",
        sha256 = "222b1ef9334f92a21d3fb53dc3fd80f30836959a90f9274a626d7e06315ba3c3",
        strip_prefix = "web-sys-0.3.46",
        build_file = Label("//criterion_bench/raze/remote:BUILD.web-sys-0.3.46.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__winapi__0_3_9",
        url = "https://crates.io/api/v1/crates/winapi/0.3.9/download",
        type = "tar.gz",
        sha256 = "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419",
        strip_prefix = "winapi-0.3.9",
        build_file = Label("//criterion_bench/raze/remote:BUILD.winapi-0.3.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__winapi_i686_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-i686-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("//criterion_bench/raze/remote:BUILD.winapi-i686-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__winapi_util__0_1_5",
        url = "https://crates.io/api/v1/crates/winapi-util/0.1.5/download",
        type = "tar.gz",
        sha256 = "70ec6ce85bb158151cae5e5c87f95a8e97d2c0c4b001223f33a334e3ce5de178",
        strip_prefix = "winapi-util-0.1.5",
        build_file = Label("//criterion_bench/raze/remote:BUILD.winapi-util-0.1.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_criterion_bench__winapi_x86_64_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-x86_64-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("//criterion_bench/raze/remote:BUILD.winapi-x86_64-pc-windows-gnu-0.4.0.bazel"),
    )
