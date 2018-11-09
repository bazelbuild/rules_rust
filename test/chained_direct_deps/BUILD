load(
    "//rust:rust.bzl",
    "rust_library",
    "rust_test",
)

rust_library(
    name = "mod1",
    srcs = ["mod1.rs"],
)

rust_library(
    name = "mod2",
    srcs = ["mod2.rs"],
    deps = [":mod1"],
)

rust_library(
    name = "mod3",
    srcs = ["mod3.rs"],
    deps = [
        ":mod2",
        ":mod1",
    ],
)

rust_test(
    name = "mod1_test",
    deps = [":mod1"],
)

rust_test(
    name = "mod2_test",
    deps = [":mod2"],
)

rust_test(
    name = "mod3_test",
    deps = [":mod3"],
)
