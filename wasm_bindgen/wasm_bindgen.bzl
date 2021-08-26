"""Deprecated: Please use `@rules_rust//wasm:providers`"""

load(
    "//wasm:wasm_bindgen.bzl",
    _rust_wasm_bindgen = "rust_wasm_bindgen",
    _rust_wasm_bindgen_toolchain = "rust_wasm_bindgen_toolchain",
)

# buildifier: disable=print
print("__DEPRECATED__: The `@rules_rust//wasm_bindgen` package is deprecated. Use `@rules_rust//wasm` instead")

rust_wasm_bindgen = _rust_wasm_bindgen
rust_wasm_bindgen_toolchain = _rust_wasm_bindgen_toolchain
