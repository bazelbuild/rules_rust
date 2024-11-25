"""Transitive dependencies for the Rust `bindgen` rules"""

load("@llvm-raw//utils/bazel:configure.bzl", "llvm_configure", "llvm_disable_optional_support_deps")

DEFAULT_REPO_MAPPING = {
    "@llvm_zlib": "@zlib",
}
LLVM_TARGETS = ["AArch64", "X86"]

# buildifier: disable=unnamed-macro
def rust_bindgen_transitive_dependencies(repo_mapping = DEFAULT_REPO_MAPPING):
    """Declare transitive dependencies needed for bindgen.

    Args:
      repo_mapping: Mapping for renaming repositories created by this function.
        The repository names created by this function are undocumented and subject
        to change in the future.
    """

    # Bzlmod does not support the `repo_mapping` parameter *at all*, so we have
    # to only specify it when requested.
    if repo_mapping == None:
        llvm_configure(
            name = "llvm-project",
            targets = LLVM_TARGETS,
        )
    else:
        llvm_repo_name = repo_mapping.get("llvm-project", "llvm-project")
        llvm_configure(
            name = llvm_repo_name,
            repo_mapping = repo_mapping,
            targets = LLVM_TARGETS,
        )

    # Disables optional dependencies for Support like zlib and terminfo. You may
    # instead want to configure them using the macros in the corresponding bzl
    # files.
    llvm_disable_optional_support_deps()
