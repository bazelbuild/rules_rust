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
  "notice", # "MIT"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)


# Unsupported target "atomic_task" with type "test" omitted
# Unsupported target "errors" with type "test" omitted
# Unsupported target "fuzz_atomic_task" with type "test" omitted
# Unsupported target "fuzz_list" with type "test" omitted
# Unsupported target "fuzz_mpsc" with type "test" omitted
# Unsupported target "fuzz_oneshot" with type "test" omitted
# Unsupported target "fuzz_semaphore" with type "test" omitted
# Unsupported target "lock" with type "test" omitted
# Unsupported target "mpsc" with type "bench" omitted
# Unsupported target "mpsc" with type "test" omitted
# Unsupported target "oneshot" with type "bench" omitted
# Unsupported target "oneshot" with type "test" omitted
# Unsupported target "semaphore" with type "test" omitted

rust_library(
    name = "tokio_sync",
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    srcs = glob(["**/*.rs"]),
    deps = [
        "@raze__fnv__1_0_6//:fnv",
        "@raze__futures__0_1_29//:futures",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.1.8",
    crate_features = [
    ],
)

# Unsupported target "watch" with type "test" omitted
