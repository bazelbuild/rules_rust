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
  "notice", # Apache-2.0 from expression "Apache-2.0 OR MIT"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)

load(
    "@io_bazel_rules_rust//cargo:cargo_build_script.bzl",
    "cargo_build_script",
)

cargo_build_script(
    name = "indexmap_build_script",
    srcs = glob(["**/*.rs"]),
    crate_root = "build.rs",
    edition = "2018",
    deps = [
        "@raze__autocfg__1_0_1//:autocfg",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    crate_features = [
    ],
    build_script_env = {
    },
    data = glob(["**"]),
    tags = ["cargo-raze"],
    version = "1.6.0",
    visibility = ["//visibility:private"],
)

# Unsupported target "bench" with type "bench" omitted
# Unsupported target "equivalent_trait" with type "test" omitted
# Unsupported target "faststring" with type "bench" omitted

rust_library(
    name = "indexmap",
    crate_type = "lib",
    deps = [
        ":indexmap_build_script",
        "@raze__hashbrown__0_9_0//:hashbrown",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.6.0",
    tags = ["cargo-raze"],
    crate_features = [
    ],
)

# Unsupported target "macros_full_path" with type "test" omitted
# Unsupported target "quick" with type "test" omitted
# Unsupported target "tests" with type "test" omitted
