"""A module for re-exporting the providers used by the rust_wasm_bindgen rule"""

load(
    "@rules_nodejs//nodejs:providers.bzl",
    _DeclarationInfo = "DeclarationInfo",
    _JSModuleInfo = "JSModuleInfo",
)

DeclarationInfo = _DeclarationInfo
JSModuleInfo = _JSModuleInfo
