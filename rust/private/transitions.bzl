# buildifier: disable=module-docstring

load("//rust:defs.bzl", "rust_common")

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

def _rename_first_party_crates_transition_impl(settings, attr):
    """The implementation of the `rename_first_party_crates` transition

    Args:
        settings (dict): A dict {String:Object} of all settings declared
            in the inputs parameter to `transition()`
        attr (dict): A dict of attributes and values of the rule to which
            the transition is attached

    Returns:
        dict: A dict of new build settings values to apply
    """
    return {"@//rust/settings:rename_first_party_crates": False}

_rename_first_party_crates_transition = transition(
    implementation = _rename_first_party_crates_transition_impl,
    inputs = [],
    outputs = ["@//rust/settings:rename_first_party_crates"],
)

def _with_disabled_rename_first_party_crates_impl(ctx):
    target = ctx.attr.target[0]
    providers = [target[rust_common.crate_info], target[rust_common.dep_info]]
    if hasattr(ctx, "executable") and hasattr(ctx.executable, "target"):
        symlink = ctx.actions.declare_file(target.label.name + "_symlink")
        ctx.actions.symlink(output = symlink, target_file = ctx.executable.target, is_executable = True)
        providers.append(DefaultInfo(executable = symlink))

    return providers

def _with_disabled_rename_first_party_crates_generator(is_executable):
    """Generates a `rule` for which all dependencies will have first-party-crate-renaming disabled.

    Args:
        is_executable (bool): whether the target is an executable.

    Returns:
        rule: A rule whose dependencies will have first-party-crate-renaming disabled.
    """
    return rule(
        implementation = _with_disabled_rename_first_party_crates_impl,
        attrs = {
            "target": attr.label(
                cfg = _rename_first_party_crates_transition,
                allow_single_file = True,
                mandatory = True,
                executable = is_executable,
            ),
            "_allowlist_function_transition": attr.label(
                default = Label("//tools/allowlists/function_transition_allowlist"),
            ),
        },
    )

with_disabled_rename_first_party_crates_exec = _with_disabled_rename_first_party_crates_generator(True)
with_disabled_rename_first_party_crates = _with_disabled_rename_first_party_crates_generator(False)
