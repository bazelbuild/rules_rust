load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
)

package(default_visibility = ["//visibility:public"])

rust_binary(
    name = "hello_version",
    srcs = ["src/main.rs"],
    version = "0.1.2-alpha0",
)

rust_binary(
    name = "hello_version_generated",
    srcs = ["src/main.rs"],
    version_file = ":generated-version",
)

genrule(
    name = "generated-version",
    outs = ["generated.version"],
    cmd = "echo 0.1.2-alpha0 > $@",
)

sh_test(
    name = "test",
    srcs = ["test.sh"],
    args = ["$(location :hello_version)"],
    data = [":hello_version"],
)

sh_test(
    name = "test-generated",
    srcs = ["test.sh"],
    args = ["$(location :hello_version_generated)"],
    data = [":hello_version_generated"],
)
