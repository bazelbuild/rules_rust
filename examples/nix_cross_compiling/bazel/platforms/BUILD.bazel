package(default_visibility = ["//visibility:public"])

# Host
platform(
    name = "host",
    constraint_values = ["@platforms//os:nixos"],
    parents = ["@local_config_platform//:host"],
)

# Platforms
platform(
    name = "aarch64-apple-darwin",
    constraint_values = [
        "@platforms//cpu:aarch64",
        "@platforms//os:macos",
    ],
)

platform(
    name = "aarch64-apple-ios",
    constraint_values = [
        "@platforms//cpu:aarch64",
        "@platforms//os:ios",
    ],
)

platform(
    name = "aarch64-linux-android",
    constraint_values = [
        "@platforms//cpu:aarch64",
        "@platforms//os:android",
    ],
)

platform(
    name = "aarch64-unknown-linux-gnu",
    constraint_values = [
        "@platforms//cpu:aarch64",
        "@platforms//os:linux",
    ],
)

platform(
    name = "wasm32-unknown-unknown",
    constraint_values = [
        "@platforms//cpu:wasm32",
        "@platforms//os:none",
    ],
)

platform(
    name = "wasm32-wasi",
    constraint_values = [
        "@platforms//cpu:wasm32",
        "@platforms//os:wasi",
    ],
)

platform(
    name = "x86_64-apple-darwin",
    constraint_values = [
        "@platforms//cpu:x86_64",
        "@platforms//os:macos",
    ],
)

platform(
    name = "x86_64-pc-windows-msvc",
    constraint_values = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
    ],
)

platform(
    name = "x86_64-unknown-linux-gnu",
    constraint_values = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
    ],
)

platform(
    name = "x86_64-unknown-nixos-gnu",
    constraint_values = [
        "@platforms//cpu:x86_64",
        "@platforms//os:nixos",
    ],
)

# Sentinel to catch implicit target platform usage
platform(
    name = "missing",
    constraint_values = [
        ":missing_constraint_value",
    ],
)

constraint_setting(name = "missing_constraint_setting")

constraint_value(
    name = "missing_constraint_value",
    constraint_setting = ":missing_constraint_setting",
)
