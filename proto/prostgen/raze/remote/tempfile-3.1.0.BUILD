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


# Unsupported target "namedtempfile" with type "test" omitted
# Unsupported target "spooled" with type "test" omitted
# Unsupported target "tempdir" with type "test" omitted

rust_library(
    name = "tempfile",
    crate_type = "lib",
    deps = [
        "@raze__cfg_if__0_1_10//:cfg_if",
        "@raze__libc__0_2_77//:libc",
        "@raze__rand__0_7_3//:rand",
        "@raze__remove_dir_all__0_5_3//:remove_dir_all",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "3.1.0",
    tags = ["cargo-raze"],
    crate_features = [
    ],
)

# Unsupported target "tempfile" with type "test" omitted
