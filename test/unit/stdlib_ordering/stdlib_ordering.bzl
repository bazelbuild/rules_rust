"""Unittest to verify ordering of rust stdlib in rust_library() CcInfo"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_library")

def _categorize_library(name):
    """Given an rlib name, guess if it's std, core, or alloc."""
    if "std" in name:
        return "std"
    if "core" in name:
        return "core"
    if "alloc" in name:
        return "alloc"
    if "compiler_builtins" in name:
        return "compiler_builtins"
    return "other"

def _dedup_preserving_order(list):
    """Given a list, deduplicate its elements preserving order."""
    r = []
    seen = {}
    for e in list:
        if e in seen:
            continue
        seen[e] = 1
        r.append(e)
    return r

def _libstd_ordering_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    libs = [lib.static_library for li in tut[CcInfo].linking_context.linker_inputs.to_list() for lib in li.libraries]
    rlibs = [_categorize_library(lib.basename) for lib in libs if ".rlib" in lib.basename]
    set_to_check = _dedup_preserving_order([lib for lib in rlibs if lib != "other"])
    asserts.equals(env, ["std", "core", "compiler_builtins", "alloc"], set_to_check)
    return analysistest.end(env)

libstd_ordering_test = analysistest.make(_libstd_ordering_test_impl)

def _native_dep_test():
    rust_library(
        name = "some_rlib",
        srcs = ["some_rlib.rs"],
    )

    libstd_ordering_test(
        name = "libstd_ordering_test",
        target_under_test = ":some_rlib",
    )

def stdlib_ordering_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _native_dep_test()

    native.test_suite(
        name = name,
        tests = [
            ":libstd_ordering_test",
        ],
    )
