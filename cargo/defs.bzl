"""# Cargo

Common definitions for the `@rules_rust//cargo` package
"""

load(
    "//cargo/private:cargo_build_script_wrapper.bzl",
    _cargo_build_script = "cargo_build_script",
)
load(
    "//cargo/private:cargo_lints.bzl",
    _extract_cargo_lints = "extract_cargo_lints",
)
load(
    "//cargo/private:cargo_toml_env_vars.bzl",
    _cargo_toml_env_vars = "cargo_toml_env_vars",
)

cargo_build_script = _cargo_build_script

extract_cargo_lints = _extract_cargo_lints

cargo_toml_env_vars = _cargo_toml_env_vars
