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
    aliases = {
        ":mod1": "alias_a",
        ":mod2": "alias_b",
    },
    deps = [
        ":mod1",
        ":mod2",
    ],
)

rust_test(
    name = "mod1_test",
    crate = ":mod1",
)

rust_test(
    name = "mod2_test",
    crate = ":mod2",
)

rust_test(
    name = "mod3_test",
    aliases = {
        ":mod1": "alias_a",
        ":mod2": "alias_b",
    },
    crate = ":mod3",
)
