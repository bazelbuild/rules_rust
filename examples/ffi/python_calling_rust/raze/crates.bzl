"""
@generated
cargo-raze generated Bazel file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

def rules_rust_examples_ffi_python_calling_rust_fetch_remote_crates():
    """This function defines a collection of repos and should be called in a WORKSPACE file"""
    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__bitflags__1_2_1",
        url = "https://crates.io/api/v1/crates/bitflags/1.2.1/download",
        type = "tar.gz",
        sha256 = "cf1de2fe8c75bc145a2f577add951f8134889b4795d47466a54a5c846d691693",
        strip_prefix = "bitflags-1.2.1",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.bitflags-1.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__cfg_if__1_0_0",
        url = "https://crates.io/api/v1/crates/cfg-if/1.0.0/download",
        type = "tar.gz",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__ctor__0_1_20",
        url = "https://crates.io/api/v1/crates/ctor/0.1.20/download",
        type = "tar.gz",
        sha256 = "5e98e2ad1a782e33928b96fc3948e7c355e5af34ba4de7670fe8bac2a3b2006d",
        strip_prefix = "ctor-0.1.20",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.ctor-0.1.20.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__ghost__0_1_2",
        url = "https://crates.io/api/v1/crates/ghost/0.1.2/download",
        type = "tar.gz",
        sha256 = "1a5bcf1bbeab73aa4cf2fde60a846858dc036163c7c33bec309f8d17de785479",
        strip_prefix = "ghost-0.1.2",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.ghost-0.1.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__indoc__0_3_6",
        url = "https://crates.io/api/v1/crates/indoc/0.3.6/download",
        type = "tar.gz",
        sha256 = "47741a8bc60fb26eb8d6e0238bbb26d8575ff623fdc97b1a2c00c050b9684ed8",
        strip_prefix = "indoc-0.3.6",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.indoc-0.3.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__indoc_impl__0_3_6",
        url = "https://crates.io/api/v1/crates/indoc-impl/0.3.6/download",
        type = "tar.gz",
        sha256 = "ce046d161f000fffde5f432a0d034d0341dc152643b2598ed5bfce44c4f3a8f0",
        strip_prefix = "indoc-impl-0.3.6",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.indoc-impl-0.3.6.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__instant__0_1_9",
        url = "https://crates.io/api/v1/crates/instant/0.1.9/download",
        type = "tar.gz",
        sha256 = "61124eeebbd69b8190558df225adf7e4caafce0d743919e5d6b19652314ec5ec",
        strip_prefix = "instant-0.1.9",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.instant-0.1.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__inventory__0_1_10",
        url = "https://crates.io/api/v1/crates/inventory/0.1.10/download",
        type = "tar.gz",
        sha256 = "0f0f7efb804ec95e33db9ad49e4252f049e37e8b0a4652e3cd61f7999f2eff7f",
        strip_prefix = "inventory-0.1.10",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.inventory-0.1.10.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__inventory_impl__0_1_10",
        url = "https://crates.io/api/v1/crates/inventory-impl/0.1.10/download",
        type = "tar.gz",
        sha256 = "75c094e94816723ab936484666968f5b58060492e880f3c8d00489a1e244fa51",
        strip_prefix = "inventory-impl-0.1.10",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.inventory-impl-0.1.10.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__libc__0_2_95",
        url = "https://crates.io/api/v1/crates/libc/0.2.95/download",
        type = "tar.gz",
        sha256 = "789da6d93f1b866ffe175afc5322a4d76c038605a1c3319bb57b06967ca98a36",
        strip_prefix = "libc-0.2.95",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.libc-0.2.95.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__lock_api__0_4_4",
        url = "https://crates.io/api/v1/crates/lock_api/0.4.4/download",
        type = "tar.gz",
        sha256 = "0382880606dff6d15c9476c416d18690b72742aa7b605bb6dd6ec9030fbf07eb",
        strip_prefix = "lock_api-0.4.4",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.lock_api-0.4.4.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__parking_lot__0_11_1",
        url = "https://crates.io/api/v1/crates/parking_lot/0.11.1/download",
        type = "tar.gz",
        sha256 = "6d7744ac029df22dca6284efe4e898991d28e3085c706c972bcd7da4a27a15eb",
        strip_prefix = "parking_lot-0.11.1",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.parking_lot-0.11.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__parking_lot_core__0_8_3",
        url = "https://crates.io/api/v1/crates/parking_lot_core/0.8.3/download",
        type = "tar.gz",
        sha256 = "fa7a782938e745763fe6907fc6ba86946d72f49fe7e21de074e08128a99fb018",
        strip_prefix = "parking_lot_core-0.8.3",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.parking_lot_core-0.8.3.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__paste__0_1_18",
        url = "https://crates.io/api/v1/crates/paste/0.1.18/download",
        type = "tar.gz",
        sha256 = "45ca20c77d80be666aef2b45486da86238fabe33e38306bd3118fe4af33fa880",
        strip_prefix = "paste-0.1.18",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.paste-0.1.18.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__paste_impl__0_1_18",
        url = "https://crates.io/api/v1/crates/paste-impl/0.1.18/download",
        type = "tar.gz",
        sha256 = "d95a7db200b97ef370c8e6de0088252f7e0dfff7d047a28528e47456c0fc98b6",
        strip_prefix = "paste-impl-0.1.18",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.paste-impl-0.1.18.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__proc_macro_hack__0_5_19",
        url = "https://crates.io/api/v1/crates/proc-macro-hack/0.5.19/download",
        type = "tar.gz",
        sha256 = "dbf0c48bc1d91375ae5c3cd81e3722dff1abcf81a30960240640d223f59fe0e5",
        strip_prefix = "proc-macro-hack-0.5.19",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.proc-macro-hack-0.5.19.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__proc_macro2__1_0_27",
        url = "https://crates.io/api/v1/crates/proc-macro2/1.0.27/download",
        type = "tar.gz",
        sha256 = "f0d8caf72986c1a598726adc988bb5984792ef84f5ee5aa50209145ee8077038",
        strip_prefix = "proc-macro2-1.0.27",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.proc-macro2-1.0.27.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__pyo3__0_13_2",
        url = "https://crates.io/api/v1/crates/pyo3/0.13.2/download",
        type = "tar.gz",
        sha256 = "4837b8e8e18a102c23f79d1e9a110b597ea3b684c95e874eb1ad88f8683109c3",
        strip_prefix = "pyo3-0.13.2",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.pyo3-0.13.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__pyo3_macros__0_13_2",
        url = "https://crates.io/api/v1/crates/pyo3-macros/0.13.2/download",
        type = "tar.gz",
        sha256 = "a47f2c300ceec3e58064fd5f8f5b61230f2ffd64bde4970c81fdd0563a2db1bb",
        strip_prefix = "pyo3-macros-0.13.2",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.pyo3-macros-0.13.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__pyo3_macros_backend__0_13_2",
        url = "https://crates.io/api/v1/crates/pyo3-macros-backend/0.13.2/download",
        type = "tar.gz",
        sha256 = "87b097e5d84fcbe3e167f400fbedd657820a375b034c78bd852050749a575d66",
        strip_prefix = "pyo3-macros-backend-0.13.2",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.pyo3-macros-backend-0.13.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__quote__1_0_9",
        url = "https://crates.io/api/v1/crates/quote/1.0.9/download",
        type = "tar.gz",
        sha256 = "c3d0b9745dc2debf507c8422de05d7226cc1f0644216dfdfead988f9b1ab32a7",
        strip_prefix = "quote-1.0.9",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.quote-1.0.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__redox_syscall__0_2_8",
        url = "https://crates.io/api/v1/crates/redox_syscall/0.2.8/download",
        type = "tar.gz",
        sha256 = "742739e41cd49414de871ea5e549afb7e2a3ac77b589bcbebe8c82fab37147fc",
        strip_prefix = "redox_syscall-0.2.8",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.redox_syscall-0.2.8.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__scopeguard__1_1_0",
        url = "https://crates.io/api/v1/crates/scopeguard/1.1.0/download",
        type = "tar.gz",
        sha256 = "d29ab0c6d3fc0ee92fe66e2d99f700eab17a8d57d1c1d3b748380fb20baa78cd",
        strip_prefix = "scopeguard-1.1.0",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.scopeguard-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__smallvec__1_6_1",
        url = "https://crates.io/api/v1/crates/smallvec/1.6.1/download",
        type = "tar.gz",
        sha256 = "fe0f37c9e8f3c5a4a66ad655a93c74daac4ad00c441533bf5c6e7990bb42604e",
        strip_prefix = "smallvec-1.6.1",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.smallvec-1.6.1.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__syn__1_0_72",
        url = "https://crates.io/api/v1/crates/syn/1.0.72/download",
        type = "tar.gz",
        sha256 = "a1e8cdbefb79a9a5a65e0db8b47b723ee907b7c7f8496c76a1770b5c310bab82",
        strip_prefix = "syn-1.0.72",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.syn-1.0.72.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__unicode_xid__0_2_2",
        url = "https://crates.io/api/v1/crates/unicode-xid/0.2.2/download",
        type = "tar.gz",
        sha256 = "8ccb82d61f80a663efe1f787a51b16b5a51e3314d6ac365b08639f52387b33f3",
        strip_prefix = "unicode-xid-0.2.2",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.unicode-xid-0.2.2.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__unindent__0_1_7",
        url = "https://crates.io/api/v1/crates/unindent/0.1.7/download",
        type = "tar.gz",
        sha256 = "f14ee04d9415b52b3aeab06258a3f07093182b88ba0f9b8d203f211a7a7d41c7",
        strip_prefix = "unindent-0.1.7",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.unindent-0.1.7.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__winapi__0_3_9",
        url = "https://crates.io/api/v1/crates/winapi/0.3.9/download",
        type = "tar.gz",
        sha256 = "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419",
        strip_prefix = "winapi-0.3.9",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.winapi-0.3.9.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__winapi_i686_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-i686-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.winapi-i686-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_rust_examples_ffi_python_calling_rust__winapi_x86_64_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-x86_64-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("//ffi/python_calling_rust/raze/remote:BUILD.winapi-x86_64-pc-windows-gnu-0.4.0.bazel"),
    )
