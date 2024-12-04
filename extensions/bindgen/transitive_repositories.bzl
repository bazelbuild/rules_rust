"""Transitive dependencies for the Rust `bindgen` rules"""

load("@llvm-raw//utils/bazel:configure.bzl", "llvm_configure", "llvm_disable_optional_support_deps")

# buildifier: disable=unnamed-macro
def rust_bindgen_transitive_dependencies():
    """Declare transitive dependencies needed for bindgen."""

    llvm_configure(
        name = "llvm-project",
        repo_mapping = {"@llvm_zlib": "@zlib"},
        targets = [
            "AArch64",
            "X86",
        ],
    )

    # Disables optional dependencies for Support like zlib and terminfo. You may
    # instead want to configure them using the macros in the corresponding bzl
    # files.
    llvm_disable_optional_support_deps()
