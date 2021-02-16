# Rust rules
* [rust_clippy](#rust_clippy)
* [rust_clippy_aspect](#rust_clippy_aspect)

<a id="#rust_clippy"></a>

## rust_clippy

<pre>
rust_clippy(<a href="#rust_clippy-name">name</a>, <a href="#rust_clippy-deps">deps</a>)
</pre>

Executes the clippy checker on a specific target.

Similar to `rust_clippy_aspect`, but allows specifying a list of dependencies within the build system.

For example, given the following example targets:

```python
package(default_visibility = ["//visibility:public"])

load("@rules_rust//rust:rust.bzl", "rust_library", "rust_test")

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

Rust clippy can be set as a build target with the following:

```python
rust_clippy(
    name = "hello_library_clippy",
    testonly = True,
    deps = [
        ":hello_lib",
        ":greeting_test",
    ],
)
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_clippy-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_clippy-deps"></a>deps |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |


