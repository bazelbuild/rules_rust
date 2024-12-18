<!-- Generated with Stardoc: http://skydoc.bazel.build -->

# Rust Toolchains

Toolchain rules for Rust.


## Rules

- [rust_analyzer_toolchain](#rust_analyzer_toolchain)
- [rust_toolchain](#rust_toolchain)
- [rustfmt_toolchain](#rustfmt_toolchain)


<a id="rust_analyzer_toolchain"></a>

## rust_analyzer_toolchain

<pre>
load("@rules_rust//rust:toolchain.bzl", "rust_analyzer_toolchain")

rust_analyzer_toolchain(<a href="#rust_analyzer_toolchain-name">name</a>, <a href="#rust_analyzer_toolchain-proc_macro_srv">proc_macro_srv</a>, <a href="#rust_analyzer_toolchain-rustc">rustc</a>, <a href="#rust_analyzer_toolchain-rustc_srcs">rustc_srcs</a>)
</pre>

A toolchain for [rust-analyzer](https://rust-analyzer.github.io/).

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_analyzer_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="rust_analyzer_toolchain-proc_macro_srv"></a>proc_macro_srv |  The path to a `rust_analyzer_proc_macro_srv` binary.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="rust_analyzer_toolchain-rustc"></a>rustc |  The path to a `rustc` binary.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="rust_analyzer_toolchain-rustc_srcs"></a>rustc_srcs |  The source code of rustc.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


<a id="rust_toolchain"></a>

## rust_toolchain

<pre>
load("@rules_rust//rust:toolchain.bzl", "rust_toolchain")

rust_toolchain(<a href="#rust_toolchain-name">name</a>, <a href="#rust_toolchain-allocator_library">allocator_library</a>, <a href="#rust_toolchain-binary_ext">binary_ext</a>, <a href="#rust_toolchain-cargo">cargo</a>, <a href="#rust_toolchain-cargo_clippy">cargo_clippy</a>, <a href="#rust_toolchain-clippy_driver">clippy_driver</a>, <a href="#rust_toolchain-debug_info">debug_info</a>,
               <a href="#rust_toolchain-default_edition">default_edition</a>, <a href="#rust_toolchain-dylib_ext">dylib_ext</a>, <a href="#rust_toolchain-env">env</a>, <a href="#rust_toolchain-exec_triple">exec_triple</a>, <a href="#rust_toolchain-experimental_link_std_dylib">experimental_link_std_dylib</a>,
               <a href="#rust_toolchain-experimental_use_cc_common_link">experimental_use_cc_common_link</a>, <a href="#rust_toolchain-extra_exec_rustc_flags">extra_exec_rustc_flags</a>, <a href="#rust_toolchain-extra_rustc_flags">extra_rustc_flags</a>,
               <a href="#rust_toolchain-extra_rustc_flags_for_crate_types">extra_rustc_flags_for_crate_types</a>, <a href="#rust_toolchain-global_allocator_library">global_allocator_library</a>, <a href="#rust_toolchain-llvm_cov">llvm_cov</a>, <a href="#rust_toolchain-llvm_profdata">llvm_profdata</a>,
               <a href="#rust_toolchain-llvm_tools">llvm_tools</a>, <a href="#rust_toolchain-opt_level">opt_level</a>, <a href="#rust_toolchain-per_crate_rustc_flags">per_crate_rustc_flags</a>, <a href="#rust_toolchain-rust_doc">rust_doc</a>, <a href="#rust_toolchain-rust_std">rust_std</a>, <a href="#rust_toolchain-rustc">rustc</a>, <a href="#rust_toolchain-rustc_lib">rustc_lib</a>,
               <a href="#rust_toolchain-rustfmt">rustfmt</a>, <a href="#rust_toolchain-staticlib_ext">staticlib_ext</a>, <a href="#rust_toolchain-stdlib_linkflags">stdlib_linkflags</a>, <a href="#rust_toolchain-strip_level">strip_level</a>, <a href="#rust_toolchain-target_json">target_json</a>, <a href="#rust_toolchain-target_triple">target_triple</a>)
</pre>

Declares a Rust toolchain for use.

This is for declaring a custom toolchain, eg. for configuring a particular version of rust or supporting a new platform.

Example:

Suppose the core rust team has ported the compiler to a new target CPU, called `cpuX`. This support can be used in Bazel by defining a new toolchain definition and declaration:

```python
load('@rules_rust//rust:toolchain.bzl', 'rust_toolchain')

rust_toolchain(
    name = "rust_cpuX_impl",
    binary_ext = "",
    dylib_ext = ".so",
    exec_triple = "cpuX-unknown-linux-gnu",
    rust_doc = "@rust_cpuX//:rustdoc",
    rust_std = "@rust_cpuX//:rust_std",
    rustc = "@rust_cpuX//:rustc",
    rustc_lib = "@rust_cpuX//:rustc_lib",
    staticlib_ext = ".a",
    stdlib_linkflags = ["-lpthread", "-ldl"],
    target_triple = "cpuX-unknown-linux-gnu",
)

toolchain(
    name = "rust_cpuX",
    exec_compatible_with = [
        "@platforms//cpu:cpuX",
        "@platforms//os:linux",
    ],
    target_compatible_with = [
        "@platforms//cpu:cpuX",
        "@platforms//os:linux",
    ],
    toolchain = ":rust_cpuX_impl",
)
```

Then, either add the label of the toolchain rule to `register_toolchains` in the WORKSPACE, or pass it to the `"--extra_toolchains"` flag for Bazel, and it will be used.

See `@rules_rust//rust:repositories.bzl` for examples of defining the `@rust_cpuX` repository with the actual binaries and libraries.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="rust_toolchain-allocator_library"></a>allocator_library |  Target that provides allocator functions when rust_library targets are embedded in a cc_binary.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `"@rules_rust//ffi/cc/allocator_library"`  |
| <a id="rust_toolchain-binary_ext"></a>binary_ext |  The extension for binaries created from rustc.   | String | required |  |
| <a id="rust_toolchain-cargo"></a>cargo |  The location of the `cargo` binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="rust_toolchain-cargo_clippy"></a>cargo_clippy |  The location of the `cargo_clippy` binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="rust_toolchain-clippy_driver"></a>clippy_driver |  The location of the `clippy-driver` binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="rust_toolchain-debug_info"></a>debug_info |  Rustc debug info levels per opt level   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{"dbg": "2", "fastbuild": "0", "opt": "0"}`  |
| <a id="rust_toolchain-default_edition"></a>default_edition |  The edition to use for rust_* rules that don't specify an edition. If absent, every rule is required to specify its `edition` attribute.   | String | optional |  `""`  |
| <a id="rust_toolchain-dylib_ext"></a>dylib_ext |  The extension for dynamic libraries created from rustc.   | String | required |  |
| <a id="rust_toolchain-env"></a>env |  Environment variables to set in actions.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="rust_toolchain-exec_triple"></a>exec_triple |  The platform triple for the toolchains execution environment. For more details see: https://docs.bazel.build/versions/master/skylark/rules.html#configurations   | String | required |  |
| <a id="rust_toolchain-experimental_link_std_dylib"></a>experimental_link_std_dylib |  Label to a boolean build setting that controls whether whether to link libstd dynamically.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `"@rules_rust//rust/settings:experimental_link_std_dylib"`  |
| <a id="rust_toolchain-experimental_use_cc_common_link"></a>experimental_use_cc_common_link |  Label to a boolean build setting that controls whether cc_common.link is used to link rust binaries.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `"@rules_rust//rust/settings:experimental_use_cc_common_link"`  |
| <a id="rust_toolchain-extra_exec_rustc_flags"></a>extra_exec_rustc_flags |  Extra flags to pass to rustc in exec configuration   | List of strings | optional |  `[]`  |
| <a id="rust_toolchain-extra_rustc_flags"></a>extra_rustc_flags |  Extra flags to pass to rustc in non-exec configuration. Subject to location expansion with respect to the srcs of the `rust_std` attribute.   | List of strings | optional |  `[]`  |
| <a id="rust_toolchain-extra_rustc_flags_for_crate_types"></a>extra_rustc_flags_for_crate_types |  Extra flags to pass to rustc based on crate type   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> List of strings</a> | optional |  `{}`  |
| <a id="rust_toolchain-global_allocator_library"></a>global_allocator_library |  Target that provides allocator functions for when a global allocator is present.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `"@rules_rust//ffi/cc/global_allocator_library"`  |
| <a id="rust_toolchain-llvm_cov"></a>llvm_cov |  The location of the `llvm-cov` binary. Can be a direct source or a filegroup containing one item. If None, rust code is not instrumented for coverage.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="rust_toolchain-llvm_profdata"></a>llvm_profdata |  The location of the `llvm-profdata` binary. Can be a direct source or a filegroup containing one item. If `llvm_cov` is None, this can be None as well and rust code is not instrumented for coverage.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="rust_toolchain-llvm_tools"></a>llvm_tools |  LLVM tools that are shipped with the Rust toolchain.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="rust_toolchain-opt_level"></a>opt_level |  Rustc optimization levels.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{"dbg": "0", "fastbuild": "0", "opt": "3"}`  |
| <a id="rust_toolchain-per_crate_rustc_flags"></a>per_crate_rustc_flags |  Extra flags to pass to rustc in non-exec configuration   | List of strings | optional |  `[]`  |
| <a id="rust_toolchain-rust_doc"></a>rust_doc |  The location of the `rustdoc` binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="rust_toolchain-rust_std"></a>rust_std |  The Rust standard library.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="rust_toolchain-rustc"></a>rustc |  The location of the `rustc` binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="rust_toolchain-rustc_lib"></a>rustc_lib |  The libraries used by rustc during compilation.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="rust_toolchain-rustfmt"></a>rustfmt |  **Deprecated**: Instead see [rustfmt_toolchain](#rustfmt_toolchain)   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="rust_toolchain-staticlib_ext"></a>staticlib_ext |  The extension for static libraries created from rustc.   | String | required |  |
| <a id="rust_toolchain-stdlib_linkflags"></a>stdlib_linkflags |  Additional linker flags to use when Rust standard library is linked by a C++ linker (rustc will deal with these automatically). Subject to location expansion with respect to the srcs of the `rust_std` attribute.   | List of strings | required |  |
| <a id="rust_toolchain-strip_level"></a>strip_level |  Rustc strip levels. For all potential options, see https://doc.rust-lang.org/rustc/codegen-options/index.html#strip   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{"dbg": "none", "fastbuild": "none", "opt": "debuginfo"}`  |
| <a id="rust_toolchain-target_json"></a>target_json |  Override the target_triple with a custom target specification. For more details see: https://doc.rust-lang.org/rustc/targets/custom.html   | String | optional |  `""`  |
| <a id="rust_toolchain-target_triple"></a>target_triple |  The platform triple for the toolchains target environment. For more details see: https://docs.bazel.build/versions/master/skylark/rules.html#configurations   | String | optional |  `""`  |


<a id="rustfmt_toolchain"></a>

## rustfmt_toolchain

<pre>
load("@rules_rust//rust:toolchain.bzl", "rustfmt_toolchain")

rustfmt_toolchain(<a href="#rustfmt_toolchain-name">name</a>, <a href="#rustfmt_toolchain-rustc">rustc</a>, <a href="#rustfmt_toolchain-rustc_lib">rustc_lib</a>, <a href="#rustfmt_toolchain-rustfmt">rustfmt</a>)
</pre>

A toolchain for [rustfmt](https://rust-lang.github.io/rustfmt/)

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rustfmt_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="rustfmt_toolchain-rustc"></a>rustc |  The location of the `rustc` binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="rustfmt_toolchain-rustc_lib"></a>rustc_lib |  The libraries used by rustc during compilation.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="rustfmt_toolchain-rustfmt"></a>rustfmt |  The location of the `rustfmt` binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


