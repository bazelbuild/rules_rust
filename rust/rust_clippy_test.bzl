"""# rust_clippy_test.bzl"""

load(
    "//rust/private:clippy.bzl",
    _rust_clippy_test = "rust_clippy_test",
)

rust_clippy_test = _rust_clippy_test
