<!-- Generated with Stardoc: http://skydoc.bazel.build -->
# Rust Bindgen

* [rust_bindgen_library](#rust_bindgen_library)
* [rust_bindgen_repositories](#rust_bindgen_repositories)
* [rust_bindgen_toolchain](#rust_bindgen_toolchain)
* [rust_bindgen](#rust_bindgen)

<a id="#rust_bindgen"></a>

## rust_bindgen

<pre>
rust_bindgen(<a href="#rust_bindgen-name">name</a>, <a href="#rust_bindgen-bindgen_flags">bindgen_flags</a>, <a href="#rust_bindgen-cc_lib">cc_lib</a>, <a href="#rust_bindgen-clang_flags">clang_flags</a>, <a href="#rust_bindgen-header">header</a>)
</pre>

Generates a rust source file from a cc_library and a header.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_bindgen-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_bindgen-bindgen_flags"></a>bindgen_flags |  Flags to pass directly to the bindgen executable. See https://rust-lang.github.io/rust-bindgen/ for details.   | List of strings | optional | [] |
| <a id="rust_bindgen-cc_lib"></a>cc_lib |  The cc_library that contains the .h file. This is used to find the transitive includes.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_bindgen-clang_flags"></a>clang_flags |  Flags to pass directly to the clang executable.   | List of strings | optional | [] |
| <a id="rust_bindgen-header"></a>header |  The .h file to generate bindings for.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="#rust_bindgen_toolchain"></a>

## rust_bindgen_toolchain

<pre>
rust_bindgen_toolchain(<a href="#rust_bindgen_toolchain-name">name</a>, <a href="#rust_bindgen_toolchain-bindgen">bindgen</a>, <a href="#rust_bindgen_toolchain-clang">clang</a>, <a href="#rust_bindgen_toolchain-libclang">libclang</a>, <a href="#rust_bindgen_toolchain-libstdcxx">libstdcxx</a>, <a href="#rust_bindgen_toolchain-rustfmt">rustfmt</a>)
</pre>

The tools required for the `rust_bindgen` rule.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_bindgen_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_bindgen_toolchain-bindgen"></a>bindgen |  The label of a <code>bindgen</code> executable.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_bindgen_toolchain-clang"></a>clang |  The label of a <code>clang</code> executable.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_bindgen_toolchain-libclang"></a>libclang |  A cc_library that provides bindgen's runtime dependency on libclang.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_bindgen_toolchain-libstdcxx"></a>libstdcxx |  A cc_library that satisfies libclang's libstdc++ dependency.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_bindgen_toolchain-rustfmt"></a>rustfmt |  The label of a <code>rustfmt</code> executable. If this is provided, generated sources will be formatted.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="#rust_bindgen_library"></a>

## rust_bindgen_library

<pre>
rust_bindgen_library(<a href="#rust_bindgen_library-name">name</a>, <a href="#rust_bindgen_library-header">header</a>, <a href="#rust_bindgen_library-cc_lib">cc_lib</a>, <a href="#rust_bindgen_library-bindgen_flags">bindgen_flags</a>, <a href="#rust_bindgen_library-clang_flags">clang_flags</a>, <a href="#rust_bindgen_library-kwargs">kwargs</a>)
</pre>

Generates a rust source file for `header`, and builds a rust_library.

Arguments are the same as `rust_bindgen`, and `kwargs` are passed directly to rust_library.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rust_bindgen_library-name"></a>name |  A unique name for this target.   |  none |
| <a id="rust_bindgen_library-header"></a>header |  The label of the .h file to generate bindings for.   |  none |
| <a id="rust_bindgen_library-cc_lib"></a>cc_lib |  The label of the cc_library that contains the .h file. This is used to find the transitive includes.   |  none |
| <a id="rust_bindgen_library-bindgen_flags"></a>bindgen_flags |  Flags to pass directly to the bindgen executable. See https://rust-lang.github.io/rust-bindgen/ for details.   |  <code>None</code> |
| <a id="rust_bindgen_library-clang_flags"></a>clang_flags |  Flags to pass directly to the clang executable.   |  <code>None</code> |
| <a id="rust_bindgen_library-kwargs"></a>kwargs |  Arguments to forward to the underlying <code>rust_library</code> rule.   |  none |


<a id="#rust_bindgen_repositories"></a>

## rust_bindgen_repositories

<pre>
rust_bindgen_repositories()
</pre>

Declare dependencies needed for bindgen.



