"""Compiled doctests need runtime dependencies, not their compilation tools."""

load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")

def _without_runfiles_impl(ctx):
    return [ctx.attr.dep[CcInfo]]

# A custom CcInfo dependency need not provide its own runtime runfiles.
without_runfiles = rule(
    implementation = _without_runfiles_impl,
    attrs = {"dep": attr.label(providers = [CcInfo])},
)

def _compiled_runfiles_test_impl(env, target):
    action = [action for action in target.actions if action.mnemonic == "RustdocTestCompile"][0]
    inputs = action.inputs.to_list()
    runfiles = target[DefaultInfo].default_runfiles.files.to_list()
    paths = [file.short_path for file in runfiles]

    env.expect.that_collection(paths).contains_at_least([
        "test/rustdoc_runfiles/crate.txt",
        "test/rustdoc_runfiles/transitive.txt",
        "test/rustdoc_runfiles/extra.txt",
        "test/rustdoc_runfiles/compile.txt",
    ])

    compilers = [file for file in inputs if file.basename in ["rustc", "rustdoc", "rustc.exe", "rustdoc.exe"]]
    env.expect.that_int(len(compilers)).is_greater_than(0)
    for file in compilers:
        env.expect.that_collection(runfiles).not_contains(file)

    runfile_paths = [file.path for file in runfiles]
    env.expect.that_collection(runfile_paths).not_contains_predicate(
        matching.contains("/rust_toolchain/"),
    )

    libraries = [file for file in inputs if "native_shared" in file.basename and file.extension in ["so", "dylib", "dll"]]
    env.expect.that_int(len(libraries)).is_greater_than(0)
    env.expect.that_collection(runfiles).contains_at_least(libraries)

def compiled_runfiles_test(name, target):
    """Analysis test macro for compiled rustdoc test runfiles.

    Args:
        name: Name of the test target.
        target: Target under test.
    """
    analysis_test(
        name = name,
        target = target,
        impl = _compiled_runfiles_test_impl,
    )
