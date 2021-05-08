load("@rules_cc//cc:defs.bzl", "cc_library")

# Based off of ring's build.rs file:
# https://github.com/briansmith/ring/blob/master/build.rs
cc_library(
    name = "ring-core",
    srcs = glob(
        [
            "**/*.h",
            "**/*.c",
            "**/*.inl",
            "**/*x86_64*-elf.S",
        ],
        exclude = ["crypto/constant_time_test.c"],
    ),
    copts = [
        "-fno-strict-aliasing",
        "-fvisibility=hidden",
    ],
    includes = [
        "include",
    ],
)
