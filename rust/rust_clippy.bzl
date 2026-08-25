"""# rust_clippy.bzl"""

load(
    "//rust/private:clippy.bzl",
    _rust_clippy = "rust_clippy",
)

rust_clippy = _rust_clippy
