<!-- Generated with Stardoc: http://skydoc.bazel.build -->
# Rust Wasm Bindgen

* [rust_wasm_bindgen_dependencies](#rust_wasm_bindgen_dependencies)
* [rust_wasm_bindgen_register_toolchains](#rust_wasm_bindgen_register_toolchains)
* [rust_wasm_bindgen_toolchain](#rust_wasm_bindgen_toolchain)
* [rust_wasm_bindgen](#rust_wasm_bindgen)


## Overview

To build a `rust_binary` for `wasm32-unknown-unknown` target add the `--platforms=@rules_rust//rust/platform:wasm` flag.

```command
bazel build @examples//hello_world_wasm --platforms=@rules_rust//rust/platform:wasm
```

To build a `rust_binary` for `wasm32-wasi` target add the `--platforms=@rules_rust//rust/platform:wasi` flag.

```command
bazel build @examples//hello_world_wasm --platforms=@rules_rust//rust/platform:wasi
```

`rust_wasm_bindgen` will automatically transition to the `wasm` platform and can be used when
building WebAssembly code for the host target.


<a id="rust_wasm_bindgen"></a>

## rust_wasm_bindgen

<pre>
rust_wasm_bindgen(<a href="#rust_wasm_bindgen-name">name</a>, <a href="#rust_wasm_bindgen-bindgen_flags">bindgen_flags</a>, <a href="#rust_wasm_bindgen-target">target</a>, <a href="#rust_wasm_bindgen-wasm_file">wasm_file</a>)
</pre>

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


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_wasm_bindgen-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="rust_wasm_bindgen-bindgen_flags"></a>bindgen_flags |  Flags to pass directly to the bindgen executable. See https://github.com/rustwasm/wasm-bindgen/ for details.   | List of strings | optional | <code>[]</code> |
| <a id="rust_wasm_bindgen-target"></a>target |  The type of output to generate. See https://rustwasm.github.io/wasm-bindgen/reference/deployment.html for details.   | String | optional | <code>"bundler"</code> |
| <a id="rust_wasm_bindgen-wasm_file"></a>wasm_file |  The <code>.wasm</code> file or crate to generate bindings for.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


<a id="rust_wasm_bindgen_toolchain"></a>

## rust_wasm_bindgen_toolchain

<pre>
rust_wasm_bindgen_toolchain(<a href="#rust_wasm_bindgen_toolchain-name">name</a>, <a href="#rust_wasm_bindgen_toolchain-bindgen">bindgen</a>)
</pre>

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


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_wasm_bindgen_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="rust_wasm_bindgen_toolchain-bindgen"></a>bindgen |  The label of a <code>wasm-bindgen-cli</code> executable.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | <code>None</code> |


<a id="rust_wasm_bindgen_dependencies"></a>

## rust_wasm_bindgen_dependencies

<pre>
rust_wasm_bindgen_dependencies()
</pre>

Declare dependencies needed for the `rules_rust` [wasm-bindgen][wb] rules.

[wb]: https://github.com/rustwasm/wasm-bindgen



<a id="rust_wasm_bindgen_register_toolchains"></a>

## rust_wasm_bindgen_register_toolchains

<pre>
rust_wasm_bindgen_register_toolchains(<a href="#rust_wasm_bindgen_register_toolchains-register_toolchains">register_toolchains</a>)
</pre>

Registers the default toolchains for the `rules_rust` [wasm-bindgen][wb] rules.

[wb]: https://github.com/rustwasm/wasm-bindgen


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rust_wasm_bindgen_register_toolchains-register_toolchains"></a>register_toolchains |  Whether or not to register toolchains.   |  `True` |


