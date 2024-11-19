"""Rust WASM-bindgen rules for interfacing with bazelbuild/rules_nodejs"""

load("@rules_nodejs//nodejs:providers.bzl", "DeclarationInfo", "JSModuleInfo")
load("//wasm_bindgen/private:wasm_bindgen.bzl", "WASM_BINDGEN_ATTR", "rust_wasm_bindgen_action")

def _nodejs_rust_wasm_bindgen_impl(ctx):
    toolchain = ctx.toolchains[Label("//wasm_bindgen:toolchain_type")]

    info = rust_wasm_bindgen_action(
        ctx = ctx,
        toolchain = toolchain,
        wasm_file = ctx.attr.wasm_file,
        target_output = ctx.attr.target,
        bindgen_flags = ctx.attr.bindgen_flags,
    )

    # Return a structure that is compatible with the deps[] of a ts_library.
    declarations = info.ts
    es5_sources = info.js

    return [
        DefaultInfo(
            files = depset([info.wasm], transitive = [info.js, info.ts]),
        ),
        DeclarationInfo(
            declarations = declarations,
            transitive_declarations = declarations,
            type_blocklisted_declarations = depset([]),
        ),
        JSModuleInfo(
            direct_sources = es5_sources,
            sources = es5_sources,
        ),
        info,
    ]

nodejs_rust_wasm_bindgen = rule(
    doc = """\
Generates javascript and typescript bindings for a webassembly module using [wasm-bindgen][ws] that interface with [bazelbuild/rules_nodejs][bbnjs].

[ws]: https://rustwasm.github.io/docs/wasm-bindgen/
[bbnjs]: https://github.com/bazelbuild/rules_nodejs

An example of this rule in use can be seen at [@rules_rust//examples/wasm_bindgen/rules_js](../examples/wasm_bindgen/rules_js)
""",
    implementation = _nodejs_rust_wasm_bindgen_impl,
    attrs = WASM_BINDGEN_ATTR,
    toolchains = [
        str(Label("//wasm_bindgen:toolchain_type")),
    ],
)
