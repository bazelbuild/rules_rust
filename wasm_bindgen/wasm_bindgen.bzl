# Copyright 2019 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# buildifier: disable=module-docstring
load("@io_bazel_rules_rust//rust:private/transitions.bzl", "wasm_bindgen_transition")

def _rust_wasm_bindgen_impl(ctx):
    toolchain = ctx.toolchains["@io_bazel_rules_rust//wasm_bindgen:wasm_bindgen_toolchain"]
    bindgen_bin = toolchain.bindgen

    args = ctx.actions.args()
    args.add("--out-dir", ctx.outputs.bindgen_wasm_module.dirname)
    args.add("--out-name", ctx.attr.name)
    args.add_all(ctx.attr.bindgen_flags)
    args.add(ctx.file.wasm_file)

    ctx.actions.run(
        executable = bindgen_bin,
        inputs = [ctx.file.wasm_file],
        outputs = [
            ctx.outputs.bindgen_javascript_bindings,
            ctx.outputs.bindgen_typescript_bindings,
            ctx.outputs.bindgen_wasm_module,
            ctx.outputs.javascript_bindings,
            ctx.outputs.typescript_bindings,
        ],
        mnemonic = "RustWasmBindgen",
        progress_message = "Generating WebAssembly bindings for {}..".format(ctx.file.wasm_file.path),
        arguments = [args],
    )

    # TODO (bazelbuild/rules_rust#443): Legacy provider syntax should be updated. See the following guide:
    # https://docs.bazel.build/versions/master/skylark/rules.html#migrating-from-legacy-providers
    # buildifier: disable=rule-impl-return
    return struct(
        providers = [
            DefaultInfo(
                files = depset([
                    ctx.outputs.bindgen_javascript_bindings,
                    ctx.outputs.bindgen_typescript_bindings,
                    ctx.outputs.bindgen_wasm_module,
                    ctx.outputs.javascript_bindings,
                    ctx.outputs.typescript_bindings,
                ]),
            ),
        ],
        typescript = struct(
            declarations = depset([
                ctx.outputs.typescript_bindings,
                ctx.outputs.bindgen_typescript_bindings,
            ]),
            transitive_declarations = depset([
                ctx.outputs.typescript_bindings,
                ctx.outputs.bindgen_typescript_bindings,
            ]),
            type_blacklisted_declarations = depset(),
            es5_sources = depset([
                ctx.outputs.bindgen_javascript_bindings,
                ctx.outputs.javascript_bindings,
            ]),
            es6_sources = depset([
                ctx.outputs.bindgen_javascript_bindings,
                ctx.outputs.javascript_bindings,
            ]),
            transitive_es5_sources = depset([
                ctx.outputs.bindgen_javascript_bindings,
                ctx.outputs.javascript_bindings,
            ]),
            transitive_es6_sources = depset([
                ctx.outputs.bindgen_javascript_bindings,
                ctx.outputs.javascript_bindings,
            ]),
        ),
    )

rust_wasm_bindgen = rule(
    implementation = _rust_wasm_bindgen_impl,
    doc = "Generates javascript and typescript bindings for a webassembly module.",
    attrs = {
        "wasm_file": attr.label(
            doc = "The .wasm file to generate bindings for.",
            allow_single_file = True,
            cfg = wasm_bindgen_transition,
        ),
        "bindgen_flags": attr.string_list(
            doc = "Flags to pass directly to the bindgen executable. See https://github.com/rustwasm/wasm-bindgen/ for details.",
        ),
        "_whitelist_function_transition": attr.label(
            default = "//tools/whitelists/function_transition_whitelist",
        ),
    },
    outputs = {
        "bindgen_javascript_bindings": "%{name}_bg.js",
        "bindgen_typescript_bindings": "%{name}_bg.wasm.d.ts",
        "bindgen_wasm_module": "%{name}_bg.wasm",
        "javascript_bindings": "%{name}.js",
        "typescript_bindings": "%{name}.d.ts",
    },
    toolchains = [
        "@io_bazel_rules_rust//wasm_bindgen:wasm_bindgen_toolchain",
    ],
)

def _rust_wasm_bindgen_toolchain_impl(ctx):
    return platform_common.ToolchainInfo(
        bindgen = ctx.executable.bindgen,
    )

rust_wasm_bindgen_toolchain = rule(
    implementation = _rust_wasm_bindgen_toolchain_impl,
    doc = "The tools required for the `rust_wasm_bindgen` rule.",
    attrs = {
        "bindgen": attr.label(
            doc = "The label of a `wasm-bindgen` executable.",
            executable = True,
            cfg = "exec",
        ),
    },
)
