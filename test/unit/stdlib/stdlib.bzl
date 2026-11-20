"""Unittest to verify contents and ordering of rust stdlib in rust_library() CcInfo"""

load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
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

def _stdlibs(tut):
    """Given a target, return the list of its standard rust libraries."""
    libs = [
        lib.static_library
        for li in tut[CcInfo].linking_context.linker_inputs.to_list()
        for lib in li.libraries
    ]
    stdlibs = [lib for lib in libs if (lib and tut.label.name not in lib.basename)]
    return stdlibs

def _libstd_ordering_test_impl(env, target):
    stdlib_categories = [_categorize_library(lib.basename) for lib in _stdlibs(target)]
    set_to_check = _dedup_preserving_order([lib for lib in stdlib_categories if lib != "other"])
    env.expect.that_collection(set_to_check).contains_exactly([
        "std",
        "core",
        "compiler_builtins",
        "alloc",
    ]).in_order()

def _libstd_ordering_test(name):
    util.helper_target(
        rust_library,
        name = name + "_some_rlib",
        srcs = ["some_rlib.rs"],
        edition = "2018",
    )

    analysis_test(
        name = name,
        target = ":" + name + "_some_rlib",
        impl = _libstd_ordering_test_impl,
    )

def _libstd_panic_test_impl(env, target):
    # The libraries panic_unwind and panic_abort are alternatives.
    # Check that they don't occur together.
    stdlibs = _stdlibs(target)
    has_panic_unwind = [lib for lib in stdlibs if "panic_unwind" in lib.basename]
    if has_panic_unwind:
        has_panic_abort = [lib for lib in stdlibs if "panic_abort" in lib.basename]
        env.expect.that_collection(has_panic_abort).contains_exactly([])

def _libstd_panic_test(name):
    util.helper_target(
        rust_library,
        name = name + "_some_rlib",
        srcs = ["some_rlib.rs"],
        edition = "2018",
    )

    analysis_test(
        name = name,
        target = ":" + name + "_some_rlib",
        impl = _libstd_panic_test_impl,
    )

def stdlib_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    test_suite(
        name = name,
        tests = [
            _libstd_ordering_test,
            _libstd_panic_test,
        ],
    )
