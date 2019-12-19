# Copyright 2015 The Bazel Authors. All rights reserved.
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

load("@io_bazel_rules_rust//rust:private/rustc.bzl", "CrateInfo", "rustc_compile_action")
load("@io_bazel_rules_rust//rust:private/utils.bzl", "find_toolchain")
load("@io_bazel_rules_rust//rust:private/transitions.bzl", "proc_macro_host_transition")

_OLD_INLINE_TEST_CRATE_MSG = """
--------------------------------------------------------------------------------
Testing crates with inline `#[cfg(test)]` attributes is now handled with the
`crate` attribute in `rust_test`:

This means you should migrate from:

```
rust_test(
    name = "{name}",
    deps = ["{dep}"],
    ...
)
```

to the following:
```
rust_test(
    name = "{name}",
    crate = "{dep}",
    ...
```

See https://github.com/bazelbuild/rules_rust/pull/203 for more details
--------------------------------------------------------------------------------

"""

# TODO(marco): Separate each rule into its own file.

def _determine_output_hash(lib_rs):
    return repr(hash(lib_rs.path))

def _determine_lib_name(name, crate_type, toolchain, lib_hash = ""):
    extension = None
    if crate_type in ("dylib", "cdylib", "proc-macro"):
        extension = toolchain.dylib_ext
    elif crate_type == "staticlib":
        extension = toolchain.staticlib_ext
    elif crate_type in ("lib", "rlib"):
        # All platforms produce 'rlib' here
        extension = ".rlib"
    elif crate_type == "bin":
        fail("crate_type of 'bin' was detected in a rust_library. Please compile " +
             "this crate as a rust_binary instead.")

    if not extension:
        fail(("Unknown crate_type: {}. If this is a cargo-supported crate type, " +
              "please file an issue!").format(crate_type))

    return "lib{name}-{lib_hash}{extension}".format(
        name = name,
        lib_hash = lib_hash,
        extension = extension,
    )

def _get_edition(ctx, toolchain):
    if getattr(ctx.attr, "edition"):
        return ctx.attr.edition
    else:
        return toolchain.default_edition

def _crate_root_src(ctx, file_name = "lib.rs"):
    """Finds the source file for the crate root."""
    srcs = ctx.files.srcs
    name_to_file = {f.basename: f for f in srcs}

    crate_root = (
        ctx.file.crate_root or
        (srcs[0] if len(srcs) == 1 else None) or
        name_to_file.get(file_name) or
        name_to_file.get(ctx.attr.name + ".rs")
    )
    if not crate_root:
        file_names = [file_name, ctx.attr.name + ".rs"]
        fail("No {} source file found.".format(" or ".join(file_names)), "srcs")
    return crate_root

def _rust_library_impl(ctx):
    # Find lib.rs
    lib_rs = _crate_root_src(ctx)

    toolchain = find_toolchain(ctx)

    # Determine unique hash for this rlib
    output_hash = _determine_output_hash(lib_rs)

    rust_lib_name = _determine_lib_name(
        ctx.attr.name,
        ctx.attr.crate_type,
        toolchain,
        output_hash,
    )
    rust_lib = ctx.actions.declare_file(rust_lib_name)

    return rustc_compile_action(
        ctx = ctx,
        toolchain = toolchain,
        crate_info = CrateInfo(
            name = ctx.label.name,
            type = ctx.attr.crate_type,
            root = lib_rs,
            srcs = ctx.files.srcs,
            deps = ctx.attr.deps,
            aliases = ctx.attr.aliases,
            output = rust_lib,
            edition = _get_edition(ctx, toolchain),
        ),
        output_hash = output_hash,
    )

def _rust_binary_impl(ctx):
    toolchain = find_toolchain(ctx)

    if (toolchain.target_arch == "wasm32"):
        output = ctx.actions.declare_file(ctx.label.name + ".wasm")
    else:
        output = ctx.actions.declare_file(ctx.label.name)

    return rustc_compile_action(
        ctx = ctx,
        toolchain = toolchain,
        crate_info = CrateInfo(
            name = ctx.label.name,
            type = "bin",
            root = _crate_root_src(ctx, "main.rs"),
            srcs = ctx.files.srcs,
            deps = ctx.attr.deps,
            aliases = ctx.attr.aliases,
            output = output,
            edition = _get_edition(ctx, toolchain),
        ),
    )

