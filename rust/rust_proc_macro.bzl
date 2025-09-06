"""rust_proc_macro"""

load(
    "//rust/private:rust_proc_macro.bzl",
    _rust_proc_macro = "rust_proc_macro_macro",
)

rust_proc_macro = _rust_proc_macro
