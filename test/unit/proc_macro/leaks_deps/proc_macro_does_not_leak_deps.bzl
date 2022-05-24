"""Unittest to verify proc-macro targets"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_proc_macro", "rust_test")

def _proc_macro_does_not_leak_deps_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_under_test(env).actions
    rustc_action = None
    for action in actions:
        if action.mnemonic == "Rustc":
            rustc_action = action
            break

    asserts.false(env, rustc_action == None)

    # Our test target has a dependency on "proc_macro_dep" via a rust_proc_macro target,
    # so the proc_macro_dep rlib should not appear as an input to the Rustc action, nor as -Ldependency on the command line.
    proc_macro_dep_inputs = [i for i in rustc_action.inputs.to_list() if "proc_macro_dep" in i.path]
    proc_macro_dep_args = [arg for arg in rustc_action.argv if "proc_macro_dep" in arg]

    asserts.equals(env, 0, len(proc_macro_dep_inputs))
    asserts.equals(env, 0, len(proc_macro_dep_args))

    # Our test target depends on proc_macro_dep:native directly, as well as transitively through the
    # proc_macro. The proc_macro should not leak its dependency, so we should only get the "native"
    # library once on the command line.
    native_deps = [arg for arg in rustc_action.argv if arg.startswith("-Clink-arg=-lnative")]
    asserts.equals(env, 1, len(native_deps))

    return analysistest.end(env)

proc_macro_does_not_leak_deps_test = analysistest.make(_proc_macro_does_not_leak_deps_impl)

def _proc_macro_does_not_leak_deps_test():
    rust_proc_macro(
        name = "proc_macro_definition",
        srcs = ["leaks_deps/proc_macro_definition.rs"],
        edition = "2018",
        deps = ["//test/unit/proc_macro/leaks_deps/proc_macro_dep"],
    )

    rust_proc_macro(
        name = "proc_macro_with_native_dep",
        srcs = ["leaks_deps/proc_macro_definition_with_native_dependency.rs"],
        edition = "2018",
        deps = [
            "//test/unit/proc_macro/leaks_deps/proc_macro_dep:proc_macro_dep_with_native_dep",
            "//test/unit/proc_macro/leaks_deps/native",
        ],
    )

    rust_test(
        name = "deps_not_leaked",
        srcs = ["leaks_deps/proc_macro_user.rs"],
        edition = "2018",
        deps = [
            "//test/unit/proc_macro/leaks_deps/native",
        ],
        proc_macro_deps = [
            ":proc_macro_definition",
            ":proc_macro_with_native_dep",
        ],
    )

    proc_macro_does_not_leak_deps_test(
        name = "proc_macro_does_not_leak_deps_test",
        target_under_test = ":deps_not_leaked",
    )

def proc_macro_does_not_leak_deps_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _proc_macro_does_not_leak_deps_test()

    native.test_suite(
        name = name,
        tests = [
            ":proc_macro_does_not_leak_deps_test",
        ],
    )