def _rust_test_common(ctx, test_binary):
    """
    Builds a Rust test binary.

    Args:
        ctx: The ctx object for the current target.
        test_binary: The File object for the test binary.
    """
    toolchain = find_toolchain(ctx)

    if ctx.attr.crate:
        # Target is building the crate in `test` config
        # Build the test binary using the dependency's srcs.
        crate = ctx.attr.crate[CrateInfo]
        target = CrateInfo(
            name = test_binary.basename,
            type = crate.type,
            root = crate.root,
            srcs = crate.srcs + ctx.files.srcs,
            deps = crate.deps + ctx.attr.deps,
            aliases = ctx.attr.aliases,
            output = test_binary,
            edition = crate.edition,
        )
    elif len(ctx.attr.deps) == 1 and len(ctx.files.srcs) == 0:
        dep = ctx.attr.deps[0].label
        msg = _OLD_INLINE_TEST_CRATE_MSG.format(
            name = test_binary.basename,
            dep = dep if ctx.label.package != dep.package else ":" + dep.name,
        )
        fail(msg)
    else:
        # Target is a standalone crate. Build the test binary as its own crate.
        target = CrateInfo(
            name = test_binary.basename,
            type = "lib",
            root = _crate_root_src(ctx),
            srcs = ctx.files.srcs,
            deps = ctx.attr.deps,
            aliases = ctx.attr.aliases,
            output = test_binary,
            edition = _get_edition(ctx, toolchain),
        )

    return rustc_compile_action(
        ctx = ctx,
        toolchain = toolchain,
        crate_info = target,
        rust_flags = ["--test"],
    )

def _rust_test_impl(ctx):
    return _rust_test_common(ctx, ctx.outputs.executable)

def _rust_benchmark_impl(ctx):
    bench_script = ctx.outputs.executable

    # Build the underlying benchmark binary.
    bench_binary = ctx.actions.declare_file(
        "{}_bin".format(bench_script.basename),
        sibling = ctx.configuration.bin_dir,
    )
    info = _rust_test_common(ctx, bench_binary)

    # Wrap the benchmark to run it as cargo would.
    ctx.actions.write(
        output = bench_script,
        content = "\n".join([
            "#!/usr/bin/env bash",
            "set -e",
            "{} --bench".format(bench_binary.short_path),
        ]),
        is_executable = True,
    )

    runfiles = ctx.runfiles(
        files = info.runfiles + [bench_binary],
        collect_data = True,
    )

    return struct(runfiles = runfiles)

def _tidy(doc_string):
    """Tidy excess whitespace in docstrings to not break index.md"""
    return "\n".join([line.strip() for line in doc_string.splitlines()])

_rust_common_attrs = {
    # TODO(stardoc): How do we provide additional documentation to an inherited attribute?
    # "name": attr.string(
    #     doc = "This name will also be used as the name of the crate built by this rule.",
    # `),
    "srcs": attr.label_list(
        doc = _tidy("""
            List of Rust `.rs` source files used to build the library.

            If `srcs` contains more than one file, then there must be a file either
            named `lib.rs`. Otherwise, `crate_root` must be set to the source file that
            is the root of the crate to be passed to rustc to build this crate.
        """),
        allow_files = [".rs"],
    ),
    "crate_root": attr.label(
        doc = _tidy("""
            The file that will be passed to `rustc` to be used for building this crate.

            If `crate_root` is not set, then this rule will look for a `lib.rs` file (or `main.rs` for rust_binary)
            or the single file in `srcs` if `srcs` contains only one file.
        """),
        allow_single_file = [".rs"],
    ),
    "data": attr.label_list(
        doc = _tidy("""
            List of files used by this rule at runtime.

            This attribute can be used to specify any data files that are embedded into
            the library, such as via the
            [`include_str!`](https://doc.rust-lang.org/std/macro.include_str!.html)
            macro.
        """),
        allow_files = True,
    ),
    "deps": attr.label_list(
        doc = _tidy("""
            List of other libraries to be linked to this library target.

            These can be either other `rust_library` targets or `cc_library` targets if
            linking a native library.
        """),
    ),
    "aliases": attr.label_keyed_string_dict(
        doc = _tidy("""
            Remap crates to a new name or moniker for linkage to this target

            These are other `rust_library` targets and will be presented as the new name given.
        """),
    ),
    "crate_features": attr.string_list(
        doc = _tidy("""
            List of features to enable for this crate.

            Features are defined in the code using the `#[cfg(feature = "foo")]`
            configuration option. The features listed here will be passed to `rustc`
            with `--cfg feature="${feature_name}"` flags.
        """),
    ),
    "edition": attr.string(
        doc = "The rust edition to use for this crate. Defaults to the edition specified in the rust_toolchain.",
    ),
    "rustc_flags": attr.string_list(
        doc = "List of compiler flags passed to `rustc`.",
    ),
    "version": attr.string(
        doc = "A version to inject in the cargo environment variable.",
        default = "0.0.0",
    ),
    "out_dir_tar": attr.label(
        doc = _tidy("""
            An optional tar or tar.gz file unpacked and passed as OUT_DIR.

            Many library crates in the Rust ecosystem require sources to be provided
            to them in the form of an OUT_DIR argument. This argument can be used to
            supply the contents of this directory.
        """),
        allow_single_file = [
            ".tar",
            ".tar.gz",
        ],
    ),
    "_cc_toolchain": attr.label(default = "@bazel_tools//tools/cpp:current_cc_toolchain"),
}

