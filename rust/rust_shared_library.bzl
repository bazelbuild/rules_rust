"""# rust_shared_library.bzl"""

load(
    "//rust/private:rust.bzl",
    _rust_cdylib_library = "rust_cdylib_library",
)

rust_shared_library = _rust_cdylib_library
