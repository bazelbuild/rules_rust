package(default_visibility = ["//visibility:public"])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

rust_binary(
    name = "print",
    srcs = ["main.rs"],
    deps = [
        ":printer",
    ],
)

rust_library(
    name = "printer",
    srcs = [
        "lib.rs",
        "print_generic.rs",
    ] + select({
        "@io_bazel_rules_rust//rust/platform:x86_64-unknown-linux-gnu": [
            ":print_linux.rs",
        ],
        "@io_bazel_rules_rust//rust/platform:x86_64-apple-darwin": [
            ":print_osx.rs",
        ],
    }),
)

rust_test(
    name = "printer_test",
    deps = [":printer"],
)
