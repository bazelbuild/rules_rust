"""Compiled doctests need runtime dependencies, not their compilation tools."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def _without_runfiles_impl(ctx):
    return [ctx.attr.dep[CcInfo]]

# A custom CcInfo dependency need not provide its own runtime runfiles.
without_runfiles = rule(
    implementation = _without_runfiles_impl,
    attrs = {"dep": attr.label(providers = [CcInfo])},
)

def _compiled_runfiles_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    action = [action for action in target.actions if action.mnemonic == "RustdocTestCompile"][0]
    inputs = action.inputs.to_list()
    runfiles = target[DefaultInfo].default_runfiles.files.to_list()
    paths = [file.short_path for file in runfiles]

    for name in ["crate.txt", "transitive.txt", "extra.txt", "compile.txt"]:
        asserts.true(env, "test/rustdoc_runfiles/" + name in paths, "Missing runfile: " + name)

    compilers = [file for file in inputs if file.basename in ["rustc", "rustdoc", "rustc.exe", "rustdoc.exe"]]
    asserts.true(env, bool(compilers), "Compilation must retain its compiler inputs")
    for file in compilers:
        asserts.false(env, file in runfiles, "Compiler should not be a test input: " + file.path)
    for file in runfiles:
        asserts.false(env, "/rust_toolchain/" in file.path, "Compiler SDK should not be a test input: " + file.path)

    libraries = [file for file in inputs if "native_shared" in file.basename and file.extension in ["so", "dylib", "dll"]]
    asserts.true(env, bool(libraries), "Fixture must link a shared native library")
    for file in libraries:
        asserts.true(env, file in runfiles, "Missing shared library: " + file.path)

    return analysistest.end(env)

compiled_runfiles_test = analysistest.make(
    _compiled_runfiles_test_impl,
)
