def _wasm_bindgen_transition(settings, attr):
    return {"//command_line_option:platforms": "@io_bazel_rules_rust//rust/platform:wasm"}

wasm_bindgen_transition = transition(
    implementation = _wasm_bindgen_transition,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)
