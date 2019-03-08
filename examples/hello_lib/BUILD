package(default_visibility = ["//visibility:public"])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_test",
    "rust_doc",
    "rust_doc_test",
)

rust_library(
    name = "hello_lib",
    srcs = [
        "src/greeter.rs",
        "src/lib.rs",
    ],
    rustc_flags = ["--cap-lints=allow"],
    crate_features = ["default"],
)

rust_library(
    name = "hello_dylib",
    srcs = [
        "src/greeter.rs",
        "src/lib.rs",
    ],
    crate_type = "dylib",
)

rust_library(
    name = "hello_cdylib",
    srcs = [
        "src/greeter.rs",
        "src/lib.rs",
    ],
    crate_type = "cdylib",
)

rust_library(
    name = "hello_staticlib",
    srcs = [
        "src/greeter.rs",
        "src/lib.rs",
    ],
    crate_type = "staticlib",
)

rust_test(
    name = "hello_lib_test",
    crate = ":hello_lib",
)

rust_test(
    name = "greeting_test",
    srcs = ["tests/greeting.rs"],
    deps = [":hello_lib"],
)

rust_doc(
    name = "hello_lib_doc",
    dep = ":hello_lib",
)

rust_doc_test(
    name = "hello_lib_doc_test",
    dep = ":hello_lib",
)
