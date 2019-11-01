package(default_visibility = ["//visibility:public"])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
)
load(
    "@io_bazel_rules_rust//wasm_bindgen:wasm_bindgen.bzl",
    "rust_wasm_bindgen",
)
load(
    "@build_bazel_rules_nodejs//:defs.bzl",
    "jasmine_node_test",
)

rust_binary(
    name = "hello_world_wasm",
    srcs = ["main.rs"],
    edition = "2018",
    deps = ["@io_bazel_rules_rust//wasm_bindgen/raze:wasm_bindgen"],
)

rust_wasm_bindgen(
    name = "hello_world_wasm_bindgen",
    wasm_file = ":hello_world_wasm",
)

jasmine_node_test(
    name = "hello_world_wasm_test",
    srcs = [
        "hello_world_wasm_test.js",
    ],
    data = [
        ":hello_world_wasm_bindgen_bg.wasm",
        "@npm//jasmine",
    ],
)
