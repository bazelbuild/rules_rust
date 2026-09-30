"""# extract_cargo_lints.bzl"""

load(
    "//cargo/private:cargo_lints.bzl",
    _extract_cargo_lints = "extract_cargo_lints",
)

extract_cargo_lints = _extract_cargo_lints
