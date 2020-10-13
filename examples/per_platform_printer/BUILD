load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

package(default_visibility = ["//visibility:public"])

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
        "@io_bazel_rules_rust//rust/platform:linux": [
            ":print_linux.rs",
        ],
        "@io_bazel_rules_rust//rust/platform:osx": [
            ":print_osx.rs",
        ],
        "@io_bazel_rules_rust//rust/platform:windows": [
            ":print_windows.rs",
        ],
    }),
)

rust_test(
    name = "printer_test",
    crate = ":printer",
)
