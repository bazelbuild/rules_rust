load(
    "//rust:rust.bzl",
    "rust_binary",
    "rust_test",
)

rust_binary(
    name = "hello-world",
    srcs = ["src/main.rs"],
    edition = "2018",
)

rust_test(
    name = "test",
    srcs = ["tests/run.rs"],
    data = [":hello-world"],
    edition = "2018",
    env = {
        "FERRIS_SAYS": "Hello fellow Rustaceans!",
        "HELLO_WORLD_BIN": "$(rootpath :hello-world)",
    },
)
