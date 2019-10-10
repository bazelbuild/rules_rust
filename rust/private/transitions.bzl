def _wasm_transition(settings, attr):
    if attr.crate_type == "proc-macro":
        return {"//command_line_option:platforms": "@local_config_platform//:host"}
    else:
        return settings

def _wasm_bindgen_transition(settings, attr):
    return {"//command_line_option:platforms": "@io_bazel_rules_rust//rust/platform:wasm"}

wasm_transition = transition(
    implementation = _wasm_transition,
    inputs = ["//command_line_option:platforms"],
    outputs = ["//command_line_option:platforms"],
)

wasm_bindgen_transition = transition(
    implementation = _wasm_bindgen_transition,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)
