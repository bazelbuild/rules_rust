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
  "notice", # MIT from expression "MIT"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)



rust_library(
    name = "async_stream",
    crate_type = "lib",
    deps = [
        "@raze__futures_core__0_3_5//:futures_core",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    proc_macro_deps = [
        "@raze__async_stream_impl__0_2_1//:async_stream_impl",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.2.1",
    tags = ["cargo-raze"],
    crate_features = [
    ],
)

# Unsupported target "for_await" with type "test" omitted
# Unsupported target "stream" with type "test" omitted
# Unsupported target "tcp_accept" with type "example" omitted
# Unsupported target "try_stream" with type "test" omitted
