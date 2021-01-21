# buildifier: disable=module-docstring
def _wasm_bindgen_transition(settings, attr):
    """The implementation of the `wasm_bindgen_transition` transition

    Args:
        settings (dict): A dict {String:Object} of all settings declared
            in the inputs parameter to `transition()`
        attr (dict): A dict of attributes and values of the rule to which
            the transition is attached

    Returns:
        dict: A dict of new build settings values to apply
    """
    return {"//command_line_option:platforms": str(Label("//rust/platform:wasm"))}

wasm_bindgen_transition = transition(
    implementation = _wasm_bindgen_transition,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)
