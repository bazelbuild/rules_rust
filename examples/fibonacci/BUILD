load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_test",
    "rust_benchmark",
    "rust_doc",
    "rust_doc_test",
)

rust_library(
    name = "fibonacci",
    srcs = ["src/lib.rs"],
)

rust_test(
    name = "fibonacci_test",
    deps = [":fibonacci"],
)

rust_benchmark(
    name = "fibonacci_bench",
    srcs = ["benches/fibonacci_bench.rs"],
    tags = [
        "manual",
        "noci",
    ],
    deps = [":fibonacci"],
)

rust_doc(
    name = "fibonacci_doc",
    dep = ":fibonacci",
)

rust_doc_test(
    name = "fibonacci_doc_test",
    dep = ":fibonacci",
)
