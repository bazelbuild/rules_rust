<a name="#rust_binary"></a>
## rust_binary

<pre>
rust_binary(<a href="#rust_binary-name">name</a>, <a href="#rust_binary-crate_features">crate_features</a>, <a href="#rust_binary-crate_root">crate_root</a>, <a href="#rust_binary-data">data</a>, <a href="#rust_binary-deps">deps</a>, <a href="#rust_binary-edition">edition</a>, <a href="#rust_binary-out_dir_tar">out_dir_tar</a>, <a href="#rust_binary-rustc_flags">rustc_flags</a>, <a href="#rust_binary-srcs">srcs</a>, <a href="#rust_binary-version">version</a>)
</pre>


Builds a Rust binary crate.

Example:

Suppose you have the following directory structure for a Rust project with a
library crate, `hello_lib`, and a binary crate, `hello_world` that uses the
`hello_lib` library:

```
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


### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="rust_binary-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="rust_binary-crate_features">
      <td><code>crate_features</code></td>
      <td>
        List of strings; optional
        <p>
          List of features to enable for this crate.

Features are defined in the code using the `#[cfg(feature = "foo")]`
configuration option. The features listed here will be passed to `rustc`
with `--cfg feature="${feature_name}"` flags.
        </p>
      </td>
    </tr>
    <tr id="rust_binary-crate_root">
      <td><code>crate_root</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
        <p>
          The file that will be passed to `rustc` to be used for building this crate.

If `crate_root` is not set, then this rule will look for a `lib.rs` file (or `main.rs` for rust_binary)
or the single file in `srcs` if `srcs` contains only one file.
        </p>
      </td>
    </tr>
    <tr id="rust_binary-data">
      <td><code>data</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
        <p>
          List of files used by this rule at runtime.

