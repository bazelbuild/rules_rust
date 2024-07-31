"""Bazel rules for [wasm-bindgen](https://crates.io/crates/wasm-bindgen)"""

load("//rust:defs.bzl", "rust_common")
load("//wasm_bindgen:providers.bzl", "RustWasmBindgenInfo")
load("//wasm_bindgen/private:transitions.bzl", "wasm_bindgen_transition")

def rust_wasm_bindgen_action(ctx, toolchain, wasm_file, target_output, bindgen_flags = []):
    """Spawn a `RustWasmBindgen` action.

    Args:
        ctx (ctx): _description_
        toolchain (ToolchainInfo): _description_
        wasm_file (Target): _description_
        target_output (str): _description_
        bindgen_flags (list, optional): _description_. Defaults to [].

    Returns:
        RustWasmBindgenInfo: _description_
    """
    bindgen_bin = toolchain.bindgen

    # Since the `wasm_file` attribute is behind a transition, it will be converted
    # to a list.
    if len(wasm_file) == 1:
        if rust_common.crate_info in wasm_file[0]:
            target = wasm_file[0]
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
            wasm_files = wasm_file[0][DefaultInfo].files.to_list()
            if len(wasm_files) != 1:
                fail("Unexpected number of wasm files: {}".format(wasm_files))

            progress_message_label = wasm_files[0].path
            input_file = wasm_files[0]
    else:
        fail("wasm_file is expected to be a transitioned label attr on `{}`. Got `{}`".format(
            ctx.label,
            wasm_file,
        ))

    bindgen_wasm_module = ctx.actions.declare_file(ctx.label.name + "_bg.wasm")

    js_out = [ctx.actions.declare_file(ctx.label.name + ".js")]
    ts_out = []
    if not "--no-typescript" in bindgen_flags:
        ts_out.append(ctx.actions.declare_file(ctx.label.name + ".d.ts"))

    if target_output == "bundler":
        js_out.append(ctx.actions.declare_file(ctx.label.name + "_bg.js"))
        if not "--no-typescript" in bindgen_flags:
            ts_out.append(ctx.actions.declare_file(ctx.label.name + "_bg.wasm.d.ts"))

    outputs = [bindgen_wasm_module] + js_out + ts_out

    args = ctx.actions.args()
    args.add("--target", target_output)
    args.add("--out-dir", bindgen_wasm_module.dirname)
    args.add("--out-name", ctx.label.name)
    args.add_all(bindgen_flags)
    args.add(input_file)

    ctx.actions.run(
        executable = bindgen_bin,
        inputs = [input_file],
        outputs = outputs,
        mnemonic = "RustWasmBindgen",
        progress_message = "Generating WebAssembly bindings for {}...".format(progress_message_label),
        arguments = [args],
    )

    return RustWasmBindgenInfo(
        wasm = bindgen_wasm_module,
        js = depset(js_out),
        ts = depset(ts_out),
    )

def _rust_wasm_bindgen_impl(ctx):
    toolchain = ctx.toolchains[Label("//wasm_bindgen:toolchain_type")]

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
    ]

WASM_BINDGEN_ATTR = {
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
}

rust_wasm_bindgen = rule(
    implementation = _rust_wasm_bindgen_impl,
    doc = """\
Generates javascript and typescript bindings for a webassembly module using [wasm-bindgen][ws].

[ws]: https://rustwasm.github.io/docs/wasm-bindgen/

An example of this rule in use can be seen at [@rules_rust//examples/wasm](../examples/wasm)
""",
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
        str(Label("//wasm_bindgen:toolchain_type")),
    ],
)

def _rust_wasm_bindgen_toolchain_impl(ctx):
    return platform_common.ToolchainInfo(
        bindgen = ctx.executable.bindgen,
    )

rust_wasm_bindgen_toolchain = rule(
    implementation = _rust_wasm_bindgen_toolchain_impl,
    doc = """\
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
""",
    attrs = {
        "bindgen": attr.label(
            doc = "The label of a `wasm-bindgen-cli` executable.",
            executable = True,
            cfg = "exec",
        ),
    },
)
