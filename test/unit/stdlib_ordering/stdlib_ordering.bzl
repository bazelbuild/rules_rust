load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts", "unittest")
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

def _dedup_preserving_order(l):
    """Given a list, deduplicate its elements preserving order."""
    r = []
    seen = {}
    for e in l:
        if e in seen:
            continue
        seen[e] = 1
        r.append(e)
    return r

def _libstd_ordering_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    libs = [l.static_library for li in tut[CcInfo].linking_context.linker_inputs.to_list() for l in li.libraries]
    rlibs = [_categorize_library(l.basename) for l in libs if ".rlib" in l.basename]
    set_to_check = _dedup_preserving_order([l for l in rlibs if l != "other"])
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
