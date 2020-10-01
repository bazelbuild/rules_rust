load("@io_bazel_stardoc//stardoc:stardoc.bzl", "stardoc")
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//visibility:private"])

bzl_library(
    name = "all_deps",
    srcs = [
        "@bazel_tools//tools:bzl_srcs",
        "@bazel_version//:def.bzl",
    ],
    deps = [
        "@bazel_skylib//:workspace",
        "@bazel_skylib//lib:unittest",
        "@bazel_skylib//lib:versions",
        "@io_bazel_rules_rust//:rules",
        "@io_bazel_rules_rust//bindgen:rules",
        "@io_bazel_rules_rust//cargo:rules",
        "@io_bazel_rules_rust//proto:rules",
        "@io_bazel_rules_rust//rust:rules",
        "@io_bazel_rules_rust//wasm_bindgen:rules",
        "@rules_proto//proto:rules",
    ],
)

PAGES = {
    "rust": [
        "rust_library",
        "rust_binary",
        "rust_benchmark",
        "rust_test",
    ],
    "rust_doc": [
        "rust_doc",
        "rust_doc_test",
    ],
    "rust_proto": [
        "rust_proto_toolchain",
        "rust_proto_library",
        "rust_grpc_library",
    ],
    "rust_bindgen": [
        "rust_bindgen_toolchain",
        "rust_bindgen_library",
        "rust_bindgen",
    ],
    "rust_wasm_bindgen": [
        "rust_wasm_bindgen_toolchain",
        "rust_wasm_bindgen",
    ],
    "cargo_build_script": [
        "cargo_build_script",
    ],
    "rust_repositories": [
        "rust_repositories",
        "rust_repository_set",
        "rust_toolchain",
        "rust_toolchain_repository",
        "rust_toolchain_repository_proxy",
    ],
    "rust_workspace": [
        "rust_workspace",
        "bazel_version",
    ],
}

[
    genrule(
        name = "%s_header_vm" % k,
        outs = ["%s_header.vm" % k],
        cmd = ">$@ echo '# Rust rules\n%s'" % "\n".join(
            ["* [{rule}](#{rule})".format(rule = v) for v in PAGES[k]],
        ),
        output_to_bindir = True,
    )
    for k in PAGES.keys()
]

[
    stardoc(
        name = "%s_md" % k,
        out = "%s.md" % k,
        header_template = ":%s_header_vm" % k,
        input = ":all.bzl",
        symbol_names = PAGES[k],
        deps = [":all_deps"],
    )
    for k in PAGES.keys()
]

genrule(
    name = "flatten_header_vm",
    outs = ["flatten_header.vm"],
    cmd = ">$@ echo '# Rust rules\n\n%s\n'" % "\n".join(
        sorted(["* [{rule}](#{rule})".format(rule = v) for k in PAGES.keys() for v in PAGES[k]]),
    ),
    output_to_bindir = True,
)

stardoc(
    name = "flatten_md",
    out = "flatten.md",
    header_template = ":flatten_header_vm",
    input = ":all.bzl",
    symbol_names = [symbol for k in PAGES.keys() for symbol in PAGES[k]],
    deps = [":all_deps"],
)
