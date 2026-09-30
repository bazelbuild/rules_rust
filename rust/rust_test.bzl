"""# rust_test.bzl"""

load(
    "//rust/private:rust.bzl",
    _rust_test = "rust_test",
)

rust_test = _rust_test
