"""A module for re-exporting the providers used by the rust_wasm_bindgen rule"""

load(
    "@aspect_rules_js//js:providers.bzl",
    _JsInfo = "JsInfo",
)

JsInfo = _JsInfo
