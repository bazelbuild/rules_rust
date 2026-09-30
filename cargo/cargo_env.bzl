"""# cargo_env.bzl"""

load(
    "//cargo/private:cargo_bootstrap.bzl",
    _cargo_env = "cargo_env",
)

cargo_env = _cargo_env
