load(
    "//rust:rust.bzl",
    "rust_test_binary",
)

package(default_visibility = ["//visibility:public"])

# Here we build the rust binary that, when run, will run our test cases.
# However, it requires some other arbitrary setup first.
#
# If this was just `rust_test`, running `bazel test //...` would fail.
rust_test_binary(
    name = "rust_test_that_requires_wrapping",
    srcs = ["tests/rust_test_that_requires_wrapping.rs"],
)

# We do our arbitrary setup in another rule such as `sh_test` which can depend
# on `rust_test_binary` in its `data` attribute.
#
# This is a trivial case, but demonstrates that a rust_test_binary output can be
# executed from another test rule.
sh_test(
    name = "wrapped_rust_test",
    srcs = ["scripts/exec_with_test_env.sh"],
    args = ["$(location :rust_test_that_requires_wrapping)"],
    data = [":rust_test_that_requires_wrapping"],
)
