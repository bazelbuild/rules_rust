"""# rust_doc.bzl"""

load(
    "//rust/private:rustdoc.bzl",
    _rust_doc = "rust_doc",
    _rustdoc_compile_action = "rustdoc_compile_action",
)

rust_doc = _rust_doc

# Custom runners can record the action without copying compiler argument logic.
rustdoc_compile_action = _rustdoc_compile_action
