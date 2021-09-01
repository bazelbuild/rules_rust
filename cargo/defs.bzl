"""Common definitions for the `@rules_rust//cargo` package"""

load(":cargo_bootstrap.bzl", _cargo_bootstrap_repository = "cargo_bootstrap_repository")
load(":cargo_build_script.bzl", _cargo_build_script = "cargo_build_script")

cargo_bootstrap_repository = _cargo_bootstrap_repository
cargo_build_script = _cargo_build_script
