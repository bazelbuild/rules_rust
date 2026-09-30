"""# cargo_dep_env.bzl"""

load(
    "//cargo/private:cargo_dep_env.bzl",
    _cargo_dep_env = "cargo_dep_env",
)

cargo_dep_env = _cargo_dep_env
