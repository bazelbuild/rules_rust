"""# Cargo

Common definitions for the `@rules_rust//cargo` package
"""

load(
    "//cargo:cargo_bootstrap_repository.bzl",
    _cargo_bootstrap_repository = "cargo_bootstrap_repository",
)
load(
    "//cargo:cargo_build_script.bzl",
    _cargo_build_script = "cargo_build_script",
)
load(
    "//cargo:cargo_dep_env.bzl",
    _cargo_dep_env = "cargo_dep_env",
)
load(
    "//cargo:cargo_env.bzl",
    _cargo_env = "cargo_env",
)
load(
    "//cargo:extract_cargo_lints.bzl",
    _extract_cargo_lints = "extract_cargo_lints",
)
load("//cargo/private:cargo_toml_env_vars.bzl", _cargo_toml_env_vars = "cargo_toml_env_vars")

cargo_bootstrap_repository = _cargo_bootstrap_repository
cargo_env = _cargo_env

cargo_build_script = _cargo_build_script
cargo_dep_env = _cargo_dep_env

extract_cargo_lints = _extract_cargo_lints

cargo_toml_env_vars = _cargo_toml_env_vars
