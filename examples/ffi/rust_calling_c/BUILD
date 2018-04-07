package(default_visibility = ["//visibility:public"])

load("@//rust:rust.bzl", "rust_binary", "rust_library")

# C++ library we are making Rust bindings for.
cc_library(
    name = "greeter",
    hdrs = ["greeter.h"],
    srcs = ["greeter.cpp"],
)

# C API for the above library that we will invoke from Rust via FFI.
cc_library(
    name = "greeter_c_api",
    srcs = ["greeter_c_api.cpp"],
    deps = [":greeter"],
)

# Rust bindings
rust_library(
    name = "rusty_greeter",
    srcs = ["lib.rs"],
    deps = [
      ":greeter_c_api",
      "@examples//fibonacci:fibonacci",
    ],
)

# Rust program that uses the Rust bindings.
rust_binary(
    name = "hello",
    srcs = ["main.rs"],
    deps = [":rusty_greeter"],
)
