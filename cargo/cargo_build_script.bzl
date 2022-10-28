"""Legacy load locations for Cargo build script rules

Instead, `defs.bzl` should be used.
"""

load(
    "//cargo/private:cargo_build_script.bzl",
    _cargo_dep_env = "cargo_dep_env",
)
load(
    "//cargo/private:cargo_build_script_wrapper.bzl",
    _cargo_build_script = "cargo_build_script",
)

cargo_build_script = _cargo_build_script
cargo_dep_env = _cargo_dep_env
