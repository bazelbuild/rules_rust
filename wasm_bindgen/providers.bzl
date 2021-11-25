"""A module for re-exporting the providers used by the rust_wasm_bindgen rule"""

load(
    "@build_bazel_rules_nodejs//:providers.bzl",
    _DeclarationInfo = "DeclarationInfo",
    _JSEcmaScriptModuleInfo = "JSEcmaScriptModuleInfo",
    _JSModuleInfo = "JSModuleInfo",
    _JSNamedModuleInfo = "JSNamedModuleInfo",
)

DeclarationInfo = _DeclarationInfo
JSEcmaScriptModuleInfo = _JSEcmaScriptModuleInfo
JSModuleInfo = _JSModuleInfo
JSNamedModuleInfo = _JSNamedModuleInfo
