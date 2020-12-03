load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_test",
)

package(default_visibility = ["//visibility:public"])

rust_binary(
    name = "versioned_dylib",
    srcs = [
        "src/main.rs",
    ],
    tags = ["manual"],
    deps = [
        "//test/versioned_dylib/c:libreturn_zero",
        "@libc",
    ],
)

rust_test(
    name = "versioned_dylib_test",
    crate = "versioned_dylib",
    tags = ["manual"],
)
