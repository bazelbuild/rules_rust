"""# rustfmt_test.bzl"""

load(
    "//rust/private:rustfmt.bzl",
    _rustfmt_test = "rustfmt_test",
)

rustfmt_test = _rustfmt_test
