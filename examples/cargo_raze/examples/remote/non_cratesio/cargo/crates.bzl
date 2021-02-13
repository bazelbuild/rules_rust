"""
@generated
cargo-raze generated Bazel file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

def remote_non_cratesio_fetch_remote_crates():
    """This function defines a collection of repos and should be called in a WORKSPACE file"""
    maybe(
        http_archive,
        name = "remote_non_cratesio__aho_corasick__0_6_10",
        url = "https://crates.io/api/v1/crates/aho-corasick/0.6.10/download",
        type = "tar.gz",
        sha256 = "81ce3d38065e618af2d7b77e10c5ad9a069859b4be3c2250f674af3840d9c8a5",
        strip_prefix = "aho-corasick-0.6.10",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.aho-corasick-0.6.10.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_non_cratesio__atty__0_2_14",
        url = "https://crates.io/api/v1/crates/atty/0.2.14/download",
        type = "tar.gz",
        sha256 = "d9b39be18770d11421cdb1b9947a45dd3f37e93092cbf377614828a319d5fee8",
        strip_prefix = "atty-0.2.14",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.atty-0.2.14.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_non_cratesio__bitflags__1_2_1",
        url = "https://crates.io/api/v1/crates/bitflags/1.2.1/download",
        type = "tar.gz",
        sha256 = "cf1de2fe8c75bc145a2f577add951f8134889b4795d47466a54a5c846d691693",
        strip_prefix = "bitflags-1.2.1",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.bitflags-1.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_non_cratesio__cfg_if__0_1_10",
        url = "https://crates.io/api/v1/crates/cfg-if/0.1.10/download",
        type = "tar.gz",
        sha256 = "4785bdd1c96b2a846b2bd7cc02e86b6b3dbf14e7e53446c4f54c92a361040822",
        strip_prefix = "cfg-if-0.1.10",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.cfg-if-0.1.10.bazel"),
    )

    maybe(
        new_git_repository,
        name = "remote_non_cratesio__env_logger__0_5_5",
        remote = "https://github.com/sebasmagri/env_logger.git",
        commit = "4d7926c515a8620e7fa0e91a07047023170c1064",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.env_logger-0.5.5.bazel"),
        init_submodules = True,
    )

    maybe(
        http_archive,
        name = "remote_non_cratesio__fuchsia_zircon__0_3_3",
        url = "https://crates.io/api/v1/crates/fuchsia-zircon/0.3.3/download",
        type = "tar.gz",
        sha256 = "2e9763c69ebaae630ba35f74888db465e49e259ba1bc0eda7d06f4a067615d82",
        strip_prefix = "fuchsia-zircon-0.3.3",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.fuchsia-zircon-0.3.3.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_non_cratesio__fuchsia_zircon_sys__0_3_3",
        url = "https://crates.io/api/v1/crates/fuchsia-zircon-sys/0.3.3/download",
        type = "tar.gz",
        sha256 = "3dcaa9ae7725d12cdb85b3ad99a434db70b468c09ded17e012d86b5c1010f7a7",
        strip_prefix = "fuchsia-zircon-sys-0.3.3",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.fuchsia-zircon-sys-0.3.3.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_non_cratesio__hermit_abi__0_1_15",
        url = "https://crates.io/api/v1/crates/hermit-abi/0.1.15/download",
        type = "tar.gz",
        sha256 = "3deed196b6e7f9e44a2ae8d94225d80302d81208b1bb673fd21fe634645c85a9",
        strip_prefix = "hermit-abi-0.1.15",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.hermit-abi-0.1.15.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_non_cratesio__humantime__1_3_0",
        url = "https://crates.io/api/v1/crates/humantime/1.3.0/download",
        type = "tar.gz",
        sha256 = "df004cfca50ef23c36850aaaa59ad52cc70d0e90243c3c7737a4dd32dc7a3c4f",
        strip_prefix = "humantime-1.3.0",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.humantime-1.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_non_cratesio__lazy_static__1_4_0",
        url = "https://crates.io/api/v1/crates/lazy_static/1.4.0/download",
        type = "tar.gz",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        strip_prefix = "lazy_static-1.4.0",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.lazy_static-1.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_non_cratesio__libc__0_2_77",
        url = "https://crates.io/api/v1/crates/libc/0.2.77/download",
        type = "tar.gz",
        sha256 = "f2f96b10ec2560088a8e76961b00d47107b3a625fecb76dedb29ee7ccbf98235",
        strip_prefix = "libc-0.2.77",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.libc-0.2.77.bazel"),
    )

    maybe(
        new_git_repository,
        name = "remote_non_cratesio__log__0_4_0",
        remote = "https://github.com/rust-lang-nursery/log.git",
        commit = "bf40d1f563cf3eef63233d935ce56f2198b381d3",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.log-0.4.0.bazel"),
        init_submodules = True,
    )

    maybe(
        http_archive,
        name = "remote_non_cratesio__log__0_4_11",
        url = "https://crates.io/api/v1/crates/log/0.4.11/download",
        type = "tar.gz",
        sha256 = "4fabed175da42fed1fa0746b0ea71f412aa9d35e76e95e59b192c64b9dc2bf8b",
        strip_prefix = "log-0.4.11",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.log-0.4.11.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_non_cratesio__memchr__2_3_3",
        url = "https://crates.io/api/v1/crates/memchr/2.3.3/download",
        type = "tar.gz",
        sha256 = "3728d817d99e5ac407411fa471ff9800a778d88a24685968b36824eaf4bee400",
        strip_prefix = "memchr-2.3.3",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.memchr-2.3.3.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_non_cratesio__quick_error__1_2_3",
        url = "https://crates.io/api/v1/crates/quick-error/1.2.3/download",
        type = "tar.gz",
        sha256 = "a1d01941d82fa2ab50be1e79e6714289dd7cde78eba4c074bc5a4374f650dfe0",
        strip_prefix = "quick-error-1.2.3",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.quick-error-1.2.3.bazel"),
    )

    maybe(
        new_git_repository,
        name = "remote_non_cratesio__rand__0_4_1",
        remote = "https://github.com/rust-random/rand.git",
        commit = "b333d687138b5cb9b225f49ba80bf1bfef01e068",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.rand-0.4.1.bazel"),
        init_submodules = True,
    )

    maybe(
        http_archive,
        name = "remote_non_cratesio__regex__0_2_11",
        url = "https://crates.io/api/v1/crates/regex/0.2.11/download",
        type = "tar.gz",
        sha256 = "9329abc99e39129fcceabd24cf5d85b4671ef7c29c50e972bc5afe32438ec384",
        strip_prefix = "regex-0.2.11",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.regex-0.2.11.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_non_cratesio__regex_syntax__0_5_6",
        url = "https://crates.io/api/v1/crates/regex-syntax/0.5.6/download",
        type = "tar.gz",
        sha256 = "7d707a4fa2637f2dca2ef9fd02225ec7661fe01a53623c1e6515b6916511f7a7",
        strip_prefix = "regex-syntax-0.5.6",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.regex-syntax-0.5.6.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_non_cratesio__termcolor__0_3_6",
        url = "https://crates.io/api/v1/crates/termcolor/0.3.6/download",
        type = "tar.gz",
        sha256 = "adc4587ead41bf016f11af03e55a624c06568b5a19db4e90fde573d805074f83",
        strip_prefix = "termcolor-0.3.6",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.termcolor-0.3.6.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_non_cratesio__thread_local__0_3_6",
        url = "https://crates.io/api/v1/crates/thread_local/0.3.6/download",
        type = "tar.gz",
        sha256 = "c6b53e329000edc2b34dbe8545fd20e55a333362d0a321909685a19bd28c3f1b",
        strip_prefix = "thread_local-0.3.6",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.thread_local-0.3.6.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_non_cratesio__ucd_util__0_1_8",
        url = "https://crates.io/api/v1/crates/ucd-util/0.1.8/download",
        type = "tar.gz",
        sha256 = "c85f514e095d348c279b1e5cd76795082cf15bd59b93207832abe0b1d8fed236",
        strip_prefix = "ucd-util-0.1.8",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.ucd-util-0.1.8.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_non_cratesio__utf8_ranges__1_0_4",
        url = "https://crates.io/api/v1/crates/utf8-ranges/1.0.4/download",
        type = "tar.gz",
        sha256 = "b4ae116fef2b7fea257ed6440d3cfcff7f190865f170cdad00bb6465bf18ecba",
        strip_prefix = "utf8-ranges-1.0.4",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.utf8-ranges-1.0.4.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_non_cratesio__winapi__0_3_9",
        url = "https://crates.io/api/v1/crates/winapi/0.3.9/download",
        type = "tar.gz",
        sha256 = "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419",
        strip_prefix = "winapi-0.3.9",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.winapi-0.3.9.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_non_cratesio__winapi_i686_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-i686-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.winapi-i686-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_non_cratesio__winapi_x86_64_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-x86_64-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.winapi-x86_64-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_non_cratesio__wincolor__0_1_6",
        url = "https://crates.io/api/v1/crates/wincolor/0.1.6/download",
        type = "tar.gz",
        sha256 = "eeb06499a3a4d44302791052df005d5232b927ed1a9658146d842165c4de7767",
        strip_prefix = "wincolor-0.1.6",
        build_file = Label("//remote/non_cratesio/cargo/remote:BUILD.wincolor-0.1.6.bazel"),
    )
