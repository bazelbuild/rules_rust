"""Rust WASM-bindgen rules for interfacing with aspect-build/rules_js"""

load("@aspect_rules_js//js:providers.bzl", "js_info")
load("//private:wasm_bindgen.bzl", "WASM_BINDGEN_ATTR", "rust_wasm_bindgen_action")

def _js_rust_wasm_bindgen_impl(ctx):
    toolchain = ctx.toolchains[Label("//:toolchain_type")]

    info = rust_wasm_bindgen_action(
        ctx = ctx,
        toolchain = toolchain,
        wasm_file = ctx.attr.wasm_file,
        target_output = ctx.attr.target,
        bindgen_flags = ctx.attr.bindgen_flags,
    )

    return [
        DefaultInfo(
            files = depset([info.wasm], transitive = [info.js, info.ts]),
        ),
        info,
        # Return a structure that is compatible with the deps[] of a ts_library.
        js_info(
            target = ctx.label,
            sources = info.js,
            transitive_sources = info.js,
            types = info.ts,
            transitive_types = info.ts,
        ),
    ]

js_rust_wasm_bindgen = rule(
    doc = """\
Generates javascript and typescript bindings for a webassembly module using [wasm-bindgen][ws] that interface with [aspect-build/rules_js][abjs].

[ws]: https://rustwasm.github.io/docs/wasm-bindgen/
[abjs]: https://github.com/aspect-build/rules_js
""",
    implementation = _js_rust_wasm_bindgen_impl,
    attrs = WASM_BINDGEN_ATTR,
    toolchains = [
        str(Label("//:toolchain_type")),
    ],
)
