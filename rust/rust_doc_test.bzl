"""# rust_doc_test.bzl"""

load(
    "//rust/private:rustdoc_test.bzl",
    _rust_doc_test = "rust_doc_test",
)

rust_doc_test = _rust_doc_test
