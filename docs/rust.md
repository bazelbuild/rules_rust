# Rust rules
* [rust_library](#rust_library)
* [rust_binary](#rust_binary)
* [rust_benchmark](#rust_benchmark)
* [rust_test](#rust_test)

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


