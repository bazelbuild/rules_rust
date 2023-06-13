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

"""Bazel rules for [wasm-bindgen](https://crates.io/crates/wasm-bindgen)"""

load("//rust:defs.bzl", "rust_common")
load(
    "//wasm_bindgen:providers.bzl",
    "DeclarationInfo",
    "JSModuleInfo",
)
load("//wasm_bindgen/private:transitions.bzl", "wasm_bindgen_transition")

_WASM_BINDGEN_DOC = """\
Generates javascript and typescript bindings for a webassembly module using [wasm-bindgen][ws].

[ws]: https://rustwasm.github.io/docs/wasm-bindgen/

To use the Rust WebAssembly bindgen rules, add the following to your `WORKSPACE` file to add the
external repositories for the Rust bindgen toolchain (in addition to the Rust rules setup):

```python
load("@rules_rust//wasm_bindgen:repositories.bzl", "rust_wasm_bindgen_repositories")

rust_wasm_bindgen_repositories()
```

For more details on `rust_wasm_bindgen_repositories`, see [here](#rust_wasm_bindgen_repositories).

An example of this rule in use can be seen at [@rules_rust//examples/wasm](../examples/wasm)
"""

_WASM_BINDGEN_TOOLCHAIN_DOC = """\
The tools required for the `rust_wasm_bindgen` rule.

In cases where users want to control or change the version of `wasm-bindgen` used by [rust_wasm_bindgen](#rust_wasm_bindgen),
a unique toolchain can be created as in the example below:

```python
load("@rules_rust//bindgen:bindgen.bzl", "rust_bindgen_toolchain")

rust_bindgen_toolchain(
    bindgen = "//3rdparty/crates:wasm_bindgen_cli__bin",
)

toolchain(
    name = "wasm_bindgen_toolchain",
    toolchain = "wasm_bindgen_toolchain_impl",
    toolchain_type = "@rules_rust//wasm_bindgen:toolchain_type",
)
```

Now that you have your own toolchain, you need to register it by
inserting the following statement in your `WORKSPACE` file:

```python
register_toolchains("//my/toolchains:wasm_bindgen_toolchain")
```

For additional information, see the [Bazel toolchains documentation][toolchains].

[toolchains]: https://docs.bazel.build/versions/master/toolchains.html
"""

def _rust_wasm_bindgen_impl(ctx):
    toolchain = ctx.toolchains[Label("//wasm_bindgen:wasm_bindgen_toolchain")]
    bindgen_bin = toolchain.bindgen

    # Since the `wasm_file` attribute is behind a transition, it will be converted
    # to a list.
    if len(ctx.attr.wasm_file) == 1 and rust_common.crate_info in ctx.attr.wasm_file[0]:
        target = ctx.attr.wasm_file[0]
        crate_info = target[rust_common.crate_info]

        # Provide a helpful warning informing users how to use the rule
        if rust_common.crate_info in target:
            supported_types = ["cdylib", "bin"]
            if crate_info.type not in supported_types:
                fail("The target '{}' is not a supported type: {}".format(
                    ctx.attr.crate.label,
                    supported_types,
                ))

        progress_message_label = target.label
        input_file = crate_info.output
    else:
        progress_message_label = ctx.file.wasm_file.path
        input_file = ctx.file.wasm_file

    bindgen_wasm_module = ctx.actions.declare_file(ctx.attr.name + "_bg.wasm")

    js_out = [ctx.actions.declare_file(ctx.attr.name + ".js")]
    ts_out = [ctx.actions.declare_file(ctx.attr.name + ".d.ts")]

    if ctx.attr.target == "bundler":
        js_out.append(ctx.actions.declare_file(ctx.attr.name + "_bg.js"))
        ts_out.append(ctx.actions.declare_file(ctx.attr.name + "_bg.wasm.d.ts"))

    outputs = [bindgen_wasm_module] + js_out + ts_out

    args = ctx.actions.args()
    args.add("--target", ctx.attr.target)
    args.add("--out-dir", bindgen_wasm_module.dirname)
    args.add("--out-name", ctx.attr.name)
    args.add_all(ctx.attr.bindgen_flags)
    args.add(input_file)

    ctx.actions.run(
        executable = bindgen_bin,
        inputs = [input_file],
        outputs = outputs,
        mnemonic = "RustWasmBindgen",
        progress_message = "Generating WebAssembly bindings for {}...".format(progress_message_label),
        arguments = [args],
    )

    # Return a structure that is compatible with the deps[] of a ts_library.
    declarations = depset(ts_out)
    es5_sources = depset(js_out)

    return [
        DefaultInfo(
            files = depset(outputs),
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
    ]

rust_wasm_bindgen = rule(
    implementation = _rust_wasm_bindgen_impl,
    doc = _WASM_BINDGEN_DOC,
    attrs = {
        "bindgen_flags": attr.string_list(
            doc = "Flags to pass directly to the bindgen executable. See https://github.com/rustwasm/wasm-bindgen/ for details.",
        ),
        "target": attr.string(
            doc = "The type of output to generate. See https://rustwasm.github.io/wasm-bindgen/reference/deployment.html for details.",
            default = "bundler",
            values = ["web", "bundler", "nodejs", "no-modules", "deno"],
        ),
        "wasm_file": attr.label(
            doc = "The `.wasm` file or crate to generate bindings for.",
            allow_single_file = True,
            cfg = wasm_bindgen_transition,
            mandatory = True,
        ),
        "_allowlist_function_transition": attr.label(
            default = Label("//tools/allowlists/function_transition_allowlist"),
        ),
    },
    toolchains = [
        str(Label("//wasm_bindgen:wasm_bindgen_toolchain")),
    ],
    incompatible_use_toolchain_transition = True,
)

def _rust_wasm_bindgen_toolchain_impl(ctx):
    return platform_common.ToolchainInfo(
        bindgen = ctx.executable.bindgen,
    )

rust_wasm_bindgen_toolchain = rule(
    implementation = _rust_wasm_bindgen_toolchain_impl,
    doc = _WASM_BINDGEN_TOOLCHAIN_DOC,
    attrs = {
        "bindgen": attr.label(
            doc = "The label of a `wasm-bindgen-cli` executable.",
            executable = True,
            cfg = "exec",
        ),
    },
)
