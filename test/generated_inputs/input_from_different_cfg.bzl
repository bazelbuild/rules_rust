"""A custom rule that generates a .rs file."""

def _change_cfg_impl(_settings, _attr):
    """A simple transition to provide us a different configuration
    Args:
        _settings (dict): a dict {String:Object} of all settings declared in the
            inputs parameter to `transition()`.
        _attr (dict): A dict of attributes and values of the rule to which the
            transition is attached.
    Returns:
        dict: A dict of new build settings values to apply.
    """
    return {"//test/generated_inputs:change_cfg": True}

change_cfg_transition = transition(
    implementation = _change_cfg_impl,
    inputs = [],
    outputs = ["//test/generated_inputs:change_cfg"],
)

def _input_from_different_cfg_impl(ctx):
    rs_file = ctx.actions.declare_file(ctx.label.name + ".rs")
    code = """
pub fn generated_fn() -> String {
    "Generated".to_owned()
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_generated() {
        assert_eq!(super::generated_fn(), "Generated".to_owned());
    }
}
"""
    ctx.actions.run_shell(
        outputs = [rs_file],
        command = """cat <<EOF > {}
{}
EOF
""".format(rs_file.path, code),
        mnemonic = "WriteRsFile",
    )

    return OutputGroupInfo(generated_file = depset([rs_file]))

input_from_different_cfg = rule(
    implementation = _input_from_different_cfg_impl,
    attrs = {
        "_allowlist_function_transition": attr.label(
            default = Label("@bazel_tools//tools/allowlists/function_transition_allowlist"),
        ),
    },
    cfg = change_cfg_transition,
)
