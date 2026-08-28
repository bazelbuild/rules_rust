"""# cargo_build_script.bzl"""

load(
    "//cargo/private:cargo_build_script_wrapper.bzl",
    _cargo_build_script = "cargo_build_script",
)

cargo_build_script = _cargo_build_script
