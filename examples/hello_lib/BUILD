load(
    "@rules_rust//rust:rust.bzl",
    "rust_analyzer",
    "rust_doc",
    "rust_doc_test",
    "rust_library",
    "rust_test",
)

package(default_visibility = ["//visibility:public"])

rust_library(
    name = "hello_lib",
    srcs = [
        "src/greeter.rs",
        "src/lib.rs",
    ],
    crate_features = ["default"],
    rustc_flags = ["--cap-lints=allow"],
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

# Regression test for #368: static lib with dependencies fail.
rust_library(
    name = "hello_test_staticlib",
    srcs = [
        "tests/greeting.rs",
    ],
    crate_type = "staticlib",
    deps = [":hello_lib"],
)

# Regression test for #368: cdylib lib with dependencies fail.
rust_library(
    name = "hello_test_cdylib",
    srcs = [
        "tests/greeting.rs",
    ],
    crate_type = "cdylib",
    deps = [":hello_lib"],
)

rust_test(
    name = "hello-lib-test",
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

rust_analyzer(
    name = "hello_rust_analyzer",
    targets = [":hello_lib"],
)
