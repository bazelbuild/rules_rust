"""# rust_proc_macro.bzl"""

load(
    "//rust/private:rust.bzl",
    _rust_proc_macro = "rust_proc_macro",
)

rust_proc_macro = _rust_proc_macro
