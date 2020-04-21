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


# Unsupported target "all" with type "test" omitted
# Unsupported target "bilock" with type "bench" omitted
# Unsupported target "bilock" with type "test" omitted
# Unsupported target "buffer_unordered" with type "test" omitted
# Unsupported target "channel" with type "test" omitted
# Unsupported target "eager_drop" with type "test" omitted
# Unsupported target "eventual" with type "test" omitted
# Unsupported target "fuse" with type "test" omitted
# Unsupported target "future_flatten_stream" with type "test" omitted

rust_library(
    name = "futures",
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    srcs = glob(["**/*.rs"]),
    deps = [
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.1.29",
    crate_features = [
        "default",
        "use_std",
        "with-deprecated",
    ],
)

# Unsupported target "futures_ordered" with type "test" omitted
# Unsupported target "futures_unordered" with type "bench" omitted
# Unsupported target "futures_unordered" with type "test" omitted
# Unsupported target "inspect" with type "test" omitted
# Unsupported target "mpsc" with type "test" omitted
# Unsupported target "mpsc-close" with type "test" omitted
# Unsupported target "oneshot" with type "test" omitted
# Unsupported target "poll" with type "bench" omitted
# Unsupported target "ready_queue" with type "test" omitted
# Unsupported target "recurse" with type "test" omitted
# Unsupported target "select_all" with type "test" omitted
# Unsupported target "select_ok" with type "test" omitted
# Unsupported target "shared" with type "test" omitted
# Unsupported target "sink" with type "test" omitted
# Unsupported target "split" with type "test" omitted
# Unsupported target "stream" with type "test" omitted
# Unsupported target "stream_catch_unwind" with type "test" omitted
# Unsupported target "sync_mpsc" with type "bench" omitted
# Unsupported target "thread_notify" with type "bench" omitted
# Unsupported target "unfold" with type "test" omitted
# Unsupported target "unsync" with type "test" omitted
# Unsupported target "unsync-oneshot" with type "test" omitted
