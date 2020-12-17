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
  "notice", # MIT from expression "MIT OR Apache-2.0"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)


# Unsupported target "client" with type "example" omitted
# Unsupported target "find_internet_password" with type "example" omitted

rust_library(
    name = "security_framework",
    crate_type = "lib",
    deps = [
        "@raze__bitflags__1_2_1//:bitflags",
        "@raze__core_foundation__0_7_0//:core_foundation",
        "@raze__core_foundation_sys__0_7_0//:core_foundation_sys",
        "@raze__libc__0_2_77//:libc",
        "@raze__security_framework_sys__1_0_0//:security_framework_sys",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.0.0",
    tags = ["cargo-raze"],
    crate_features = [
        "OSX_10_9",
        "default",
    ],
)

# Unsupported target "set_internet_password" with type "example" omitted
