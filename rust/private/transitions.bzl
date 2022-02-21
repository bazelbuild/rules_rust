# buildifier: disable=module-docstring
load("//rust:defs.bzl", "rust_common")

def _wasm_bindgen_transition(_settings, _attr):
    """The implementation of the `wasm_bindgen_transition` transition

    Args:
        _settings (dict): A dict {String:Object} of all settings declared
            in the inputs parameter to `transition()`
        _attr (dict): A dict of attributes and values of the rule to which
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

def _import_macro_dep_bootstrap_transition(_settings, _attr):
    """The implementation of the `import_macro_dep_bootstrap_transition` transition.

    This transition modifies the config to start using the fake macro
    implementation, so that the macro itself can be bootstrapped without
    creating a dependency cycle, even while every Rust target has an implicit
    dependency on the "import" macro (either real or fake).

    Args:
        _settings (dict): a dict {String:Object} of all settings declared in the
            inputs parameter to `transition()`.
        _attr (dict): A dict of attributes and values of the rule to which the
            transition is attached.

    Returns:
        dict: A dict of new build settings values to apply.
    """
    return {"@rules_rust//rust/settings:use_real_import_macro": False}

import_macro_dep_bootstrap_transition = transition(
    implementation = _import_macro_dep_bootstrap_transition,
    inputs = [],
    outputs = ["@rules_rust//rust/settings:use_real_import_macro"],
)

def _with_import_macro_bootstrapping_mode_impl(ctx):
    target = ctx.attr.target[0]
    providers = [target[rust_common.crate_info], target[rust_common.dep_info]]
    if hasattr(ctx, "executable") and hasattr(ctx.executable, "target"):
        symlink = ctx.actions.declare_file(target.label.name + "_symlink")
        ctx.actions.symlink(output = symlink, target_file = ctx.executable.target, is_executable = True)
        providers.append(DefaultInfo(executable = symlink))

    return providers

with_import_macro_bootstrapping_mode = rule(
    implementation = _with_import_macro_bootstrapping_mode_impl,
    attrs = {
        "target": attr.label(
            cfg = import_macro_dep_bootstrap_transition,
            allow_single_file = True,
            mandatory = True,
            executable = False,
        ),
        "_allowlist_function_transition": attr.label(
            default = Label("//tools/allowlists/function_transition_allowlist"),
        ),
    },
)
