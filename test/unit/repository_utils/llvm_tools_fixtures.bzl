"""Minimal SDK repositories exercising the generated LLVM library glob."""

load("//rust/platform:triple.bzl", "triple")

# buildifier: disable=bzl-visibility
load("//rust/private:repository_utils.bzl", "BUILD_for_llvm_tools")

def _fixture_impl(ctx):
    ctx.file("BUILD.bazel", BUILD_for_llvm_tools(triple(ctx.attr.triple)))
    for filename in ctx.attr.libraries:
        ctx.file("lib/rustlib/" + ctx.attr.triple + "/lib/" + filename, "fixture")
    ctx.file("lib/rustlib/unrelated-target/lib/libLLVM-wrong.dylib", "not selected")

_fixture = repository_rule(implementation = _fixture_impl, attrs = {"triple": attr.string(), "libraries": attr.string_list()})

def _fixtures_impl(_ctx):
    _fixture(name = "llvm_macos_fixture", triple = "aarch64-apple-darwin", libraries = ["libLLVM.dylib", "libLLVM-23.dylib", "libLLVM.a"])
    _fixture(name = "llvm_linux_fixture", triple = "x86_64-unknown-linux-gnu", libraries = ["libLLVM.so", "libLLVM.so.23", "libLLVM.a"])
    _fixture(name = "llvm_static_fixture", triple = "aarch64-apple-darwin", libraries = ["libLLVM.a"])

fixtures = module_extension(implementation = _fixtures_impl)
