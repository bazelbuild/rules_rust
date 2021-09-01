"""
@generated
cargo-raze generated Bazel file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

def rules_rust_examples_bench_criterion_fetch_remote_crates():
    """This function defines a collection of repos and should be called in a WORKSPACE file"""
    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__atty__0_2_14",
        url = "https://crates.io/api/v1/crates/atty/0.2.14/download",
        type = "tar.gz",
        sha256 = "d9b39be18770d11421cdb1b9947a45dd3f37e93092cbf377614828a319d5fee8",
        strip_prefix = "atty-0.2.14",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.atty-0.2.14.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__autocfg__1_0_1",
        url = "https://crates.io/api/v1/crates/autocfg/1.0.1/download",
        type = "tar.gz",
        sha256 = "cdb031dd78e28731d87d56cc8ffef4a8f36ca26c38fe2de700543e627f8a464a",
        strip_prefix = "autocfg-1.0.1",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.autocfg-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__bitflags__1_3_2",
        url = "https://crates.io/api/v1/crates/bitflags/1.3.2/download",
        type = "tar.gz",
        sha256 = "bef38d45163c2f1dde094a7dfd33ccf595c92905c8f8f4fdc18d06fb1037718a",
        strip_prefix = "bitflags-1.3.2",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.bitflags-1.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__bstr__0_2_16",
        url = "https://crates.io/api/v1/crates/bstr/0.2.16/download",
        type = "tar.gz",
        sha256 = "90682c8d613ad3373e66de8c6411e0ae2ab2571e879d2efbf73558cc66f21279",
        strip_prefix = "bstr-0.2.16",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.bstr-0.2.16.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__bumpalo__3_7_0",
        url = "https://crates.io/api/v1/crates/bumpalo/3.7.0/download",
        type = "tar.gz",
        sha256 = "9c59e7af012c713f529e7a3ee57ce9b31ddd858d4b512923602f74608b009631",
        strip_prefix = "bumpalo-3.7.0",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.bumpalo-3.7.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__cast__0_2_7",
        url = "https://crates.io/api/v1/crates/cast/0.2.7/download",
        type = "tar.gz",
        sha256 = "4c24dab4283a142afa2fdca129b80ad2c6284e073930f964c3a1293c225ee39a",
        strip_prefix = "cast-0.2.7",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.cast-0.2.7.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__cfg_if__1_0_0",
        url = "https://crates.io/api/v1/crates/cfg-if/1.0.0/download",
        type = "tar.gz",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__clap__2_33_3",
        url = "https://crates.io/api/v1/crates/clap/2.33.3/download",
        type = "tar.gz",
        sha256 = "37e58ac78573c40708d45522f0d80fa2f01cc4f9b4e2bf749807255454312002",
        strip_prefix = "clap-2.33.3",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.clap-2.33.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__criterion__0_3_5",
        url = "https://crates.io/api/v1/crates/criterion/0.3.5/download",
        type = "tar.gz",
        sha256 = "1604dafd25fba2fe2d5895a9da139f8dc9b319a5fe5354ca137cbbce4e178d10",
        strip_prefix = "criterion-0.3.5",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.criterion-0.3.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__criterion_plot__0_4_4",
        url = "https://crates.io/api/v1/crates/criterion-plot/0.4.4/download",
        type = "tar.gz",
        sha256 = "d00996de9f2f7559f7f4dc286073197f83e92256a59ed395f9aac01fe717da57",
        strip_prefix = "criterion-plot-0.4.4",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.criterion-plot-0.4.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__crossbeam_channel__0_5_1",
        url = "https://crates.io/api/v1/crates/crossbeam-channel/0.5.1/download",
        type = "tar.gz",
        sha256 = "06ed27e177f16d65f0f0c22a213e17c696ace5dd64b14258b52f9417ccb52db4",
        strip_prefix = "crossbeam-channel-0.5.1",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.crossbeam-channel-0.5.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__crossbeam_deque__0_8_1",
        url = "https://crates.io/api/v1/crates/crossbeam-deque/0.8.1/download",
        type = "tar.gz",
        sha256 = "6455c0ca19f0d2fbf751b908d5c55c1f5cbc65e03c4225427254b46890bdde1e",
        strip_prefix = "crossbeam-deque-0.8.1",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.crossbeam-deque-0.8.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__crossbeam_epoch__0_9_5",
        url = "https://crates.io/api/v1/crates/crossbeam-epoch/0.9.5/download",
        type = "tar.gz",
        sha256 = "4ec02e091aa634e2c3ada4a392989e7c3116673ef0ac5b72232439094d73b7fd",
        strip_prefix = "crossbeam-epoch-0.9.5",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.crossbeam-epoch-0.9.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__crossbeam_utils__0_8_5",
        url = "https://crates.io/api/v1/crates/crossbeam-utils/0.8.5/download",
        type = "tar.gz",
        sha256 = "d82cfc11ce7f2c3faef78d8a684447b40d503d9681acebed6cb728d45940c4db",
        strip_prefix = "crossbeam-utils-0.8.5",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.crossbeam-utils-0.8.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__csv__1_1_6",
        url = "https://crates.io/api/v1/crates/csv/1.1.6/download",
        type = "tar.gz",
        sha256 = "22813a6dc45b335f9bade10bf7271dc477e81113e89eb251a0bc2a8a81c536e1",
        strip_prefix = "csv-1.1.6",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.csv-1.1.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__csv_core__0_1_10",
        url = "https://crates.io/api/v1/crates/csv-core/0.1.10/download",
        type = "tar.gz",
        sha256 = "2b2466559f260f48ad25fe6317b3c8dac77b5bdb5763ac7d9d6103530663bc90",
        strip_prefix = "csv-core-0.1.10",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.csv-core-0.1.10.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__either__1_6_1",
        url = "https://crates.io/api/v1/crates/either/1.6.1/download",
        type = "tar.gz",
        sha256 = "e78d4f1cc4ae33bbfc157ed5d5a5ef3bc29227303d595861deb238fcec4e9457",
        strip_prefix = "either-1.6.1",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.either-1.6.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__half__1_7_1",
        url = "https://crates.io/api/v1/crates/half/1.7.1/download",
        type = "tar.gz",
        sha256 = "62aca2aba2d62b4a7f5b33f3712cb1b0692779a56fb510499d5c0aa594daeaf3",
        strip_prefix = "half-1.7.1",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.half-1.7.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__hermit_abi__0_1_19",
        url = "https://crates.io/api/v1/crates/hermit-abi/0.1.19/download",
        type = "tar.gz",
        sha256 = "62b467343b94ba476dcb2500d242dadbb39557df889310ac77c5d99100aaac33",
        strip_prefix = "hermit-abi-0.1.19",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.hermit-abi-0.1.19.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__itertools__0_10_1",
        url = "https://crates.io/api/v1/crates/itertools/0.10.1/download",
        type = "tar.gz",
        sha256 = "69ddb889f9d0d08a67338271fa9b62996bc788c7796a5c18cf057420aaed5eaf",
        strip_prefix = "itertools-0.10.1",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.itertools-0.10.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__itoa__0_4_8",
        url = "https://crates.io/api/v1/crates/itoa/0.4.8/download",
        type = "tar.gz",
        sha256 = "b71991ff56294aa922b450139ee08b3bfc70982c6b2c7562771375cf73542dd4",
        strip_prefix = "itoa-0.4.8",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.itoa-0.4.8.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__js_sys__0_3_53",
        url = "https://crates.io/api/v1/crates/js-sys/0.3.53/download",
        type = "tar.gz",
        sha256 = "e4bf49d50e2961077d9c99f4b7997d770a1114f087c3c2e0069b36c13fc2979d",
        strip_prefix = "js-sys-0.3.53",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.js-sys-0.3.53.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__lazy_static__1_4_0",
        url = "https://crates.io/api/v1/crates/lazy_static/1.4.0/download",
        type = "tar.gz",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        strip_prefix = "lazy_static-1.4.0",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.lazy_static-1.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__libc__0_2_101",
        url = "https://crates.io/api/v1/crates/libc/0.2.101/download",
        type = "tar.gz",
        sha256 = "3cb00336871be5ed2c8ed44b60ae9959dc5b9f08539422ed43f09e34ecaeba21",
        strip_prefix = "libc-0.2.101",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.libc-0.2.101.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__log__0_4_14",
        url = "https://crates.io/api/v1/crates/log/0.4.14/download",
        type = "tar.gz",
        sha256 = "51b9bbe6c47d51fc3e1a9b945965946b4c44142ab8792c50835a980d362c2710",
        strip_prefix = "log-0.4.14",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.log-0.4.14.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__memchr__2_4_1",
        url = "https://crates.io/api/v1/crates/memchr/2.4.1/download",
        type = "tar.gz",
        sha256 = "308cc39be01b73d0d18f82a0e7b2a3df85245f84af96fdddc5d202d27e47b86a",
        strip_prefix = "memchr-2.4.1",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.memchr-2.4.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__memoffset__0_6_4",
        url = "https://crates.io/api/v1/crates/memoffset/0.6.4/download",
        type = "tar.gz",
        sha256 = "59accc507f1338036a0477ef61afdae33cde60840f4dfe481319ce3ad116ddf9",
        strip_prefix = "memoffset-0.6.4",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.memoffset-0.6.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__num_traits__0_2_14",
        url = "https://crates.io/api/v1/crates/num-traits/0.2.14/download",
        type = "tar.gz",
        sha256 = "9a64b1ec5cda2586e284722486d802acf1f7dbdc623e2bfc57e65ca1cd099290",
        strip_prefix = "num-traits-0.2.14",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.num-traits-0.2.14.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__num_cpus__1_13_0",
        url = "https://crates.io/api/v1/crates/num_cpus/1.13.0/download",
        type = "tar.gz",
        sha256 = "05499f3756671c15885fee9034446956fff3f243d6077b91e5767df161f766b3",
        strip_prefix = "num_cpus-1.13.0",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.num_cpus-1.13.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__oorandom__11_1_3",
        url = "https://crates.io/api/v1/crates/oorandom/11.1.3/download",
        type = "tar.gz",
        sha256 = "0ab1bc2a289d34bd04a330323ac98a1b4bc82c9d9fcb1e66b63caa84da26b575",
        strip_prefix = "oorandom-11.1.3",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.oorandom-11.1.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__plotters__0_3_1",
        url = "https://crates.io/api/v1/crates/plotters/0.3.1/download",
        type = "tar.gz",
        sha256 = "32a3fd9ec30b9749ce28cd91f255d569591cdf937fe280c312143e3c4bad6f2a",
        strip_prefix = "plotters-0.3.1",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.plotters-0.3.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__plotters_backend__0_3_2",
        url = "https://crates.io/api/v1/crates/plotters-backend/0.3.2/download",
        type = "tar.gz",
        sha256 = "d88417318da0eaf0fdcdb51a0ee6c3bed624333bff8f946733049380be67ac1c",
        strip_prefix = "plotters-backend-0.3.2",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.plotters-backend-0.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__plotters_svg__0_3_1",
        url = "https://crates.io/api/v1/crates/plotters-svg/0.3.1/download",
        type = "tar.gz",
        sha256 = "521fa9638fa597e1dc53e9412a4f9cefb01187ee1f7413076f9e6749e2885ba9",
        strip_prefix = "plotters-svg-0.3.1",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.plotters-svg-0.3.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__proc_macro2__1_0_29",
        url = "https://crates.io/api/v1/crates/proc-macro2/1.0.29/download",
        type = "tar.gz",
        sha256 = "b9f5105d4fdaab20335ca9565e106a5d9b82b6219b5ba735731124ac6711d23d",
        strip_prefix = "proc-macro2-1.0.29",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.proc-macro2-1.0.29.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__quote__1_0_9",
        url = "https://crates.io/api/v1/crates/quote/1.0.9/download",
        type = "tar.gz",
        sha256 = "c3d0b9745dc2debf507c8422de05d7226cc1f0644216dfdfead988f9b1ab32a7",
        strip_prefix = "quote-1.0.9",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.quote-1.0.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__rayon__1_5_1",
        url = "https://crates.io/api/v1/crates/rayon/1.5.1/download",
        type = "tar.gz",
        sha256 = "c06aca804d41dbc8ba42dfd964f0d01334eceb64314b9ecf7c5fad5188a06d90",
        strip_prefix = "rayon-1.5.1",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.rayon-1.5.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__rayon_core__1_9_1",
        url = "https://crates.io/api/v1/crates/rayon-core/1.9.1/download",
        type = "tar.gz",
        sha256 = "d78120e2c850279833f1dd3582f730c4ab53ed95aeaaaa862a2a5c71b1656d8e",
        strip_prefix = "rayon-core-1.9.1",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.rayon-core-1.9.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__regex__1_5_4",
        url = "https://crates.io/api/v1/crates/regex/1.5.4/download",
        type = "tar.gz",
        sha256 = "d07a8629359eb56f1e2fb1652bb04212c072a87ba68546a04065d525673ac461",
        strip_prefix = "regex-1.5.4",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.regex-1.5.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__regex_automata__0_1_10",
        url = "https://crates.io/api/v1/crates/regex-automata/0.1.10/download",
        type = "tar.gz",
        sha256 = "6c230d73fb8d8c1b9c0b3135c5142a8acee3a0558fb8db5cf1cb65f8d7862132",
        strip_prefix = "regex-automata-0.1.10",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.regex-automata-0.1.10.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__regex_syntax__0_6_25",
        url = "https://crates.io/api/v1/crates/regex-syntax/0.6.25/download",
        type = "tar.gz",
        sha256 = "f497285884f3fcff424ffc933e56d7cbca511def0c9831a7f9b5f6153e3cc89b",
        strip_prefix = "regex-syntax-0.6.25",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.regex-syntax-0.6.25.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__rustc_version__0_4_0",
        url = "https://crates.io/api/v1/crates/rustc_version/0.4.0/download",
        type = "tar.gz",
        sha256 = "bfa0f585226d2e68097d4f95d113b15b83a82e819ab25717ec0590d9584ef366",
        strip_prefix = "rustc_version-0.4.0",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.rustc_version-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__ryu__1_0_5",
        url = "https://crates.io/api/v1/crates/ryu/1.0.5/download",
        type = "tar.gz",
        sha256 = "71d301d4193d031abdd79ff7e3dd721168a9572ef3fe51a1517aba235bd8f86e",
        strip_prefix = "ryu-1.0.5",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.ryu-1.0.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__same_file__1_0_6",
        url = "https://crates.io/api/v1/crates/same-file/1.0.6/download",
        type = "tar.gz",
        sha256 = "93fc1dc3aaa9bfed95e02e6eadabb4baf7e3078b0bd1b4d7b6b0b68378900502",
        strip_prefix = "same-file-1.0.6",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.same-file-1.0.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__scopeguard__1_1_0",
        url = "https://crates.io/api/v1/crates/scopeguard/1.1.0/download",
        type = "tar.gz",
        sha256 = "d29ab0c6d3fc0ee92fe66e2d99f700eab17a8d57d1c1d3b748380fb20baa78cd",
        strip_prefix = "scopeguard-1.1.0",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.scopeguard-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__semver__1_0_4",
        url = "https://crates.io/api/v1/crates/semver/1.0.4/download",
        type = "tar.gz",
        sha256 = "568a8e6258aa33c13358f81fd834adb854c6f7c9468520910a9b1e8fac068012",
        strip_prefix = "semver-1.0.4",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.semver-1.0.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__serde__1_0_130",
        url = "https://crates.io/api/v1/crates/serde/1.0.130/download",
        type = "tar.gz",
        sha256 = "f12d06de37cf59146fbdecab66aa99f9fe4f78722e3607577a5375d66bd0c913",
        strip_prefix = "serde-1.0.130",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.serde-1.0.130.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__serde_cbor__0_11_2",
        url = "https://crates.io/api/v1/crates/serde_cbor/0.11.2/download",
        type = "tar.gz",
        sha256 = "2bef2ebfde456fb76bbcf9f59315333decc4fda0b2b44b420243c11e0f5ec1f5",
        strip_prefix = "serde_cbor-0.11.2",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.serde_cbor-0.11.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__serde_derive__1_0_130",
        url = "https://crates.io/api/v1/crates/serde_derive/1.0.130/download",
        type = "tar.gz",
        sha256 = "d7bc1a1ab1961464eae040d96713baa5a724a8152c1222492465b54322ec508b",
        strip_prefix = "serde_derive-1.0.130",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.serde_derive-1.0.130.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__serde_json__1_0_67",
        url = "https://crates.io/api/v1/crates/serde_json/1.0.67/download",
        type = "tar.gz",
        sha256 = "a7f9e390c27c3c0ce8bc5d725f6e4d30a29d26659494aa4b17535f7522c5c950",
        strip_prefix = "serde_json-1.0.67",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.serde_json-1.0.67.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__syn__1_0_75",
        url = "https://crates.io/api/v1/crates/syn/1.0.75/download",
        type = "tar.gz",
        sha256 = "b7f58f7e8eaa0009c5fec437aabf511bd9933e4b2d7407bd05273c01a8906ea7",
        strip_prefix = "syn-1.0.75",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.syn-1.0.75.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__textwrap__0_11_0",
        url = "https://crates.io/api/v1/crates/textwrap/0.11.0/download",
        type = "tar.gz",
        sha256 = "d326610f408c7a4eb6f51c37c330e496b08506c9457c9d34287ecc38809fb060",
        strip_prefix = "textwrap-0.11.0",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.textwrap-0.11.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__tinytemplate__1_2_1",
        url = "https://crates.io/api/v1/crates/tinytemplate/1.2.1/download",
        type = "tar.gz",
        sha256 = "be4d6b5f19ff7664e8c98d03e2139cb510db9b0a60b55f8e8709b689d939b6bc",
        strip_prefix = "tinytemplate-1.2.1",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.tinytemplate-1.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__unicode_width__0_1_8",
        url = "https://crates.io/api/v1/crates/unicode-width/0.1.8/download",
        type = "tar.gz",
        sha256 = "9337591893a19b88d8d87f2cec1e73fad5cdfd10e5a6f349f498ad6ea2ffb1e3",
        strip_prefix = "unicode-width-0.1.8",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.unicode-width-0.1.8.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__unicode_xid__0_2_2",
        url = "https://crates.io/api/v1/crates/unicode-xid/0.2.2/download",
        type = "tar.gz",
        sha256 = "8ccb82d61f80a663efe1f787a51b16b5a51e3314d6ac365b08639f52387b33f3",
        strip_prefix = "unicode-xid-0.2.2",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.unicode-xid-0.2.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__walkdir__2_3_2",
        url = "https://crates.io/api/v1/crates/walkdir/2.3.2/download",
        type = "tar.gz",
        sha256 = "808cf2735cd4b6866113f648b791c6adc5714537bc222d9347bb203386ffda56",
        strip_prefix = "walkdir-2.3.2",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.walkdir-2.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__wasm_bindgen__0_2_76",
        url = "https://crates.io/api/v1/crates/wasm-bindgen/0.2.76/download",
        type = "tar.gz",
        sha256 = "8ce9b1b516211d33767048e5d47fa2a381ed8b76fc48d2ce4aa39877f9f183e0",
        strip_prefix = "wasm-bindgen-0.2.76",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.wasm-bindgen-0.2.76.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__wasm_bindgen_backend__0_2_76",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-backend/0.2.76/download",
        type = "tar.gz",
        sha256 = "cfe8dc78e2326ba5f845f4b5bf548401604fa20b1dd1d365fb73b6c1d6364041",
        strip_prefix = "wasm-bindgen-backend-0.2.76",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.wasm-bindgen-backend-0.2.76.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__wasm_bindgen_macro__0_2_76",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-macro/0.2.76/download",
        type = "tar.gz",
        sha256 = "44468aa53335841d9d6b6c023eaab07c0cd4bddbcfdee3e2bb1e8d2cb8069fef",
        strip_prefix = "wasm-bindgen-macro-0.2.76",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.wasm-bindgen-macro-0.2.76.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__wasm_bindgen_macro_support__0_2_76",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-macro-support/0.2.76/download",
        type = "tar.gz",
        sha256 = "0195807922713af1e67dc66132c7328206ed9766af3858164fb583eedc25fbad",
        strip_prefix = "wasm-bindgen-macro-support-0.2.76",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.wasm-bindgen-macro-support-0.2.76.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__wasm_bindgen_shared__0_2_76",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-shared/0.2.76/download",
        type = "tar.gz",
        sha256 = "acdb075a845574a1fa5f09fd77e43f7747599301ea3417a9fbffdeedfc1f4a29",
        strip_prefix = "wasm-bindgen-shared-0.2.76",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.wasm-bindgen-shared-0.2.76.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__web_sys__0_3_53",
        url = "https://crates.io/api/v1/crates/web-sys/0.3.53/download",
        type = "tar.gz",
        sha256 = "224b2f6b67919060055ef1a67807367c2066ed520c3862cc013d26cf893a783c",
        strip_prefix = "web-sys-0.3.53",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.web-sys-0.3.53.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__winapi__0_3_9",
        url = "https://crates.io/api/v1/crates/winapi/0.3.9/download",
        type = "tar.gz",
        sha256 = "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419",
        strip_prefix = "winapi-0.3.9",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.winapi-0.3.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__winapi_i686_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-i686-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.winapi-i686-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__winapi_util__0_1_5",
        url = "https://crates.io/api/v1/crates/winapi-util/0.1.5/download",
        type = "tar.gz",
        sha256 = "70ec6ce85bb158151cae5e5c87f95a8e97d2c0c4b001223f33a334e3ce5de178",
        strip_prefix = "winapi-util-0.1.5",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.winapi-util-0.1.5.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_bench_criterion__winapi_x86_64_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-x86_64-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("//benchmarking/criterion/raze/remote:BUILD.winapi-x86_64-pc-windows-gnu-0.4.0.bazel"),
    )
