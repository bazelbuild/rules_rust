load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)
load(
    "@io_bazel_rules_rust//cargo:cargo_build_script.bzl",
    "cargo_build_script",
)

cargo_build_script(
    name = "build_script",
    srcs = ["build_script.rs"],
    data = ["test.txt"],
    crate_features = ["bleh"],
)

rust_library(
    name = "lib",
    srcs = ["lib.rs"],
    deps = [":build_script"],
)

rust_test(
    name = "test",
    crate = ":lib",
)
