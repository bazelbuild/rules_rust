"""
@generated
cargo-raze generated Bazel file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

def remote_dev_dependencies_fetch_remote_crates():
    """This function defines a collection of repos and should be called in a WORKSPACE file"""
    maybe(
        http_archive,
        name = "remote_dev_dependencies__addr2line__0_14_1",
        url = "https://crates.io/api/v1/crates/addr2line/0.14.1/download",
        type = "tar.gz",
        sha256 = "a55f82cfe485775d02112886f4169bde0c5894d75e79ead7eafe7e40a25e45f7",
        strip_prefix = "addr2line-0.14.1",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.addr2line-0.14.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__adler__0_2_3",
        url = "https://crates.io/api/v1/crates/adler/0.2.3/download",
        type = "tar.gz",
        sha256 = "ee2a4ec343196209d6594e19543ae87a39f96d5534d7174822a3ad825dd6ed7e",
        strip_prefix = "adler-0.2.3",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.adler-0.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__ansi_term__0_11_0",
        url = "https://crates.io/api/v1/crates/ansi_term/0.11.0/download",
        type = "tar.gz",
        sha256 = "ee49baf6cb617b853aa8d93bf420db2383fab46d314482ca2803b40d5fde979b",
        strip_prefix = "ansi_term-0.11.0",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.ansi_term-0.11.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__atty__0_2_14",
        url = "https://crates.io/api/v1/crates/atty/0.2.14/download",
        type = "tar.gz",
        sha256 = "d9b39be18770d11421cdb1b9947a45dd3f37e93092cbf377614828a319d5fee8",
        strip_prefix = "atty-0.2.14",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.atty-0.2.14.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__autocfg__1_0_1",
        url = "https://crates.io/api/v1/crates/autocfg/1.0.1/download",
        type = "tar.gz",
        sha256 = "cdb031dd78e28731d87d56cc8ffef4a8f36ca26c38fe2de700543e627f8a464a",
        strip_prefix = "autocfg-1.0.1",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.autocfg-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__backtrace__0_3_56",
        url = "https://crates.io/api/v1/crates/backtrace/0.3.56/download",
        type = "tar.gz",
        sha256 = "9d117600f438b1707d4e4ae15d3595657288f8235a0eb593e80ecc98ab34e1bc",
        strip_prefix = "backtrace-0.3.56",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.backtrace-0.3.56.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__bitflags__1_2_1",
        url = "https://crates.io/api/v1/crates/bitflags/1.2.1/download",
        type = "tar.gz",
        sha256 = "cf1de2fe8c75bc145a2f577add951f8134889b4795d47466a54a5c846d691693",
        strip_prefix = "bitflags-1.2.1",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.bitflags-1.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__cfg_if__1_0_0",
        url = "https://crates.io/api/v1/crates/cfg-if/1.0.0/download",
        type = "tar.gz",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__clap__2_33_3",
        url = "https://crates.io/api/v1/crates/clap/2.33.3/download",
        type = "tar.gz",
        sha256 = "37e58ac78573c40708d45522f0d80fa2f01cc4f9b4e2bf749807255454312002",
        strip_prefix = "clap-2.33.3",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.clap-2.33.3.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__error_chain__0_10_0",
        url = "https://crates.io/api/v1/crates/error-chain/0.10.0/download",
        type = "tar.gz",
        sha256 = "d9435d864e017c3c6afeac1654189b06cdb491cf2ff73dbf0d73b0f292f42ff8",
        strip_prefix = "error-chain-0.10.0",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.error-chain-0.10.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__ferris_says__0_2_0",
        url = "https://crates.io/api/v1/crates/ferris-says/0.2.0/download",
        type = "tar.gz",
        sha256 = "7f34f82e9a8b1533c027d018abd90b8687bf923be287b2617dfce4bea4ea3687",
        strip_prefix = "ferris-says-0.2.0",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.ferris-says-0.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__gimli__0_23_0",
        url = "https://crates.io/api/v1/crates/gimli/0.23.0/download",
        type = "tar.gz",
        sha256 = "f6503fe142514ca4799d4c26297c4248239fe8838d827db6bd6065c6ed29a6ce",
        strip_prefix = "gimli-0.23.0",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.gimli-0.23.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__hermit_abi__0_1_18",
        url = "https://crates.io/api/v1/crates/hermit-abi/0.1.18/download",
        type = "tar.gz",
        sha256 = "322f4de77956e22ed0e5032c359a0f1273f1f7f0d79bfa3b8ffbc730d7fbcc5c",
        strip_prefix = "hermit-abi-0.1.18",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.hermit-abi-0.1.18.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__indoc__1_0_3",
        url = "https://crates.io/api/v1/crates/indoc/1.0.3/download",
        type = "tar.gz",
        sha256 = "e5a75aeaaef0ce18b58056d306c27b07436fbb34b8816c53094b76dd81803136",
        strip_prefix = "indoc-1.0.3",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.indoc-1.0.3.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__libc__0_2_85",
        url = "https://crates.io/api/v1/crates/libc/0.2.85/download",
        type = "tar.gz",
        sha256 = "7ccac4b00700875e6a07c6cde370d44d32fa01c5a65cdd2fca6858c479d28bb3",
        strip_prefix = "libc-0.2.85",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.libc-0.2.85.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__miniz_oxide__0_4_3",
        url = "https://crates.io/api/v1/crates/miniz_oxide/0.4.3/download",
        type = "tar.gz",
        sha256 = "0f2d26ec3309788e423cfbf68ad1800f061638098d76a83681af979dc4eda19d",
        strip_prefix = "miniz_oxide-0.4.3",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.miniz_oxide-0.4.3.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__object__0_23_0",
        url = "https://crates.io/api/v1/crates/object/0.23.0/download",
        type = "tar.gz",
        sha256 = "a9a7ab5d64814df0fe4a4b5ead45ed6c5f181ee3ff04ba344313a6c80446c5d4",
        strip_prefix = "object-0.23.0",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.object-0.23.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__rustc_demangle__0_1_18",
        url = "https://crates.io/api/v1/crates/rustc-demangle/0.1.18/download",
        type = "tar.gz",
        sha256 = "6e3bad0ee36814ca07d7968269dd4b7ec89ec2da10c4bb613928d3077083c232",
        strip_prefix = "rustc-demangle-0.1.18",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.rustc-demangle-0.1.18.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__smallvec__0_4_5",
        url = "https://crates.io/api/v1/crates/smallvec/0.4.5/download",
        type = "tar.gz",
        sha256 = "f90c5e5fe535e48807ab94fc611d323935f39d4660c52b26b96446a7b33aef10",
        strip_prefix = "smallvec-0.4.5",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.smallvec-0.4.5.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__strsim__0_8_0",
        url = "https://crates.io/api/v1/crates/strsim/0.8.0/download",
        type = "tar.gz",
        sha256 = "8ea5119cdb4c55b55d432abb513a0429384878c15dde60cc77b1c99de1a95a6a",
        strip_prefix = "strsim-0.8.0",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.strsim-0.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__textwrap__0_11_0",
        url = "https://crates.io/api/v1/crates/textwrap/0.11.0/download",
        type = "tar.gz",
        sha256 = "d326610f408c7a4eb6f51c37c330e496b08506c9457c9d34287ecc38809fb060",
        strip_prefix = "textwrap-0.11.0",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.textwrap-0.11.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__unicode_width__0_1_8",
        url = "https://crates.io/api/v1/crates/unicode-width/0.1.8/download",
        type = "tar.gz",
        sha256 = "9337591893a19b88d8d87f2cec1e73fad5cdfd10e5a6f349f498ad6ea2ffb1e3",
        strip_prefix = "unicode-width-0.1.8",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.unicode-width-0.1.8.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__unindent__0_1_7",
        url = "https://crates.io/api/v1/crates/unindent/0.1.7/download",
        type = "tar.gz",
        sha256 = "f14ee04d9415b52b3aeab06258a3f07093182b88ba0f9b8d203f211a7a7d41c7",
        strip_prefix = "unindent-0.1.7",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.unindent-0.1.7.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__vec_map__0_8_2",
        url = "https://crates.io/api/v1/crates/vec_map/0.8.2/download",
        type = "tar.gz",
        sha256 = "f1bddf1187be692e79c5ffeab891132dfb0f236ed36a43c7ed39f1165ee20191",
        strip_prefix = "vec_map-0.8.2",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.vec_map-0.8.2.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__winapi__0_3_9",
        url = "https://crates.io/api/v1/crates/winapi/0.3.9/download",
        type = "tar.gz",
        sha256 = "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419",
        strip_prefix = "winapi-0.3.9",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.winapi-0.3.9.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__winapi_i686_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-i686-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.winapi-i686-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_dev_dependencies__winapi_x86_64_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-x86_64-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("//remote/dev_dependencies/cargo/remote:BUILD.winapi-x86_64-pc-windows-gnu-0.4.0.bazel"),
    )
