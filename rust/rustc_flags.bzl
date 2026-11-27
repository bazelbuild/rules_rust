"""# rustc_flags.bzl"""

load(
    "//rust/private:rustc_flags.bzl",
    _RustcFlagsInfo = "RustcFlagsInfo",
    _rustc_flags = "rustc_flags",
)

RustcFlagsInfo = _RustcFlagsInfo
rustc_flags = _rustc_flags
