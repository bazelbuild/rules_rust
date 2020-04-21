"""
cargo-raze crate build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""
package(default_visibility = [
  # Public for visibility by "@raze__crate__version//" targets.
  #
  # Prefer access through "//proto/raze", which limits external
  # visibility to explicit Cargo.toml dependencies.
  "//visibility:public",
])

licenses([
  "notice", # "MIT,Apache-2.0"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)


# Unsupported target "build-script-build" with type "custom-build" omitted
# Unsupported target "client" with type "example" omitted
# Unsupported target "client_server" with type "bench" omitted

rust_library(
    name = "httpbis",
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    srcs = glob(["**/*.rs"]),
    deps = [
        "@raze__bytes__0_4_12//:bytes",
        "@raze__futures__0_1_29//:futures",
        "@raze__futures_cpupool__0_1_8//:futures_cpupool",
        "@raze__log__0_4_6//:log",
        "@raze__net2__0_2_33//:net2",
        "@raze__tls_api__0_1_22//:tls_api",
        "@raze__tls_api_stub__0_1_22//:tls_api_stub",
        "@raze__tokio_core__0_1_17//:tokio_core",
        "@raze__tokio_io__0_1_13//:tokio_io",
        "@raze__tokio_timer__0_1_2//:tokio_timer",
        "@raze__tokio_tls_api__0_1_22//:tokio_tls_api",
        "@raze__tokio_uds__0_1_7//:tokio_uds",
        "@raze__unix_socket__0_5_0//:unix_socket",
        "@raze__void__1_0_2//:void",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.7.0",
    crate_features = [
    ],
)

# Unsupported target "server" with type "example" omitted
