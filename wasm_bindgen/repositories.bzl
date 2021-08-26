"""Deprecated: Please use `@rules_rust//wasm:providers`"""

load(
    "//wasm:repositories.bzl",
    _rust_wasm_bindgen_repositories = "rust_wasm_bindgen_repositories",
)

# buildifier: disable=print
print("__DEPRECATED__: The `@rules_rust//wasm_bindgen` package is deprecated. Use `@rules_rust//wasm` instead")

rust_wasm_bindgen_repositories = _rust_wasm_bindgen_repositories
