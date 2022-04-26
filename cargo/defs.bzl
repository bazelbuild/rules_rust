"""Common definitions for the `@rules_rust//cargo` package"""

load(":cargo_bootstrap.bzl", _cargo_bootstrap_repository = "cargo_bootstrap_repository", _cargo_env = "cargo_env")
load(":cargo_build_script.bzl", _cargo_build_script = "cargo_build_script")
load(":cargo_environ.bzl", _CARGO_BAZEL_ISOLATED = "CARGO_BAZEL_ISOLATED", _cargo_environ = "cargo_environ")

cargo_bootstrap_repository = _cargo_bootstrap_repository
cargo_env = _cargo_env
cargo_environ = _cargo_environ
CARGO_BAZEL_ISOLATED = _CARGO_BAZEL_ISOLATED

cargo_build_script = _cargo_build_script
