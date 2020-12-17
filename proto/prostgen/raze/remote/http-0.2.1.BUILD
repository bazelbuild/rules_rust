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


# Unsupported target "header_map" with type "bench" omitted
# Unsupported target "header_map" with type "test" omitted
# Unsupported target "header_map_fuzz" with type "test" omitted
# Unsupported target "header_name" with type "bench" omitted
# Unsupported target "header_value" with type "bench" omitted

rust_library(
    name = "http",
    crate_type = "lib",
    deps = [
        "@raze__bytes__0_5_6//:bytes",
        "@raze__fnv__1_0_7//:fnv",
        "@raze__itoa__0_4_6//:itoa",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.2.1",
    tags = ["cargo-raze"],
    crate_features = [
    ],
)

# Unsupported target "status_code" with type "test" omitted
# Unsupported target "uri" with type "bench" omitted