This attribute can be used to specify any data files that are embedded into
the library, such as via the
[`include_str!`](https://doc.rust-lang.org/std/macro.include_str!.html)
macro.
        </p>
      </td>
    </tr>
    <tr id="rust_binary-deps">
      <td><code>deps</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
        <p>
          List of other libraries to be linked to this library target.

These can be either other `rust_library` targets or `cc_library` targets if
linking a native library.
        </p>
      </td>
    </tr>
    <tr id="rust_binary-edition">
      <td><code>edition</code></td>
      <td>
        String; optional
        <p>
          The rust edition to use for this crate. Defaults to the edition specified in the rust_toolchain.
        </p>
      </td>
    </tr>
    <tr id="rust_binary-out_dir_tar">
      <td><code>out_dir_tar</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
        <p>
          An optional tar or tar.gz file unpacked and passed as OUT_DIR.

Many library crates in the Rust ecosystem require sources to be provided
to them in the form of an OUT_DIR argument. This argument can be used to
supply the contents of this directory.
        </p>
      </td>
    </tr>
    <tr id="rust_binary-rustc_flags">
      <td><code>rustc_flags</code></td>
      <td>
        List of strings; optional
        <p>
          List of compiler flags passed to `rustc`.
        </p>
      </td>
    </tr>
    <tr id="rust_binary-srcs">
      <td><code>srcs</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
        <p>
          List of Rust `.rs` source files used to build the library.

If `srcs` contains more than one file, then there must be a file either
named `lib.rs`. Otherwise, `crate_root` must be set to the source file that
is the root of the crate to be passed to rustc to build this crate.
        </p>
      </td>
    </tr>
    <tr id="rust_binary-version">
      <td><code>version</code></td>
      <td>
        String; optional
        <p>
          A version to inject in the cargo environment variable.
        </p>
      </td>
    </tr>
  </tbody>
</table>


<a name="#rust_doc"></a>
## rust_doc

<pre>
rust_doc(<a href="#rust_doc-name">name</a>, <a href="#rust_doc-dep">dep</a>, <a href="#rust_doc-html_after_content">html_after_content</a>, <a href="#rust_doc-html_before_content">html_before_content</a>, <a href="#rust_doc-html_in_header">html_in_header</a>, <a href="#rust_doc-markdown_css">markdown_css</a>)
</pre>



### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="rust_doc-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="rust_doc-dep">
      <td><code>dep</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; required
        <p>
          The crate to generate documentation for.
        </p>
      </td>
    </tr>
    <tr id="rust_doc-html_after_content">
      <td><code>html_after_content</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
      </td>
    </tr>
    <tr id="rust_doc-html_before_content">
      <td><code>html_before_content</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
      </td>
    </tr>
    <tr id="rust_doc-html_in_header">
      <td><code>html_in_header</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
      </td>
    </tr>
    <tr id="rust_doc-markdown_css">
      <td><code>markdown_css</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
      </td>
    </tr>
  </tbody>
</table>


<a name="#rust_doc_test"></a>
## rust_doc_test

<pre>
rust_doc_test(<a href="#rust_doc_test-name">name</a>, <a href="#rust_doc_test-dep">dep</a>)
</pre>


Runs Rust documentation tests.

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

To run [documentation tests][doc-test] for the `hello_lib` crate, define a
`rust_doc_test` target that depends on the `hello_lib` `rust_library` target:

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


### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="rust_doc_test-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="rust_doc_test-dep">
      <td><code>dep</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; required
        <p>
          The label of the target to run documentation tests for.

`rust_doc_test` can run documentation tests for the source files of
`rust_library` or `rust_binary` targets.
        </p>
      </td>
    </tr>
  </tbody>
</table>


<a name="#rust_library"></a>
## rust_library

<pre>
rust_library(<a href="#rust_library-name">name</a>, <a href="#rust_library-crate_features">crate_features</a>, <a href="#rust_library-crate_root">crate_root</a>, <a href="#rust_library-crate_type">crate_type</a>, <a href="#rust_library-data">data</a>, <a href="#rust_library-deps">deps</a>, <a href="#rust_library-edition">edition</a>, <a href="#rust_library-out_dir_tar">out_dir_tar</a>, <a href="#rust_library-rustc_flags">rustc_flags</a>, <a href="#rust_library-srcs">srcs</a>, <a href="#rust_library-version">version</a>)
</pre>


Builds a Rust library crate.

Example:

Suppose you have the following directory structure for a simple Rust library crate:

```
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
```
$ bazel build //hello_lib
INFO: Found 1 target...
Target //examples/rust/hello_lib:hello_lib up-to-date:
  bazel-bin/examples/rust/hello_lib/libhello_lib.rlib
INFO: Elapsed time: 1.245s, Critical Path: 1.01s
```


### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="rust_library-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="rust_library-crate_features">
      <td><code>crate_features</code></td>
      <td>
        List of strings; optional
        <p>
          List of features to enable for this crate.

Features are defined in the code using the `#[cfg(feature = "foo")]`
configuration option. The features listed here will be passed to `rustc`
with `--cfg feature="${feature_name}"` flags.
        </p>
      </td>
    </tr>
    <tr id="rust_library-crate_root">
      <td><code>crate_root</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
        <p>
          The file that will be passed to `rustc` to be used for building this crate.

If `crate_root` is not set, then this rule will look for a `lib.rs` file (or `main.rs` for rust_binary)
or the single file in `srcs` if `srcs` contains only one file.
        </p>
      </td>
    </tr>
    <tr id="rust_library-crate_type">
      <td><code>crate_type</code></td>
      <td>
        String; optional
        <p>
          The type of linkage to use for building this library.
Options include "lib", "rlib", "dylib", "cdylib", "staticlib", and "proc-macro".

The exact output file will depend on the toolchain used.
        </p>
      </td>
    </tr>
    <tr id="rust_library-data">
      <td><code>data</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
        <p>
          List of files used by this rule at runtime.

This attribute can be used to specify any data files that are embedded into
the library, such as via the
[`include_str!`](https://doc.rust-lang.org/std/macro.include_str!.html)
macro.
        </p>
      </td>
    </tr>
    <tr id="rust_library-deps">
      <td><code>deps</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
        <p>
          List of other libraries to be linked to this library target.

These can be either other `rust_library` targets or `cc_library` targets if
linking a native library.
        </p>
      </td>
    </tr>
    <tr id="rust_library-edition">
      <td><code>edition</code></td>
      <td>
        String; optional
        <p>
          The rust edition to use for this crate. Defaults to the edition specified in the rust_toolchain.
        </p>
      </td>
    </tr>
    <tr id="rust_library-out_dir_tar">
      <td><code>out_dir_tar</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
        <p>
          An optional tar or tar.gz file unpacked and passed as OUT_DIR.

Many library crates in the Rust ecosystem require sources to be provided
to them in the form of an OUT_DIR argument. This argument can be used to
supply the contents of this directory.
        </p>
      </td>
    </tr>
    <tr id="rust_library-rustc_flags">
      <td><code>rustc_flags</code></td>
      <td>
        List of strings; optional
        <p>
          List of compiler flags passed to `rustc`.
        </p>
      </td>
    </tr>
    <tr id="rust_library-srcs">
      <td><code>srcs</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
        <p>
          List of Rust `.rs` source files used to build the library.

If `srcs` contains more than one file, then there must be a file either
named `lib.rs`. Otherwise, `crate_root` must be set to the source file that
is the root of the crate to be passed to rustc to build this crate.
        </p>
      </td>
    </tr>
    <tr id="rust_library-version">
      <td><code>version</code></td>
      <td>
        String; optional
        <p>
          A version to inject in the cargo environment variable.
        </p>
      </td>
    </tr>
  </tbody>
</table>


<a name="#rust_proto_library"></a>
## rust_proto_library

<pre>
rust_proto_library(<a href="#rust_proto_library-name">name</a>, <a href="#rust_proto_library-deps">deps</a>, <a href="#rust_proto_library-rust_deps">rust_deps</a>)
</pre>


Builds a Rust library crate from a set of `proto_library`s.

Example:

```
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


### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="rust_proto_library-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="rust_proto_library-deps">
      <td><code>deps</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; required
        <p>
          List of proto_library dependencies that will be built.
                One crate for each proto_library will be created with the corresponding stubs.
        </p>
      </td>
    </tr>
    <tr id="rust_proto_library-rust_deps">
      <td><code>rust_deps</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
      </td>
    </tr>
  </tbody>
</table>


<a name="#rust_proto_toolchain"></a>
## rust_proto_toolchain

<pre>
rust_proto_toolchain(<a href="#rust_proto_toolchain-name">name</a>, <a href="#rust_proto_toolchain-edition">edition</a>, <a href="#rust_proto_toolchain-grpc_compile_deps">grpc_compile_deps</a>, <a href="#rust_proto_toolchain-grpc_plugin">grpc_plugin</a>, <a href="#rust_proto_toolchain-proto_compile_deps">proto_compile_deps</a>, <a href="#rust_proto_toolchain-proto_plugin">proto_plugin</a>, <a href="#rust_proto_toolchain-protoc">protoc</a>)
</pre>


Declares a Rust Proto toolchain for use.

This is used to configure proto compilation and can be used to set different
protobuf compiler plugin.

Example:

Suppose a new nicer gRPC plugin has came out. The new plugin can be
used in Bazel by defining a new toolchain definition and declaration:

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
        "@bazel_tools//platforms:cpuX",
    ],
    target_compatible_with = [
        "@bazel_tools//platforms:cpuX",
    ],
    toolchain = ":rust_proto_impl",
)
```

Then, either add the label of the toolchain rule to register_toolchains in the WORKSPACE, or pass
it to the "--extra_toolchains" flag for Bazel, and it will be used.

See @io_bazel_rules_rust//proto:BUILD for examples of defining the toolchain.


### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="rust_proto_toolchain-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="rust_proto_toolchain-edition">
      <td><code>edition</code></td>
      <td>
        String; optional
        <p>
          The edition used by the generated rust source.
        </p>
      </td>
    </tr>
    <tr id="rust_proto_toolchain-grpc_compile_deps">
      <td><code>grpc_compile_deps</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
        <p>
          The compile-time dependencies for the generated gRPC stubs.
        </p>
      </td>
    </tr>
    <tr id="rust_proto_toolchain-grpc_plugin">
      <td><code>grpc_plugin</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
        <p>
          The location of the Rust protobuf compiler pugin to generate rust gRPC stubs.
        </p>
      </td>
    </tr>
    <tr id="rust_proto_toolchain-proto_compile_deps">
      <td><code>proto_compile_deps</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
        <p>
          The compile-time dependencies for the generated protobuf stubs.
        </p>
      </td>
    </tr>
    <tr id="rust_proto_toolchain-proto_plugin">
      <td><code>proto_plugin</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
        <p>
          The location of the Rust protobuf compiler plugin used to generate rust sources.
        </p>
      </td>
    </tr>
    <tr id="rust_proto_toolchain-protoc">
      <td><code>protoc</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
        <p>
          The location of the `protoc` binary. It should be an executable target.
        </p>
      </td>
    </tr>
  </tbody>
</table>


<a name="#rust_test"></a>
## rust_test

<pre>
rust_test(<a href="#rust_test-name">name</a>, <a href="#rust_test-crate_features">crate_features</a>, <a href="#rust_test-crate_root">crate_root</a>, <a href="#rust_test-data">data</a>, <a href="#rust_test-deps">deps</a>, <a href="#rust_test-edition">edition</a>, <a href="#rust_test-out_dir_tar">out_dir_tar</a>, <a href="#rust_test-rustc_flags">rustc_flags</a>, <a href="#rust_test-srcs">srcs</a>, <a href="#rust_test-version">version</a>)
</pre>


Builds a Rust test crate.

Examples:

Suppose you have the following directory structure for a Rust library crate
with unit test code in the library sources:

```
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

To build and run the tests, simply add a `rust_test` rule with no `srcs` and
only depends on the `hello_lib` `rust_library` target:

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

### Example: `test` directory

Integration tests that live in the [`tests` directory][int-tests], they are
essentially built as separate crates. Suppose you have the following directory
structure where `greeting.rs` is an integration test for the `hello_lib`
library crate:

[int-tests]: http://doc.rust-lang.org/book/testing.html#the-tests-directory

```
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


### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="rust_test-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="rust_test-crate_features">
      <td><code>crate_features</code></td>
      <td>
        List of strings; optional
        <p>
          List of features to enable for this crate.

Features are defined in the code using the `#[cfg(feature = "foo")]`
configuration option. The features listed here will be passed to `rustc`
with `--cfg feature="${feature_name}"` flags.
        </p>
      </td>
    </tr>
    <tr id="rust_test-crate_root">
      <td><code>crate_root</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
        <p>
          The file that will be passed to `rustc` to be used for building this crate.

If `crate_root` is not set, then this rule will look for a `lib.rs` file (or `main.rs` for rust_binary)
or the single file in `srcs` if `srcs` contains only one file.
        </p>
      </td>
    </tr>
    <tr id="rust_test-data">
      <td><code>data</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
        <p>
          List of files used by this rule at runtime.

This attribute can be used to specify any data files that are embedded into
the library, such as via the
[`include_str!`](https://doc.rust-lang.org/std/macro.include_str!.html)
macro.
        </p>
      </td>
    </tr>
    <tr id="rust_test-deps">
      <td><code>deps</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
        <p>
          List of other libraries to be linked to this library target.

These can be either other `rust_library` targets or `cc_library` targets if
linking a native library.
        </p>
      </td>
    </tr>
    <tr id="rust_test-edition">
      <td><code>edition</code></td>
      <td>
        String; optional
        <p>
          The rust edition to use for this crate. Defaults to the edition specified in the rust_toolchain.
        </p>
      </td>
    </tr>
    <tr id="rust_test-out_dir_tar">
      <td><code>out_dir_tar</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
        <p>
          An optional tar or tar.gz file unpacked and passed as OUT_DIR.

Many library crates in the Rust ecosystem require sources to be provided
to them in the form of an OUT_DIR argument. This argument can be used to
supply the contents of this directory.
        </p>
      </td>
    </tr>
    <tr id="rust_test-rustc_flags">
      <td><code>rustc_flags</code></td>
      <td>
        List of strings; optional
        <p>
          List of compiler flags passed to `rustc`.
        </p>
      </td>
    </tr>
    <tr id="rust_test-srcs">
      <td><code>srcs</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
        <p>
          List of Rust `.rs` source files used to build the library.

If `srcs` contains more than one file, then there must be a file either
named `lib.rs`. Otherwise, `crate_root` must be set to the source file that
is the root of the crate to be passed to rustc to build this crate.
        </p>
      </td>
    </tr>
    <tr id="rust_test-version">
      <td><code>version</code></td>
      <td>
        String; optional
        <p>
          A version to inject in the cargo environment variable.
        </p>
      </td>
    </tr>
  </tbody>
</table>


<a name="#rust_toolchain"></a>
## rust_toolchain

<pre>
rust_toolchain(<a href="#rust_toolchain-name">name</a>, <a href="#rust_toolchain-debug_info">debug_info</a>, <a href="#rust_toolchain-default_edition">default_edition</a>, <a href="#rust_toolchain-dylib_ext">dylib_ext</a>, <a href="#rust_toolchain-exec_triple">exec_triple</a>, <a href="#rust_toolchain-opt_level">opt_level</a>, <a href="#rust_toolchain-os">os</a>, <a href="#rust_toolchain-rust_doc">rust_doc</a>, <a href="#rust_toolchain-rust_lib">rust_lib</a>, <a href="#rust_toolchain-rustc">rustc</a>, <a href="#rust_toolchain-rustc_lib">rustc_lib</a>, <a href="#rust_toolchain-staticlib_ext">staticlib_ext</a>, <a href="#rust_toolchain-target_triple">target_triple</a>)
</pre>


Declares a Rust toolchain for use.

This is for declaring a custom toolchain, eg. for configuring a particular version of rust or supporting a new platform.

Example:

Suppose the core rust team has ported the compiler to a new target CPU, called `cpuX`. This
support can be used in Bazel by defining a new toolchain definition and declaration:

```python
load('@io_bazel_rules_rust//rust:toolchain.bzl', 'rust_toolchain')

rust_toolchain(
  name = "rust_cpuX_impl",
  rustc = "@rust_cpuX//:rustc",
  rustc_lib = "@rust_cpuX//:rustc_lib",
  rust_lib = "@rust_cpuX//:rust_lib",
  rust_doc = "@rust_cpuX//:rustdoc",
  staticlib_ext = ".a",
  dylib_ext = ".so",
  os = "linux",
)

toolchain(
  name = "rust_cpuX",
  exec_compatible_with = [
    "@bazel_tools//platforms:cpuX",
  ],
  target_compatible_with = [
    "@bazel_tools//platforms:cpuX",
  ],
  toolchain = ":rust_cpuX_impl",
)
```

Then, either add the label of the toolchain rule to `register_toolchains` in the WORKSPACE, or pass
it to the `"--extra_toolchains"` flag for Bazel, and it will be used.

See @io_bazel_rules_rust//rust:repositories.bzl for examples of defining the @rust_cpuX repository
with the actual binaries and libraries.


### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="rust_toolchain-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="rust_toolchain-debug_info">
      <td><code>debug_info</code></td>
      <td>
        <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a>; optional
      </td>
    </tr>
    <tr id="rust_toolchain-default_edition">
      <td><code>default_edition</code></td>
      <td>
        String; optional
        <p>
          The edition to use for rust_* rules that don't specify an edition.
        </p>
      </td>
    </tr>
    <tr id="rust_toolchain-dylib_ext">
      <td><code>dylib_ext</code></td>
      <td>
        String; required
      </td>
    </tr>
    <tr id="rust_toolchain-exec_triple">
      <td><code>exec_triple</code></td>
      <td>
        String; optional
      </td>
    </tr>
    <tr id="rust_toolchain-opt_level">
      <td><code>opt_level</code></td>
      <td>
        <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a>; optional
      </td>
    </tr>
    <tr id="rust_toolchain-os">
      <td><code>os</code></td>
      <td>
        String; required
      </td>
    </tr>
    <tr id="rust_toolchain-rust_doc">
      <td><code>rust_doc</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
        <p>
          The location of the `rustdoc` binary. Can be a direct source or a filegroup containing one item.
        </p>
      </td>
    </tr>
    <tr id="rust_toolchain-rust_lib">
      <td><code>rust_lib</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
        <p>
          The rust standard library.
        </p>
      </td>
    </tr>
    <tr id="rust_toolchain-rustc">
      <td><code>rustc</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
        <p>
          The location of the `rustc` binary. Can be a direct source or a filegroup containing one item.
        </p>
      </td>
    </tr>
    <tr id="rust_toolchain-rustc_lib">
      <td><code>rustc_lib</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
        <p>
          The libraries used by rustc during compilation.
        </p>
      </td>
    </tr>
    <tr id="rust_toolchain-staticlib_ext">
      <td><code>staticlib_ext</code></td>
      <td>
        String; required
      </td>
    </tr>
    <tr id="rust_toolchain-target_triple">
      <td><code>target_triple</code></td>
      <td>
        String; optional
      </td>
    </tr>
  </tbody>
</table>


