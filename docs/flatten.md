# Rust rules

* [bazel_version](#bazel_version)
* [cargo_build_script](#cargo_build_script)
* [rust_benchmark](#rust_benchmark)
* [rust_binary](#rust_binary)
* [rust_bindgen](#rust_bindgen)
* [rust_bindgen_library](#rust_bindgen_library)
* [rust_bindgen_toolchain](#rust_bindgen_toolchain)
* [rust_doc](#rust_doc)
* [rust_doc_test](#rust_doc_test)
* [rust_grpc_library](#rust_grpc_library)
* [rust_library](#rust_library)
* [rust_proto_library](#rust_proto_library)
* [rust_proto_toolchain](#rust_proto_toolchain)
* [rust_repositories](#rust_repositories)
* [rust_repository_set](#rust_repository_set)
* [rust_test](#rust_test)
* [rust_toolchain](#rust_toolchain)
* [rust_toolchain_repository](#rust_toolchain_repository)
* [rust_toolchain_repository_proxy](#rust_toolchain_repository_proxy)
* [rust_wasm_bindgen](#rust_wasm_bindgen)
* [rust_wasm_bindgen_toolchain](#rust_wasm_bindgen_toolchain)
* [rust_workspace](#rust_workspace)


<a id="#rust_benchmark"></a>

## rust_benchmark

<pre>
rust_benchmark(<a href="#rust_benchmark-name">name</a>, <a href="#rust_benchmark-aliases">aliases</a>, <a href="#rust_benchmark-crate_features">crate_features</a>, <a href="#rust_benchmark-crate_root">crate_root</a>, <a href="#rust_benchmark-data">data</a>, <a href="#rust_benchmark-deps">deps</a>, <a href="#rust_benchmark-edition">edition</a>, <a href="#rust_benchmark-out_dir_tar">out_dir_tar</a>,
               <a href="#rust_benchmark-proc_macro_deps">proc_macro_deps</a>, <a href="#rust_benchmark-rustc_env">rustc_env</a>, <a href="#rust_benchmark-rustc_flags">rustc_flags</a>, <a href="#rust_benchmark-srcs">srcs</a>, <a href="#rust_benchmark-version">version</a>)
</pre>

Builds a Rust benchmark test.

**Warning**: This rule is currently experimental. [Rust Benchmark tests][rust-bench] require the `Bencher` interface in the unstable `libtest` crate, which is behind the `test` unstable feature gate. As a result, using this rule would require using a nightly binary release of Rust.

[rust-bench]: https://doc.rust-lang.org/book/benchmark-tests.html

Example:

Suppose you have the following directory structure for a Rust project with a library crate, `fibonacci` with benchmarks under the `benches/` directory:

```output
[workspace]/
  WORKSPACE
  fibonacci/
      BUILD
      src/
          lib.rs
      benches/
          fibonacci_bench.rs
```

`fibonacci/src/lib.rs`:
```rust
pub fn fibonacci(n: u64) -> u64 {
    if n < 2 {
        return n;
    }
    let mut n1: u64 = 0;
    let mut n2: u64 = 1;
    for _ in 1..n {
        let sum = n1 + n2;
        n1 = n2;
        n2 = sum;
    }
    n2
}
```

`fibonacci/benches/fibonacci_bench.rs`:
```rust
#![feature(test)]

extern crate test;
extern crate fibonacci;

use test::Bencher;

#[bench]
fn bench_fibonacci(b: &mut Bencher) {
    b.iter(|| fibonacci::fibonacci(40));
}
```

To build the benchmark test, add a `rust_benchmark` target:

`fibonacci/BUILD`:
```python
package(default_visibility = ["//visibility:public"])

load("@io_bazel_rules_rust//rust:rust.bzl", "rust_library", "rust_benchmark")

rust_library(
  name = "fibonacci",
  srcs = ["src/lib.rs"],
)

rust_benchmark(
  name = "fibonacci_bench",
  srcs = ["benches/fibonacci_bench.rs"],
  deps = [":fibonacci"],
)
```

Run the benchmark test using: `bazel run //fibonacci:fibonacci_bench`.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_benchmark-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_benchmark-aliases"></a>aliases |  Remap crates to a new name or moniker for linkage to this target<br><br>These are other <code>rust_library</code> targets and will be presented as the new name given.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: Label -> String</a> | optional | {} |
| <a id="rust_benchmark-crate_features"></a>crate_features |  List of features to enable for this crate.<br><br>Features are defined in the code using the <code>#[cfg(feature = "foo")]</code> configuration option. The features listed here will be passed to <code>rustc</code> with <code>--cfg feature="${feature_name}"</code> flags.   | List of strings | optional | [] |
| <a id="rust_benchmark-crate_root"></a>crate_root |  The file that will be passed to <code>rustc</code> to be used for building this crate.<br><br>If <code>crate_root</code> is not set, then this rule will look for a <code>lib.rs</code> file (or <code>main.rs</code> for rust_binary) or the single file in <code>srcs</code> if <code>srcs</code> contains only one file.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_benchmark-data"></a>data |  List of files used by this rule at runtime.<br><br>This attribute can be used to specify any data files that are embedded into the library, such as via the [<code>include_str!</code>](https://doc.rust-lang.org/std/macro.include_str!.html) macro.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="rust_benchmark-deps"></a>deps |  List of other libraries to be linked to this library target.<br><br>These can be either other <code>rust_library</code> targets or <code>cc_library</code> targets if linking a native library.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="rust_benchmark-edition"></a>edition |  The rust edition to use for this crate. Defaults to the edition specified in the rust_toolchain.   | String | optional | "" |
| <a id="rust_benchmark-out_dir_tar"></a>out_dir_tar |  __Deprecated__, do not use, see [#cargo_build_script] instead.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_benchmark-proc_macro_deps"></a>proc_macro_deps |  List of <code>rust_library</code> targets with kind <code>proc-macro</code> used to help build this library target.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="rust_benchmark-rustc_env"></a>rustc_env |  Dictionary of additional <code>"key": "value"</code> environment variables to set for rustc.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="rust_benchmark-rustc_flags"></a>rustc_flags |  List of compiler flags passed to <code>rustc</code>.   | List of strings | optional | [] |
| <a id="rust_benchmark-srcs"></a>srcs |  List of Rust <code>.rs</code> source files used to build the library.<br><br>If <code>srcs</code> contains more than one file, then there must be a file either named <code>lib.rs</code>. Otherwise, <code>crate_root</code> must be set to the source file that is the root of the crate to be passed to rustc to build this crate.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="rust_benchmark-version"></a>version |  A version to inject in the cargo environment variable.   | String | optional | "0.0.0" |


<a id="#rust_binary"></a>

## rust_binary

<pre>
rust_binary(<a href="#rust_binary-name">name</a>, <a href="#rust_binary-aliases">aliases</a>, <a href="#rust_binary-crate_features">crate_features</a>, <a href="#rust_binary-crate_root">crate_root</a>, <a href="#rust_binary-crate_type">crate_type</a>, <a href="#rust_binary-data">data</a>, <a href="#rust_binary-deps">deps</a>, <a href="#rust_binary-edition">edition</a>,
            <a href="#rust_binary-linker_script">linker_script</a>, <a href="#rust_binary-out_binary">out_binary</a>, <a href="#rust_binary-out_dir_tar">out_dir_tar</a>, <a href="#rust_binary-proc_macro_deps">proc_macro_deps</a>, <a href="#rust_binary-rustc_env">rustc_env</a>, <a href="#rust_binary-rustc_flags">rustc_flags</a>, <a href="#rust_binary-srcs">srcs</a>,
            <a href="#rust_binary-version">version</a>)
</pre>

Builds a Rust binary crate.

Example:

Suppose you have the following directory structure for a Rust project with a
library crate, `hello_lib`, and a binary crate, `hello_world` that uses the
`hello_lib` library:

```output
[workspace]/
    WORKSPACE
    hello_lib/
        BUILD
        src/
            lib.rs
    hello_world/
        BUILD
        src/
            main.rs
```

`hello_lib/src/lib.rs`:
```rust
pub struct Greeter {
    greeting: String,
}

impl Greeter {
    pub fn new(greeting: &str) -> Greeter {
        Greeter { greeting: greeting.to_string(), }
    }

    pub fn greet(&self, thing: &str) {
        println!("{} {}", &self.greeting, thing);
    }
}
```

`hello_lib/BUILD`:
```python
package(default_visibility = ["//visibility:public"])

load("@io_bazel_rules_rust//rust:rust.bzl", "rust_library")

rust_library(
    name = "hello_lib",
    srcs = ["src/lib.rs"],
)
```

`hello_world/src/main.rs`:
```rust
extern crate hello_lib;

fn main() {
    let hello = hello_lib::Greeter::new("Hello");
    hello.greet("world");
}
```

`hello_world/BUILD`:
```python
load("@io_bazel_rules_rust//rust:rust.bzl", "rust_binary")

rust_binary(
    name = "hello_world",
    srcs = ["src/main.rs"],
    deps = ["//hello_lib"],
)
```

Build and run `hello_world`:
```
$ bazel run //hello_world
INFO: Found 1 target...
Target //examples/rust/hello_world:hello_world up-to-date:
  bazel-bin/examples/rust/hello_world/hello_world
INFO: Elapsed time: 1.308s, Critical Path: 1.22s

INFO: Running command line: bazel-bin/examples/rust/hello_world/hello_world
Hello world
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_binary-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_binary-aliases"></a>aliases |  Remap crates to a new name or moniker for linkage to this target<br><br>These are other <code>rust_library</code> targets and will be presented as the new name given.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: Label -> String</a> | optional | {} |
| <a id="rust_binary-crate_features"></a>crate_features |  List of features to enable for this crate.<br><br>Features are defined in the code using the <code>#[cfg(feature = "foo")]</code> configuration option. The features listed here will be passed to <code>rustc</code> with <code>--cfg feature="${feature_name}"</code> flags.   | List of strings | optional | [] |
| <a id="rust_binary-crate_root"></a>crate_root |  The file that will be passed to <code>rustc</code> to be used for building this crate.<br><br>If <code>crate_root</code> is not set, then this rule will look for a <code>lib.rs</code> file (or <code>main.rs</code> for rust_binary) or the single file in <code>srcs</code> if <code>srcs</code> contains only one file.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_binary-crate_type"></a>crate_type |  -   | String | optional | "bin" |
| <a id="rust_binary-data"></a>data |  List of files used by this rule at runtime.<br><br>This attribute can be used to specify any data files that are embedded into the library, such as via the [<code>include_str!</code>](https://doc.rust-lang.org/std/macro.include_str!.html) macro.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="rust_binary-deps"></a>deps |  List of other libraries to be linked to this library target.<br><br>These can be either other <code>rust_library</code> targets or <code>cc_library</code> targets if linking a native library.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="rust_binary-edition"></a>edition |  The rust edition to use for this crate. Defaults to the edition specified in the rust_toolchain.   | String | optional | "" |
| <a id="rust_binary-linker_script"></a>linker_script |  Link script to forward into linker via rustc options.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_binary-out_binary"></a>out_binary |  -   | Boolean | optional | False |
| <a id="rust_binary-out_dir_tar"></a>out_dir_tar |  __Deprecated__, do not use, see [#cargo_build_script] instead.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_binary-proc_macro_deps"></a>proc_macro_deps |  List of <code>rust_library</code> targets with kind <code>proc-macro</code> used to help build this library target.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="rust_binary-rustc_env"></a>rustc_env |  Dictionary of additional <code>"key": "value"</code> environment variables to set for rustc.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="rust_binary-rustc_flags"></a>rustc_flags |  List of compiler flags passed to <code>rustc</code>.   | List of strings | optional | [] |
| <a id="rust_binary-srcs"></a>srcs |  List of Rust <code>.rs</code> source files used to build the library.<br><br>If <code>srcs</code> contains more than one file, then there must be a file either named <code>lib.rs</code>. Otherwise, <code>crate_root</code> must be set to the source file that is the root of the crate to be passed to rustc to build this crate.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="rust_binary-version"></a>version |  A version to inject in the cargo environment variable.   | String | optional | "0.0.0" |


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


<a id="#rust_doc"></a>

## rust_doc

<pre>
rust_doc(<a href="#rust_doc-name">name</a>, <a href="#rust_doc-dep">dep</a>, <a href="#rust_doc-html_after_content">html_after_content</a>, <a href="#rust_doc-html_before_content">html_before_content</a>, <a href="#rust_doc-html_in_header">html_in_header</a>, <a href="#rust_doc-markdown_css">markdown_css</a>)
</pre>

Generates code documentation.

Example:
  Suppose you have the following directory structure for a Rust library crate:

  ```
  [workspace]/
      WORKSPACE
      hello_lib/
          BUILD
          src/
              lib.rs
  ```

  To build [`rustdoc`][rustdoc] documentation for the `hello_lib` crate, define   a `rust_doc` rule that depends on the the `hello_lib` `rust_library` target:

  [rustdoc]: https://doc.rust-lang.org/book/documentation.html

  ```python
  package(default_visibility = ["//visibility:public"])

  load("@io_bazel_rules_rust//rust:rust.bzl", "rust_library", "rust_doc")

  rust_library(
      name = "hello_lib",
      srcs = ["src/lib.rs"],
  )

  rust_doc(
      name = "hello_lib_doc",
      dep = ":hello_lib",
  )
  ```

  Running `bazel build //hello_lib:hello_lib_doc` will build a zip file containing   the documentation for the `hello_lib` library crate generated by `rustdoc`.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_doc-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_doc-dep"></a>dep |  The label of the target to generate code documentation for.<br><br><code>rust_doc</code> can generate HTML code documentation for the source files of <code>rust_library</code> or <code>rust_binary</code> targets.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="rust_doc-html_after_content"></a>html_after_content |  File to add in <code>&lt;body&gt;</code>, after content.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_doc-html_before_content"></a>html_before_content |  File to add in <code>&lt;body&gt;</code>, before content.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_doc-html_in_header"></a>html_in_header |  File to add to <code>&lt;head&gt;</code>.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_doc-markdown_css"></a>markdown_css |  CSS files to include via <code>&lt;link&gt;</code> in a rendered Markdown file.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |


<a id="#rust_doc_test"></a>

## rust_doc_test

<pre>
rust_doc_test(<a href="#rust_doc_test-name">name</a>, <a href="#rust_doc_test-dep">dep</a>)
</pre>

Runs Rust documentation tests.

Example:

Suppose you have the following directory structure for a Rust library crate:

```output
[workspace]/
  WORKSPACE
  hello_lib/
      BUILD
      src/
          lib.rs
```

To run [documentation tests][doc-test] for the `hello_lib` crate, define a `rust_doc_test` target that depends on the `hello_lib` `rust_library` target:

[doc-test]: https://doc.rust-lang.org/book/documentation.html#documentation-as-tests

```python
package(default_visibility = ["//visibility:public"])

load("@io_bazel_rules_rust//rust:rust.bzl", "rust_library", "rust_doc_test")

rust_library(
    name = "hello_lib",
    srcs = ["src/lib.rs"],
)

rust_doc_test(
    name = "hello_lib_doc_test",
    dep = ":hello_lib",
)
```

Running `bazel test //hello_lib:hello_lib_doc_test` will run all documentation tests for the `hello_lib` library crate.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_doc_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_doc_test-dep"></a>dep |  The label of the target to run documentation tests for.<br><br><code>rust_doc_test</code> can run documentation tests for the source files of <code>rust_library</code> or <code>rust_binary</code> targets.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |


<a id="#rust_grpc_library"></a>

## rust_grpc_library

<pre>
rust_grpc_library(<a href="#rust_grpc_library-name">name</a>, <a href="#rust_grpc_library-deps">deps</a>, <a href="#rust_grpc_library-rust_deps">rust_deps</a>)
</pre>

Builds a Rust library crate from a set of `proto_library`s suitable for gRPC.

Example:

```python
load("@io_bazel_rules_rust//proto:proto.bzl", "rust_grpc_library")
load("@io_bazel_rules_rust//proto:toolchain.bzl", "GRPC_COMPILE_DEPS")

proto_library(
    name = "my_proto",
    srcs = ["my.proto"]
)

rust_grpc_library(
    name = "rust",
    deps = [":my_proto"],
)

rust_binary(
    name = "my_service",
    srcs = ["my_service.rs"],
    deps = [":rust"] + GRPC_COMPILE_DEPS,
)
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_grpc_library-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_grpc_library-deps"></a>deps |  List of proto_library dependencies that will be built. One crate for each proto_library will be created with the corresponding gRPC stubs.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="rust_grpc_library-rust_deps"></a>rust_deps |  The crates the generated library depends on.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | ["@io_bazel_rules_rust//proto/raze:protobuf", "@io_bazel_rules_rust//proto/raze:grpc", "@io_bazel_rules_rust//proto/raze:tls_api", "@io_bazel_rules_rust//proto/raze:tls_api_stub"] |


<a id="#rust_library"></a>

## rust_library

<pre>
rust_library(<a href="#rust_library-name">name</a>, <a href="#rust_library-aliases">aliases</a>, <a href="#rust_library-crate_features">crate_features</a>, <a href="#rust_library-crate_root">crate_root</a>, <a href="#rust_library-crate_type">crate_type</a>, <a href="#rust_library-data">data</a>, <a href="#rust_library-deps">deps</a>, <a href="#rust_library-edition">edition</a>,
             <a href="#rust_library-out_dir_tar">out_dir_tar</a>, <a href="#rust_library-proc_macro_deps">proc_macro_deps</a>, <a href="#rust_library-rustc_env">rustc_env</a>, <a href="#rust_library-rustc_flags">rustc_flags</a>, <a href="#rust_library-srcs">srcs</a>, <a href="#rust_library-version">version</a>)
</pre>

Builds a Rust library crate.

Example:

Suppose you have the following directory structure for a simple Rust library crate:

```output
[workspace]/
    WORKSPACE
    hello_lib/
        BUILD
        src/
            greeter.rs
            lib.rs
```

`hello_lib/src/greeter.rs`:
```rust
pub struct Greeter {
    greeting: String,
}

impl Greeter {
    pub fn new(greeting: &str) -> Greeter {
        Greeter { greeting: greeting.to_string(), }
    }

    pub fn greet(&self, thing: &str) {
        println!("{} {}", &self.greeting, thing);
    }
}
```

`hello_lib/src/lib.rs`:

```rust
pub mod greeter;
```

`hello_lib/BUILD`:
```python
package(default_visibility = ["//visibility:public"])

load("@io_bazel_rules_rust//rust:rust.bzl", "rust_library")

rust_library(
    name = "hello_lib",
    srcs = [
        "src/greeter.rs",
        "src/lib.rs",
    ],
)
```

Build the library:
```output
$ bazel build //hello_lib
INFO: Found 1 target...
Target //examples/rust/hello_lib:hello_lib up-to-date:
  bazel-bin/examples/rust/hello_lib/libhello_lib.rlib
INFO: Elapsed time: 1.245s, Critical Path: 1.01s
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_library-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_library-aliases"></a>aliases |  Remap crates to a new name or moniker for linkage to this target<br><br>These are other <code>rust_library</code> targets and will be presented as the new name given.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: Label -> String</a> | optional | {} |
| <a id="rust_library-crate_features"></a>crate_features |  List of features to enable for this crate.<br><br>Features are defined in the code using the <code>#[cfg(feature = "foo")]</code> configuration option. The features listed here will be passed to <code>rustc</code> with <code>--cfg feature="${feature_name}"</code> flags.   | List of strings | optional | [] |
| <a id="rust_library-crate_root"></a>crate_root |  The file that will be passed to <code>rustc</code> to be used for building this crate.<br><br>If <code>crate_root</code> is not set, then this rule will look for a <code>lib.rs</code> file (or <code>main.rs</code> for rust_binary) or the single file in <code>srcs</code> if <code>srcs</code> contains only one file.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_library-crate_type"></a>crate_type |  The type of linkage to use for building this library. Options include <code>"lib"</code>, <code>"rlib"</code>, <code>"dylib"</code>, <code>"cdylib"</code>, <code>"staticlib"</code>, and <code>"proc-macro"</code>.<br><br>The exact output file will depend on the toolchain used.   | String | optional | "rlib" |
| <a id="rust_library-data"></a>data |  List of files used by this rule at runtime.<br><br>This attribute can be used to specify any data files that are embedded into the library, such as via the [<code>include_str!</code>](https://doc.rust-lang.org/std/macro.include_str!.html) macro.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="rust_library-deps"></a>deps |  List of other libraries to be linked to this library target.<br><br>These can be either other <code>rust_library</code> targets or <code>cc_library</code> targets if linking a native library.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="rust_library-edition"></a>edition |  The rust edition to use for this crate. Defaults to the edition specified in the rust_toolchain.   | String | optional | "" |
| <a id="rust_library-out_dir_tar"></a>out_dir_tar |  __Deprecated__, do not use, see [#cargo_build_script] instead.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_library-proc_macro_deps"></a>proc_macro_deps |  List of <code>rust_library</code> targets with kind <code>proc-macro</code> used to help build this library target.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="rust_library-rustc_env"></a>rustc_env |  Dictionary of additional <code>"key": "value"</code> environment variables to set for rustc.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="rust_library-rustc_flags"></a>rustc_flags |  List of compiler flags passed to <code>rustc</code>.   | List of strings | optional | [] |
| <a id="rust_library-srcs"></a>srcs |  List of Rust <code>.rs</code> source files used to build the library.<br><br>If <code>srcs</code> contains more than one file, then there must be a file either named <code>lib.rs</code>. Otherwise, <code>crate_root</code> must be set to the source file that is the root of the crate to be passed to rustc to build this crate.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="rust_library-version"></a>version |  A version to inject in the cargo environment variable.   | String | optional | "0.0.0" |


<a id="#rust_proto_library"></a>

## rust_proto_library

<pre>
rust_proto_library(<a href="#rust_proto_library-name">name</a>, <a href="#rust_proto_library-deps">deps</a>, <a href="#rust_proto_library-rust_deps">rust_deps</a>)
</pre>

Builds a Rust library crate from a set of `proto_library`s.

Example:

```python
load("@io_bazel_rules_rust//proto:proto.bzl", "rust_proto_library")
load("@io_bazel_rules_rust//proto:toolchain.bzl", "PROTO_COMPILE_DEPS")

proto_library(
    name = "my_proto",
    srcs = ["my.proto"]
)

proto_rust_library(
    name = "rust",
    deps = [":my_proto"],
)

rust_binary(
    name = "my_proto_binary",
    srcs = ["my_proto_binary.rs"],
    deps = [":rust"] + PROTO_COMPILE_DEPS,
)
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_proto_library-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_proto_library-deps"></a>deps |  List of proto_library dependencies that will be built. One crate for each proto_library will be created with the corresponding stubs.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="rust_proto_library-rust_deps"></a>rust_deps |  The crates the generated library depends on.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | ["@io_bazel_rules_rust//proto/raze:protobuf"] |


<a id="#rust_proto_toolchain"></a>

## rust_proto_toolchain

<pre>
rust_proto_toolchain(<a href="#rust_proto_toolchain-name">name</a>, <a href="#rust_proto_toolchain-edition">edition</a>, <a href="#rust_proto_toolchain-grpc_plugin">grpc_plugin</a>, <a href="#rust_proto_toolchain-proto_plugin">proto_plugin</a>, <a href="#rust_proto_toolchain-protoc">protoc</a>)
</pre>

Declares a Rust Proto toolchain for use.

This is used to configure proto compilation and can be used to set different protobuf compiler plugin.

Example:

Suppose a new nicer gRPC plugin has came out. The new plugin can be used in Bazel by defining a new toolchain definition and declaration:

```python
load('@io_bazel_rules_rust//proto:toolchain.bzl', 'rust_proto_toolchain')

rust_proto_toolchain(
   name="rust_proto_impl",
   grpc_plugin="@rust_grpc//:grpc_plugin",
   grpc_compile_deps=["@rust_grpc//:grpc_deps"],
)

toolchain(
    name="rust_proto",
    exec_compatible_with = [
        "@platforms//cpu:cpuX",
    ],
    target_compatible_with = [
        "@platforms//cpu:cpuX",
    ],
    toolchain = ":rust_proto_impl",
)
```

Then, either add the label of the toolchain rule to register_toolchains in the WORKSPACE, or pass it to the "--extra_toolchains" flag for Bazel, and it will be used.

See @io_bazel_rules_rust//proto:BUILD for examples of defining the toolchain.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_proto_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_proto_toolchain-edition"></a>edition |  The edition used by the generated rust source.   | String | optional | "2015" |
| <a id="rust_proto_toolchain-grpc_plugin"></a>grpc_plugin |  The location of the Rust protobuf compiler plugin to generate rust gRPC stubs.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | @io_bazel_rules_rust//proto:protoc_gen_rust_grpc |
| <a id="rust_proto_toolchain-proto_plugin"></a>proto_plugin |  The location of the Rust protobuf compiler plugin used to generate rust sources.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | @io_bazel_rules_rust//proto:protoc_gen_rust |
| <a id="rust_proto_toolchain-protoc"></a>protoc |  The location of the <code>protoc</code> binary. It should be an executable target.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | @com_google_protobuf//:protoc |


<a id="#rust_test"></a>

## rust_test

<pre>
rust_test(<a href="#rust_test-name">name</a>, <a href="#rust_test-aliases">aliases</a>, <a href="#rust_test-crate">crate</a>, <a href="#rust_test-crate_features">crate_features</a>, <a href="#rust_test-crate_root">crate_root</a>, <a href="#rust_test-data">data</a>, <a href="#rust_test-deps">deps</a>, <a href="#rust_test-edition">edition</a>, <a href="#rust_test-out_dir_tar">out_dir_tar</a>,
          <a href="#rust_test-proc_macro_deps">proc_macro_deps</a>, <a href="#rust_test-rustc_env">rustc_env</a>, <a href="#rust_test-rustc_flags">rustc_flags</a>, <a href="#rust_test-srcs">srcs</a>, <a href="#rust_test-version">version</a>)
</pre>

Builds a Rust test crate.

Examples:

Suppose you have the following directory structure for a Rust library crate with unit test code in the library sources:

```output
[workspace]/
    WORKSPACE
    hello_lib/
        BUILD
        src/
            lib.rs
```

`hello_lib/src/lib.rs`:
```rust
pub struct Greeter {
    greeting: String,
}

impl Greeter {
    pub fn new(greeting: &str) -> Greeter {
        Greeter { greeting: greeting.to_string(), }
    }

    pub fn greet(&self, thing: &str) {
        println!("{} {}", &self.greeting, thing);
    }
}

#[cfg(test)]
mod test {
    use super::Greeter;

    #[test]
    fn test_greeting() {
        let hello = Greeter::new("Hi");
        assert_eq!("Hi Rust", hello.greeting("Rust"));
    }
}
```

To build and run the tests, simply add a `rust_test` rule with no `srcs` and only depends on the `hello_lib` `rust_library` target:

`hello_lib/BUILD`:
```python
package(default_visibility = ["//visibility:public"])

load("@io_bazel_rules_rust//rust:rust.bzl", "rust_library", "rust_test")

rust_library(
    name = "hello_lib",
    srcs = ["src/lib.rs"],
)

rust_test(
    name = "hello_lib_test",
    deps = [":hello_lib"],
)
```

Run the test with `bazel build //hello_lib:hello_lib_test`.

To run a crate or lib with the `#[cfg(test)]` configuration, handling inline tests, you should specify the crate directly like so.

```python
rust_test(
    name = "hello_lib_test",
    crate = ":hello_lib",
    # You may add other deps that are specific to the test configuration
    deps = ["//some/dev/dep"],
)
```

### Example: `test` directory

Integration tests that live in the [`tests` directory][int-tests], they are essentially built as separate crates. Suppose you have the following directory structure where `greeting.rs` is an integration test for the `hello_lib` library crate:

[int-tests]: http://doc.rust-lang.org/book/testing.html#the-tests-directory

```output
[workspace]/
    WORKSPACE
    hello_lib/
        BUILD
        src/
            lib.rs
        tests/
            greeting.rs
```

`hello_lib/tests/greeting.rs`:
```rust
extern crate hello_lib;

use hello_lib;

#[test]
fn test_greeting() {
    let hello = greeter::Greeter::new("Hello");
    assert_eq!("Hello world", hello.greeting("world"));
}
```

To build the `greeting.rs` integration test, simply add a `rust_test` target
with `greeting.rs` in `srcs` and a dependency on the `hello_lib` target:

`hello_lib/BUILD`:
```python
package(default_visibility = ["//visibility:public"])

load("@io_bazel_rules_rust//rust:rust.bzl", "rust_library", "rust_test")

rust_library(
    name = "hello_lib",
    srcs = ["src/lib.rs"],
)

rust_test(
    name = "greeting_test",
    srcs = ["tests/greeting.rs"],
    deps = [":hello_lib"],
)
```

Run the test with `bazel build //hello_lib:hello_lib_test`.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_test-aliases"></a>aliases |  Remap crates to a new name or moniker for linkage to this target<br><br>These are other <code>rust_library</code> targets and will be presented as the new name given.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: Label -> String</a> | optional | {} |
| <a id="rust_test-crate"></a>crate |  Target inline tests declared in the given crate<br><br>These tests are typically those that would be held out under <code>#[cfg(test)]</code> declarations.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_test-crate_features"></a>crate_features |  List of features to enable for this crate.<br><br>Features are defined in the code using the <code>#[cfg(feature = "foo")]</code> configuration option. The features listed here will be passed to <code>rustc</code> with <code>--cfg feature="${feature_name}"</code> flags.   | List of strings | optional | [] |
| <a id="rust_test-crate_root"></a>crate_root |  The file that will be passed to <code>rustc</code> to be used for building this crate.<br><br>If <code>crate_root</code> is not set, then this rule will look for a <code>lib.rs</code> file (or <code>main.rs</code> for rust_binary) or the single file in <code>srcs</code> if <code>srcs</code> contains only one file.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_test-data"></a>data |  List of files used by this rule at runtime.<br><br>This attribute can be used to specify any data files that are embedded into the library, such as via the [<code>include_str!</code>](https://doc.rust-lang.org/std/macro.include_str!.html) macro.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="rust_test-deps"></a>deps |  List of other libraries to be linked to this library target.<br><br>These can be either other <code>rust_library</code> targets or <code>cc_library</code> targets if linking a native library.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="rust_test-edition"></a>edition |  The rust edition to use for this crate. Defaults to the edition specified in the rust_toolchain.   | String | optional | "" |
| <a id="rust_test-out_dir_tar"></a>out_dir_tar |  __Deprecated__, do not use, see [#cargo_build_script] instead.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_test-proc_macro_deps"></a>proc_macro_deps |  List of <code>rust_library</code> targets with kind <code>proc-macro</code> used to help build this library target.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="rust_test-rustc_env"></a>rustc_env |  Dictionary of additional <code>"key": "value"</code> environment variables to set for rustc.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="rust_test-rustc_flags"></a>rustc_flags |  List of compiler flags passed to <code>rustc</code>.   | List of strings | optional | [] |
| <a id="rust_test-srcs"></a>srcs |  List of Rust <code>.rs</code> source files used to build the library.<br><br>If <code>srcs</code> contains more than one file, then there must be a file either named <code>lib.rs</code>. Otherwise, <code>crate_root</code> must be set to the source file that is the root of the crate to be passed to rustc to build this crate.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="rust_test-version"></a>version |  A version to inject in the cargo environment variable.   | String | optional | "0.0.0" |


<a id="#rust_toolchain"></a>

## rust_toolchain

<pre>
rust_toolchain(<a href="#rust_toolchain-name">name</a>, <a href="#rust_toolchain-binary_ext">binary_ext</a>, <a href="#rust_toolchain-cargo">cargo</a>, <a href="#rust_toolchain-clippy_driver">clippy_driver</a>, <a href="#rust_toolchain-debug_info">debug_info</a>, <a href="#rust_toolchain-default_edition">default_edition</a>, <a href="#rust_toolchain-dylib_ext">dylib_ext</a>,
               <a href="#rust_toolchain-exec_triple">exec_triple</a>, <a href="#rust_toolchain-opt_level">opt_level</a>, <a href="#rust_toolchain-os">os</a>, <a href="#rust_toolchain-rust_doc">rust_doc</a>, <a href="#rust_toolchain-rust_lib">rust_lib</a>, <a href="#rust_toolchain-rustc">rustc</a>, <a href="#rust_toolchain-rustc_lib">rustc_lib</a>, <a href="#rust_toolchain-rustfmt">rustfmt</a>,
               <a href="#rust_toolchain-staticlib_ext">staticlib_ext</a>, <a href="#rust_toolchain-stdlib_linkflags">stdlib_linkflags</a>, <a href="#rust_toolchain-target_triple">target_triple</a>)
</pre>

Declares a Rust toolchain for use.

This is for declaring a custom toolchain, eg. for configuring a particular version of rust or supporting a new platform.

Example:

Suppose the core rust team has ported the compiler to a new target CPU, called `cpuX`. This support can be used in Bazel by defining a new toolchain definition and declaration:

```python
load('@io_bazel_rules_rust//rust:toolchain.bzl', 'rust_toolchain')

rust_toolchain(
    name = "rust_cpuX_impl",
    rustc = "@rust_cpuX//:rustc",
    rustc_lib = "@rust_cpuX//:rustc_lib",
    rust_lib = "@rust_cpuX//:rust_lib",
    rust_doc = "@rust_cpuX//:rustdoc",
    binary_ext = "",
    staticlib_ext = ".a",
    dylib_ext = ".so",
    stdlib_linkflags = ["-lpthread", "-ldl"],
    os = "linux",
)

toolchain(
    name = "rust_cpuX",
    exec_compatible_with = [
        "@platforms//cpu:cpuX",
    ],
    target_compatible_with = [
        "@platforms//cpu:cpuX",
    ],
    toolchain = ":rust_cpuX_impl",
)
```

Then, either add the label of the toolchain rule to `register_toolchains` in the WORKSPACE, or pass it to the `"--extra_toolchains"` flag for Bazel, and it will be used.

See @io_bazel_rules_rust//rust:repositories.bzl for examples of defining the @rust_cpuX repository with the actual binaries and libraries.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_toolchain-binary_ext"></a>binary_ext |  The extension for binaries created from rustc.   | String | required |  |
| <a id="rust_toolchain-cargo"></a>cargo |  The location of the <code>cargo</code> binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-clippy_driver"></a>clippy_driver |  The location of the <code>clippy-driver</code> binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-debug_info"></a>debug_info |  Rustc debug info levels per opt level   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {"opt": "0", "dbg": "2", "fastbuild": "0"} |
| <a id="rust_toolchain-default_edition"></a>default_edition |  The edition to use for rust_* rules that don't specify an edition.   | String | optional | "2015" |
| <a id="rust_toolchain-dylib_ext"></a>dylib_ext |  The extension for dynamic libraries created from rustc.   | String | required |  |
| <a id="rust_toolchain-exec_triple"></a>exec_triple |  The platform triple for the toolchains execution environment. For more details see: https://docs.bazel.build/versions/master/skylark/rules.html#configurations   | String | optional | "" |
| <a id="rust_toolchain-opt_level"></a>opt_level |  Rustc optimization levels.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {"opt": "3", "dbg": "0", "fastbuild": "0"} |
| <a id="rust_toolchain-os"></a>os |  The operating system for the current toolchain   | String | required |  |
| <a id="rust_toolchain-rust_doc"></a>rust_doc |  The location of the <code>rustdoc</code> binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-rust_lib"></a>rust_lib |  The rust standard library.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-rustc"></a>rustc |  The location of the <code>rustc</code> binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-rustc_lib"></a>rustc_lib |  The libraries used by rustc during compilation.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-rustfmt"></a>rustfmt |  The location of the <code>rustfmt</code> binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-staticlib_ext"></a>staticlib_ext |  The extension for static libraries created from rustc.   | String | required |  |
| <a id="rust_toolchain-stdlib_linkflags"></a>stdlib_linkflags |  Additional linker libs used when std lib is linked, see https://github.com/rust-lang/rust/blob/master/src/libstd/build.rs   | List of strings | required |  |
| <a id="rust_toolchain-target_triple"></a>target_triple |  The platform triple for the toolchains target environment. For more details see: https://docs.bazel.build/versions/master/skylark/rules.html#configurations   | String | optional | "" |


<a id="#rust_toolchain_repository"></a>

## rust_toolchain_repository

<pre>
rust_toolchain_repository(<a href="#rust_toolchain_repository-name">name</a>, <a href="#rust_toolchain_repository-dev_components">dev_components</a>, <a href="#rust_toolchain_repository-edition">edition</a>, <a href="#rust_toolchain_repository-exec_triple">exec_triple</a>, <a href="#rust_toolchain_repository-extra_target_triples">extra_target_triples</a>,
                          <a href="#rust_toolchain_repository-iso_date">iso_date</a>, <a href="#rust_toolchain_repository-rustfmt_version">rustfmt_version</a>, <a href="#rust_toolchain_repository-sha256s">sha256s</a>, <a href="#rust_toolchain_repository-toolchain_name_prefix">toolchain_name_prefix</a>, <a href="#rust_toolchain_repository-version">version</a>)
</pre>

Composes a single workspace containing the toolchain components for compiling on a given platform to a series of target platforms. 
A given instance of this rule should be accompanied by a rust_toolchain_repository_proxy invocation to declare its toolchains to Bazel; the indirection allows separating toolchain selection from toolchain fetching.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_toolchain_repository-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_toolchain_repository-dev_components"></a>dev_components |  Whether to download the rustc-dev components (defaults to False). Requires version to be "nightly".   | Boolean | optional | False |
| <a id="rust_toolchain_repository-edition"></a>edition |  The rust edition to be used by default.   | String | optional | "2015" |
| <a id="rust_toolchain_repository-exec_triple"></a>exec_triple |  The Rust-style target that this compiler runs on   | String | required |  |
| <a id="rust_toolchain_repository-extra_target_triples"></a>extra_target_triples |  Additional rust-style targets that this set of toolchains should support.   | List of strings | optional | [] |
| <a id="rust_toolchain_repository-iso_date"></a>iso_date |  The date of the tool (or None, if the version is a specific version).   | String | optional | "" |
| <a id="rust_toolchain_repository-rustfmt_version"></a>rustfmt_version |  The version of the tool among "nightly", "beta", or an exact version.   | String | optional | "" |
| <a id="rust_toolchain_repository-sha256s"></a>sha256s |  A dict associating tool subdirectories to sha256 hashes. See [rust_repositories](#rust_repositories) for more details.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="rust_toolchain_repository-toolchain_name_prefix"></a>toolchain_name_prefix |  The per-target prefix expected for the rust_toolchain declarations in the parent workspace.   | String | optional | "" |
| <a id="rust_toolchain_repository-version"></a>version |  The version of the tool among "nightly", "beta", or an exact version.   | String | required |  |


<a id="#rust_toolchain_repository_proxy"></a>

## rust_toolchain_repository_proxy

<pre>
rust_toolchain_repository_proxy(<a href="#rust_toolchain_repository_proxy-name">name</a>, <a href="#rust_toolchain_repository_proxy-exec_triple">exec_triple</a>, <a href="#rust_toolchain_repository_proxy-extra_target_triples">extra_target_triples</a>, <a href="#rust_toolchain_repository_proxy-parent_workspace_name">parent_workspace_name</a>,
                                <a href="#rust_toolchain_repository_proxy-toolchain_name_prefix">toolchain_name_prefix</a>)
</pre>

Generates a toolchain-bearing repository that declares the toolchains from some other rust_toolchain_repository.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_toolchain_repository_proxy-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_toolchain_repository_proxy-exec_triple"></a>exec_triple |  The Rust-style target triple for the compilation platform   | String | required |  |
| <a id="rust_toolchain_repository_proxy-extra_target_triples"></a>extra_target_triples |  The Rust-style triples for extra compilation targets   | List of strings | optional | [] |
| <a id="rust_toolchain_repository_proxy-parent_workspace_name"></a>parent_workspace_name |  The name of the other rust_toolchain_repository   | String | required |  |
| <a id="rust_toolchain_repository_proxy-toolchain_name_prefix"></a>toolchain_name_prefix |  The per-target prefix expected for the rust_toolchain declarations in the parent workspace.   | String | optional | "" |


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
| <a id="rust_wasm_bindgen_toolchain-bindgen"></a>bindgen |  The label of a <code>bindgen</code> executable.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="#cargo_build_script"></a>

## cargo_build_script

<pre>
cargo_build_script(<a href="#cargo_build_script-name">name</a>, <a href="#cargo_build_script-crate_name">crate_name</a>, <a href="#cargo_build_script-crate_features">crate_features</a>, <a href="#cargo_build_script-version">version</a>, <a href="#cargo_build_script-deps">deps</a>, <a href="#cargo_build_script-build_script_env">build_script_env</a>, <a href="#cargo_build_script-kwargs">kwargs</a>)
</pre>

Compile and execute a rust build script to generate build attributes

This rules take the same arguments as rust_binary.

Example:

Suppose you have a crate with a cargo build script `build.rs`:

```output
[workspace]/
    hello_lib/
        BUILD
        build.rs
        src/
            lib.rs
```

Then you want to use the build script in the following:

`hello_lib/BUILD`:
```python
package(default_visibility = ["//visibility:public"])

load("@io_bazel_rules_rust//rust:rust.bzl", "rust_binary", "rust_library")
load("@io_bazel_rules_rust//cargo:cargo_build_script.bzl", "cargo_build_script")

# This will run the build script from the root of the workspace, and
# collect the outputs.
cargo_build_script(
    name = "build_script",
    srcs = ["build.rs"],
    # Data are shipped during execution.
    data = ["src/lib.rs"],
    # Environment variables passed during build.rs execution
    build_script_env = {"CARGO_PKG_VERSION": "0.1.2"},
)

rust_library(
    name = "hello_lib",
    srcs = [
        "src/lib.rs",
    ],
    deps = [":build_script"],
)
```

The `hello_lib` target will be build with the flags and the environment variables declared by the     build script in addition to the file generated by it.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="cargo_build_script-name"></a>name |  The target name for the underlying rule   |  none |
| <a id="cargo_build_script-crate_name"></a>crate_name |  Name of the crate associated with this build script target.   |  <code>""</code> |
| <a id="cargo_build_script-crate_features"></a>crate_features |  A list of features to enable for the build script.   |  <code>[]</code> |
| <a id="cargo_build_script-version"></a>version |  The semantic version (semver) of the crate.   |  <code>None</code> |
| <a id="cargo_build_script-deps"></a>deps |  The dependencies of the crate defined by <code>crate_name</code>.   |  <code>[]</code> |
| <a id="cargo_build_script-build_script_env"></a>build_script_env |  Environment variables for build scripts.   |  <code>{}</code> |
| <a id="cargo_build_script-kwargs"></a>kwargs |  Forwards to the underlying <code>rust_binary</code> rule.   |  none |


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


<a id="#rust_repositories"></a>

## rust_repositories

<pre>
rust_repositories(<a href="#rust_repositories-version">version</a>, <a href="#rust_repositories-iso_date">iso_date</a>, <a href="#rust_repositories-rustfmt_version">rustfmt_version</a>, <a href="#rust_repositories-edition">edition</a>, <a href="#rust_repositories-dev_components">dev_components</a>, <a href="#rust_repositories-sha256s">sha256s</a>)
</pre>

Emits a default set of toolchains for Linux, OSX, and Freebsd

Skip this macro and call the `rust_repository_set` macros directly if you need a compiler for     other hosts or for additional target triples.

The `sha256` attribute represents a dict associating tool subdirectories to sha256 hashes. As an example:
```python
{
    "rust-1.46.0-x86_64-unknown-linux-gnu": "e3b98bc3440fe92817881933f9564389eccb396f5f431f33d48b979fa2fbdcf5",
    "rustfmt-1.4.12-x86_64-unknown-linux-gnu": "1894e76913303d66bf40885a601462844eec15fca9e76a6d13c390d7000d64b0",
    "rust-std-1.46.0-x86_64-unknown-linux-gnu": "ac04aef80423f612c0079829b504902de27a6997214eb58ab0765d02f7ec1dbc",
}
```
This would match for `exec_triple = "x86_64-unknown-linux-gnu"`.  If not specified, rules_rust pulls from a non-exhaustive     list of known checksums..

See `load_arbitrary_tool` in `@io_bazel_rules_rust//rust:repositories.bzl` for more details.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rust_repositories-version"></a>version |  The version of Rust. Either "nightly", "beta", or an exact version.   |  <code>"1.44.0"</code> |
| <a id="rust_repositories-iso_date"></a>iso_date |  The date of the nightly or beta release (or None, if the version is a specific version).   |  <code>None</code> |
| <a id="rust_repositories-rustfmt_version"></a>rustfmt_version |  The version of rustfmt. Either "nightly", "beta", or an exact version.   |  <code>"1.4.18"</code> |
| <a id="rust_repositories-edition"></a>edition |  The rust edition to be used by default (2015 (default) or 2018)   |  <code>None</code> |
| <a id="rust_repositories-dev_components"></a>dev_components |  Whether to download the rustc-dev components (defaults to False). Requires version to be "nightly".   |  <code>False</code> |
| <a id="rust_repositories-sha256s"></a>sha256s |  A dict associating tool subdirectories to sha256 hashes.   |  <code>None</code> |


<a id="#rust_repository_set"></a>

## rust_repository_set

<pre>
rust_repository_set(<a href="#rust_repository_set-name">name</a>, <a href="#rust_repository_set-version">version</a>, <a href="#rust_repository_set-exec_triple">exec_triple</a>, <a href="#rust_repository_set-extra_target_triples">extra_target_triples</a>, <a href="#rust_repository_set-iso_date">iso_date</a>, <a href="#rust_repository_set-rustfmt_version">rustfmt_version</a>,
                    <a href="#rust_repository_set-edition">edition</a>, <a href="#rust_repository_set-dev_components">dev_components</a>, <a href="#rust_repository_set-sha256s">sha256s</a>)
</pre>

Assembles a remote repository for the given toolchain params, produces a proxy repository     to contain the toolchain declaration, and registers the toolchains.

N.B. A "proxy repository" is needed to allow for registering the toolchain (with constraints)     without actually downloading the toolchain.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rust_repository_set-name"></a>name |  The name of the generated repository   |  none |
| <a id="rust_repository_set-version"></a>version |  The version of the tool among "nightly", "beta', or an exact version.   |  none |
| <a id="rust_repository_set-exec_triple"></a>exec_triple |  The Rust-style target that this compiler runs on   |  none |
| <a id="rust_repository_set-extra_target_triples"></a>extra_target_triples |  Additional rust-style targets that this set of     toolchains should support. Defaults to [].   |  <code>[]</code> |
| <a id="rust_repository_set-iso_date"></a>iso_date |  The date of the tool. Defaults to None.   |  <code>None</code> |
| <a id="rust_repository_set-rustfmt_version"></a>rustfmt_version |  The version of rustfmt to be associated with the     toolchain. Defaults to None.   |  <code>None</code> |
| <a id="rust_repository_set-edition"></a>edition |  The rust edition to be used by default (2015 (if None) or 2018).   |  <code>None</code> |
| <a id="rust_repository_set-dev_components"></a>dev_components |  Whether to download the rustc-dev components.     Requires version to be "nightly". Defaults to False.   |  <code>False</code> |
| <a id="rust_repository_set-sha256s"></a>sha256s |  A dict associating tool subdirectories to sha256 hashes. See     [rust_repositories](#rust_repositories) for more details.   |  <code>None</code> |


<a id="#rust_workspace"></a>

## rust_workspace

<pre>
rust_workspace()
</pre>

A helper macro for setting up requirements for `rules_rust` within a given workspace.

This macro should always loaded and invoked after `rust_repositories` within a WORKSPACE
file.

**PARAMETERS**



