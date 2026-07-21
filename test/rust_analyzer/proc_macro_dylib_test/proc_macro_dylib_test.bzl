"""Regression test: find_proc_macro_dylib must key off exec_triple.

Proc-macros are loaded by the host rust-analyzer process, so the dylib
extension used to locate the compiled artifact must match the exec platform,
not the target — otherwise a cross-compile spec points at an unloadable
artifact (e.g. `.wasm` or `.dll` on a Linux host).
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

# buildifier: disable=bzl-visibility
load("@rules_rust//rust/private:rust_analyzer.bzl", "find_proc_macro_dylib")

_ProcMacroDylibProbeInfo = provider(
    doc = "Captures find_proc_macro_dylib results across mock exec triples.",
    fields = ["by_system"],
)

def _probe_aspect_impl(target, ctx):
    if ctx.rule.kind != "rust_proc_macro":
        return []

    # Pairwise-distinct dylib extensions: .so / .dylib / .dll / .wasm.
    by_system = {
        system: find_proc_macro_dylib(
            struct(exec_triple = struct(system = system)),
            target,
        )
        for system in ["linux", "macos", "windows", "wasi"]
    }
    return [_ProcMacroDylibProbeInfo(by_system = by_system)]

_probe_aspect = aspect(implementation = _probe_aspect_impl)

def _exec_triple_selects_dylib_impl(ctx):
    env = analysistest.begin(ctx)
    probe = analysistest.target_under_test(env)[_ProcMacroDylibProbeInfo]

    hits = [s for s, d in probe.by_system.items() if d != None]
    asserts.equals(
        env,
        1,
        len(hits),
        "Expected exactly one exec_triple.system to find the host proc-macro dylib; got {}".format(probe.by_system),
    )
    return analysistest.end(env)

exec_triple_selects_dylib_test = analysistest.make(
    _exec_triple_selects_dylib_impl,
    extra_target_under_test_aspects = [_probe_aspect],
)
