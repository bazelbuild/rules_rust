load(
    "@rules_rust//cargo:cargo_build_script.bzl",
    "cargo_build_script",
)
load(
    "@rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_test",
)

cargo_build_script(
    name = "build_script",
    srcs = ["build_script.rs"],
    build_script_env = {"SOME_ENV": "42"},
    crate_features = ["bleh"],
    data = ["test.txt"],
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
