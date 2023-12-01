"""TODO"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load(
    "//wasm_bindgen:repositories.bzl",
    _rust_wasm_bindgen_dependencies = "rust_wasm_bindgen_dependencies",
    _rust_wasm_bindgen_register_toolchains = "rust_wasm_bindgen_register_toolchains",
)

def js_rust_wasm_bindgen_dependencies():
    _rust_wasm_bindgen_dependencies()

    maybe(
        http_archive,
        name = "aspect_rules_js",
        sha256 = "7b2a4d1d264e105eae49a27e2e78065b23e2e45724df2251eacdd317e95bfdfd",
        strip_prefix = "rules_js-1.31.0",
        url = "https://github.com/aspect-build/rules_js/releases/download/v1.31.0/rules_js-v1.31.0.tar.gz",
    )

def js_rust_wasm_bindgen_register_toolchains(**kwargs):
    _rust_wasm_bindgen_register_toolchains(**kwargs)
