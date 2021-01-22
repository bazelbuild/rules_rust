# Rust rules
* [rust_wasm_bindgen_repositories](#rust_wasm_bindgen_repositories)
* [rust_wasm_bindgen_toolchain](#rust_wasm_bindgen_toolchain)
* [rust_wasm_bindgen](#rust_wasm_bindgen)

<a id="#rust_wasm_bindgen"></a>

## rust_wasm_bindgen

<pre>
rust_wasm_bindgen(<a href="#rust_wasm_bindgen-name">name</a>, <a href="#rust_wasm_bindgen-bindgen_flags">bindgen_flags</a>, <a href="#rust_wasm_bindgen-wasm_file">wasm_file</a>)
</pre>

Generates javascript and typescript bindings for a webassembly module.

To use the Rust WebAssembly bindgen rules, add the following to your `WORKSPACE` file to add the
external repositories for the Rust bindgen toolchain (in addition to the Rust rules setup):

```python
load("@rules_rust//wasm_bindgen:repositories.bzl", "rust_wasm_bindgen_repositories")

rust_wasm_bindgen_repositories()
```

An example of this rule in use can be seen at [@rules_rust//examples/wasm/...](../examples/wasm)


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

You can also use your own version of wasm-bindgen using the toolchain rules below:

```python
load("@rules_rust//bindgen:bindgen.bzl", "rust_bindgen_toolchain")

rust_bindgen_toolchain(
    bindgen = "//my/raze:cargo_bin_wasm_bindgen",
)

toolchain(
    name = "wasm-bindgen-toolchain",
    toolchain = "wasm-bindgen-toolchain-impl",
    toolchain_type = "@rules_rust//wasm_bindgen:wasm_bindgen_toolchain",
)
```

Now that you have your own toolchain, you need to register it by
inserting the following statement in your `WORKSPACE` file:

```python
register_toolchains("//my/toolchains:wasm-bindgen-toolchain")
```

For additional information, see the [Bazel toolchains documentation](https://docs.bazel.build/versions/master/toolchains.html).


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_wasm_bindgen_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_wasm_bindgen_toolchain-bindgen"></a>bindgen |  The label of a <code>wasm-bindgen</code> executable.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="#rust_wasm_bindgen_repositories"></a>

## rust_wasm_bindgen_repositories

<pre>
rust_wasm_bindgen_repositories()
</pre>

Declare dependencies needed for wasm-bindgen.

This macro will load crate dependencies of `wasm-bindgen` that are generated using [cargo raze][raze] inside the rules_rust     repository. This makes the default toolchain `@rules_rust//wasm_bindgen:default_wasm_bindgen_toolchain` available. For     more information on `wasm_bindgen` toolchains, see [rust_wasm_bindgen_toolchain](#rust_wasm_bindgen_toolchain).



