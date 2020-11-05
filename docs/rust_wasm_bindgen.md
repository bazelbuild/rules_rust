# Rust rules
* [rust_wasm_bindgen_toolchain](#rust_wasm_bindgen_toolchain)
* [rust_wasm_bindgen](#rust_wasm_bindgen)

<a id="#rust_wasm_bindgen"></a>

## rust_wasm_bindgen

<pre>
rust_wasm_bindgen(<a href="#rust_wasm_bindgen-name">name</a>, <a href="#rust_wasm_bindgen-bindgen_flags">bindgen_flags</a>, <a href="#rust_wasm_bindgen-wasm_file">wasm_file</a>)
</pre>

Generates javascript and typescript bindings for a webassembly module.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_wasm_bindgen-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_wasm_bindgen-bindgen_flags"></a>bindgen_flags |  Flags to pass directly to the bindgen executable. See https://github.com/rustwasm/wasm-bindgen/ for details.   | List of strings | optional | [] |
| <a id="rust_wasm_bindgen-wasm_file"></a>wasm_file |  The .wasm file to generate bindings for.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="#rust_wasm_bindgen_toolchain"></a>

## rust_wasm_bindgen_toolchain

<pre>
rust_wasm_bindgen_toolchain(<a href="#rust_wasm_bindgen_toolchain-name">name</a>, <a href="#rust_wasm_bindgen_toolchain-bindgen">bindgen</a>)
</pre>

The tools required for the `rust_wasm_bindgen` rule.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_wasm_bindgen_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_wasm_bindgen_toolchain-bindgen"></a>bindgen |  The label of a <code>wasm-bindgen</code> executable.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


