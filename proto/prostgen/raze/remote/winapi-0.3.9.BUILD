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
    name = "winapi_build_script",
    srcs = glob(["**/*.rs"]),
    crate_root = "build.rs",
    edition = "2015",
    deps = [
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    crate_features = [
      "errhandlingapi",
      "fileapi",
      "handleapi",
      "lmcons",
      "minschannel",
      "minwinbase",
      "minwindef",
      "ntdef",
      "ntsecapi",
      "profileapi",
      "schannel",
      "securitybaseapi",
      "sspi",
      "std",
      "sysinfoapi",
      "timezoneapi",
      "winbase",
      "wincrypt",
      "winerror",
      "winsock2",
      "ws2def",
      "ws2ipdef",
      "ws2tcpip",
      "wtypesbase",
    ],
    build_script_env = {
    },
    data = glob(["**"]),
    tags = ["cargo-raze"],
    version = "0.3.9",
    visibility = ["//visibility:private"],
)


rust_library(
    name = "winapi",
    crate_type = "lib",
    deps = [
        ":winapi_build_script",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.3.9",
    tags = ["cargo-raze"],
    crate_features = [
        "errhandlingapi",
        "fileapi",
        "handleapi",
        "lmcons",
        "minschannel",
        "minwinbase",
        "minwindef",
        "ntdef",
        "ntsecapi",
        "profileapi",
        "schannel",
        "securitybaseapi",
        "sspi",
        "std",
        "sysinfoapi",
        "timezoneapi",
        "winbase",
        "wincrypt",
        "winerror",
        "winsock2",
        "ws2def",
        "ws2ipdef",
        "ws2tcpip",
        "wtypesbase",
    ],
)

