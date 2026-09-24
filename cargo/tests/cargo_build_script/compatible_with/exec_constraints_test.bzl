"""Check that a Cargo build script constrains both execution stages."""

def exec_constraints_test(name, build_script, constraint):
    """Assert macro expansion forwards the execution constraint to both actions."""
    expected = str(Label(constraint))
    for target in [build_script + "_", build_script]:
        rule = native.existing_rule(target)
        if rule == None:
            fail("missing build script target " + target)
        actual = rule.get("exec_compatible_with", [])
        if len(actual) != 1 or str(actual[0]) != expected:
            fail("{} must execute on {}, got {}".format(target, expected, actual))

    native.test_suite(name = name, tests = [":test_compatible_with"])
