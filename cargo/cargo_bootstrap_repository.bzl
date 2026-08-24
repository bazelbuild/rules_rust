"""# cargo_bootstrap_repository.bzl"""

load(
    "//cargo/private:cargo_bootstrap.bzl",
    _cargo_bootstrap_repository = "cargo_bootstrap_repository",
)

cargo_bootstrap_repository = _cargo_bootstrap_repository
