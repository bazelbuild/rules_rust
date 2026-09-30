"""# rust_test_suite.bzl"""

load(
    "//rust/private:rust.bzl",
    _rust_test_suite = "rust_test_suite",
)

rust_test_suite = _rust_test_suite
