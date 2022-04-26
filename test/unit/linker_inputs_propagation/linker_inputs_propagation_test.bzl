"""Unittests for propagation of linker inputs through Rust libraries"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _shared_lib_is_propagated_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    link_action = [action for action in tut.actions if action.mnemonic == "CppLink"][0]

    lib_name = _get_lib_name(ctx, name = "foo_shared")
    asserts.true(env, _contains_input(link_action.inputs, lib_name))

    return analysistest.end(env)

def _static_lib_is_not_propagated_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    link_action = [action for action in tut.actions if action.mnemonic == "CppLink"][0]

    lib_name = _get_lib_name(ctx, name = "foo")
    asserts.false(env, _contains_input(link_action.inputs, lib_name))

    return analysistest.end(env)

def _contains_input(inputs, name):
    for input in inputs.to_list():
        # We cannot check for name equality because rlib outputs contain
        # a hash in their name.
        if input.basename.startswith(name):
            return True
    return False

def _get_lib_name(ctx, name):
    if ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo]):
        return name
    else:
        return "lib{}".format(name)

static_lib_is_not_propagated_test = analysistest.make(
    _static_lib_is_not_propagated_test_impl,
    attrs = {
        "_windows_constraint": attr.label(default = Label("@platforms//os:windows")),
    },
)

shared_lib_is_propagated_test = analysistest.make(
    _shared_lib_is_propagated_test_impl,
    attrs = {
        "_macos_constraint": attr.label(default = Label("@platforms//os:macos")),
        "_windows_constraint": attr.label(default = Label("@platforms//os:windows")),
    },
)

def _linker_inputs_propagation_test():
    static_lib_is_not_propagated_test(
        name = "depends_on_foo_via_staticlib",
        target_under_test = "//test/linker_inputs_propagation:depends_on_foo_via_staticlib",
    )

    shared_lib_is_propagated_test(
        name = "depends_on_shared_foo_via_staticlib",
        target_under_test = "//test/linker_inputs_propagation:depends_on_shared_foo_via_staticlib",
    )

    static_lib_is_not_propagated_test(
        name = "depends_on_foo_via_sharedlib",
        target_under_test = "//test/linker_inputs_propagation:depends_on_foo_via_sharedlib",
    )

    shared_lib_is_propagated_test(
        name = "depends_on_shared_foo_via_sharedlib",
        target_under_test = "//test/linker_inputs_propagation:depends_on_shared_foo_via_sharedlib",
    )

def linker_inputs_propagation_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _linker_inputs_propagation_test()

    native.test_suite(
        name = name,
        tests = [
            ":depends_on_foo_via_staticlib",
            ":depends_on_shared_foo_via_staticlib",
            ":depends_on_foo_via_sharedlib",
            ":depends_on_shared_foo_via_sharedlib",
        ],
    )
