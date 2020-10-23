load("@io_bazel_rules_rust//rust:rust.bzl", "rust_test")

rust_test(
    name = "hello_uses_cargo_manifest_dir",
    srcs = ["src/lib.rs"],
    edition = "2018",
    deps = ["@hello_cargo_manifest_dir"],
)