_rust_library_attrs = {
    "crate_type": attr.string(
        doc = _tidy("""
            The type of linkage to use for building this library.
            Options include "lib", "rlib", "dylib", "cdylib", "staticlib", and "proc-macro".

            The exact output file will depend on the toolchain used.
        """),
        default = "rlib",
    ),
    "_whitelist_function_transition": attr.label(
        default = "//tools/whitelists/function_transition_whitelist",
    ),
}

_rust_test_attrs = {
    "crate": attr.label(
        mandatory = False,
        doc = _tidy("""
            Target inline tests declared in the given crate

            These tests are typically those that would be held out under
            `#[cfg(test)]` declarations.
        """),
    ),
}

rust_library = rule(
    _rust_library_impl,
    attrs = dict(_rust_common_attrs.items() +
                 _rust_library_attrs.items()),
    fragments = ["cpp"],
    host_fragments = ["cpp"],
    cfg = proc_macro_host_transition,
    toolchains = [
        "@io_bazel_rules_rust//rust:toolchain",
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    doc = """
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
""",
)

_rust_binary_attrs = {
    "linker_script": attr.label(
        doc = _tidy("""
            Link script to forward into linker via rustc options.
        """),
        cfg = "host",
        allow_single_file = True,
    ),
}

rust_binary = rule(
    _rust_binary_impl,
    attrs = dict(_rust_common_attrs.items() + _rust_binary_attrs.items()),
    executable = True,
    fragments = ["cpp"],
    host_fragments = ["cpp"],
    toolchains = [
        "@io_bazel_rules_rust//rust:toolchain",
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    doc = """
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
""",
)

rust_test = rule(
    _rust_test_impl,
    attrs = dict(_rust_common_attrs.items() +
                 _rust_test_attrs.items()),
    executable = True,
    fragments = ["cpp"],
    host_fragments = ["cpp"],
    test = True,
    toolchains = [
        "@io_bazel_rules_rust//rust:toolchain",
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    doc = """
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

To run a crate or lib with the `#[cfg(test)]` configuration, handling inline
tests, you should specify the crate directly like so.

```
rust_test(
    name = "hello_lib_test",
    crate = ":hello_lib",
    # You may add other deps that are specific to the test configuration
    deps = ["//some/dev/dep"],
)
```

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
""",
)

rust_benchmark = rule(
    _rust_benchmark_impl,
    attrs = _rust_common_attrs,
    executable = True,
    fragments = ["cpp"],
    host_fragments = ["cpp"],
    toolchains = [
        "@io_bazel_rules_rust//rust:toolchain",
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    doc = """
Builds a Rust benchmark test.

**Warning**: This rule is currently experimental. [Rust Benchmark
tests][rust-bench] require the `Bencher` interface in the unstable `libtest`
crate, which is behind the `test` unstable feature gate. As a result, using
this rule would require using a nightly binary release of Rust.

[rust-bench]: https://doc.rust-lang.org/book/benchmark-tests.html

Example:

Suppose you have the following directory structure for a Rust project with a
library crate, `fibonacci` with benchmarks under the `benches/` directory:

```
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

`fibonacci/BUILD`:\
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
""",
)
