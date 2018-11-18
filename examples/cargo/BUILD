load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)
load(
    "@io_bazel_rules_rust//cargo:cargo_build_script.bzl",
    "cargo_build_script_run",
)

rust_binary(
    name = "build_script",
    srcs = ["build_script.rs"],
)

cargo_build_script_run(
    name = "build_script_run",
    srcs = ["lib.rs"],
    crate_features = ["bleh"],
    script = ":build_script"
)

rust_library(
    name = "lib",
    deps = [":build_script_run"],
    srcs = ["lib.rs"],
)

rust_test(
    name = "test",
    crate = ":lib",
)