load("@io_bazel_rules_rust//test/rustfmt:rustfmt_generator.bzl", "rustfmt_generator")

rustfmt_generator(
    name = "formatted",
    src = ":unformatted.rs",
)

sh_test(
    name = "rustfmt_test",
    size = "small",
    srcs = [":rustfmt_test.sh"],
    data = [
        ":formatted.rs",
        ":unformatted.rs",
    ],
    deps = ["@bazel_tools//tools/bash/runfiles"],
)
