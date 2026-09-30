"""# rust_static_library.bzl"""

load(
    "//rust/private:rust.bzl",
    _rust_static_library = "rust_static_library",
)

rust_static_library = _rust_static_library
