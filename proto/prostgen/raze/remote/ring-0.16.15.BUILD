"""
@generated
cargo-raze crate build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""
package(default_visibility = [
  # Public for visibility by "@raze__crate__version//" targets.
  #
  # Prefer access through "//proto/prostgen/raze", which limits external
  # visibility to explicit Cargo.toml dependencies.
  "//visibility:public",
])

licenses([
  "restricted", # no license
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)


# Unsupported target "aead_tests" with type "test" omitted
# Unsupported target "agreement_tests" with type "test" omitted
# Unsupported target "build-script-build" with type "custom-build" omitted
# Unsupported target "constant_time_tests" with type "test" omitted
# Unsupported target "digest_tests" with type "test" omitted
# Unsupported target "ecdsa_tests" with type "test" omitted
# Unsupported target "ed25519_tests" with type "test" omitted
# Unsupported target "hkdf_tests" with type "test" omitted
# Unsupported target "hmac_tests" with type "test" omitted
# Unsupported target "pbkdf2_tests" with type "test" omitted
# Unsupported target "quic_tests" with type "test" omitted
# Unsupported target "rand_tests" with type "test" omitted

rust_library(
    name = "ring",
    crate_type = "lib",
    deps = [
        "@raze__libc__0_2_77//:libc",
        "@raze__once_cell__1_4_1//:once_cell",
        "@raze__spin__0_5_2//:spin",
        "@raze__untrusted__0_7_1//:untrusted",
        ":ring-core",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    data = glob(["**/src/data/*", "**/src/ec/**/*.der"]),
    version = "0.16.15",
    tags = ["cargo-raze"],
    crate_features = [
        "alloc",
        "default",
        "dev_urandom_fallback",
        "once_cell",
    ],
)

# Unsupported target "rsa_tests" with type "test" omitted
# Unsupported target "signature_tests" with type "test" omitted

# Additional content from builds/ring-0.16.BUILD
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
