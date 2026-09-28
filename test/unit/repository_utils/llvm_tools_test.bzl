"""SDK runtime library regressions for issue #4298."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")

def _runtime_libraries_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(env, sorted(ctx.attr.expected), sorted([file.basename for file in ctx.attr.library[DefaultInfo].files.to_list()]))
    return unittest.end(env)

llvm_runtime_libraries_test = unittest.make(_runtime_libraries_impl, attrs = {"library": attr.label(mandatory = True), "expected": attr.string_list()})
