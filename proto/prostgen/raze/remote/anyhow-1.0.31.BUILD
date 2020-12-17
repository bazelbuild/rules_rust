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

load(
    "@io_bazel_rules_rust//cargo:cargo_build_script.bzl",
    "cargo_build_script",
)

cargo_build_script(
    name = "anyhow_build_script",
    srcs = glob(["**/*.rs"]),
    crate_root = "build.rs",
    edition = "2018",
    deps = [
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    crate_features = [
      "default",
      "std",
    ],
    build_script_env = {
    },
    data = glob(["**"]),
    tags = ["cargo-raze"],
    version = "1.0.31",
    visibility = ["//visibility:private"],
)


rust_library(
    name = "anyhow",
    crate_type = "lib",
    deps = [
        ":anyhow_build_script",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.0.31",
    tags = ["cargo-raze"],
    crate_features = [
        "default",
        "std",
    ],
)

# Unsupported target "compiletest" with type "test" omitted
# Unsupported target "test_autotrait" with type "test" omitted
# Unsupported target "test_backtrace" with type "test" omitted
# Unsupported target "test_boxed" with type "test" omitted
# Unsupported target "test_chain" with type "test" omitted
# Unsupported target "test_context" with type "test" omitted
# Unsupported target "test_convert" with type "test" omitted
# Unsupported target "test_downcast" with type "test" omitted
# Unsupported target "test_fmt" with type "test" omitted
# Unsupported target "test_macros" with type "test" omitted
# Unsupported target "test_repr" with type "test" omitted
# Unsupported target "test_source" with type "test" omitted
