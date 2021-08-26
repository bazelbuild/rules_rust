"""Deprecated: Please use `@rules_rust//wasm:providers`"""

load(
    "//wasm:providers.bzl",
    _DeclarationInfo = "DeclarationInfo",
    _JSEcmaScriptModuleInfo = "JSEcmaScriptModuleInfo",
    _JSModuleInfo = "JSModuleInfo",
    _JSNamedModuleInfo = "JSNamedModuleInfo",
)

# buildifier: disable=print
print("__DEPRECATED__: The `@rules_rust//wasm_bindgen` package is deprecated. Use `@rules_rust//wasm` instead")

DeclarationInfo = _DeclarationInfo
JSEcmaScriptModuleInfo = _JSEcmaScriptModuleInfo
JSModuleInfo = _JSModuleInfo
JSNamedModuleInfo = _JSNamedModuleInfo
