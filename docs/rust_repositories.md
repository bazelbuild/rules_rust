<!-- Generated with Stardoc: http://skydoc.bazel.build -->
# Rust Repositories

* [rules_rust_dependencies](#rules_rust_dependencies)
* [rust_register_toolchains](#rust_register_toolchains)
* [rust_repositories](#rust_repositories)
* [rust_repository_set](#rust_repository_set)
* [rust_stdlib_filegroup](#rust_stdlib_filegroup)
* [rust_toolchain_repository_proxy](#rust_toolchain_repository_proxy)
* [rust_toolchain_repository](#rust_toolchain_repository)
* [rust_toolchain_tools_repository](#rust_toolchain_tools_repository)
* [rust_toolchain](#rust_toolchain)

<a id="rust_stdlib_filegroup"></a>

## rust_stdlib_filegroup

<pre>
rust_stdlib_filegroup(<a href="#rust_stdlib_filegroup-name">name</a>, <a href="#rust_stdlib_filegroup-srcs">srcs</a>)
</pre>

A dedicated filegroup-like rule for Rust stdlib artifacts.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_stdlib_filegroup-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_stdlib_filegroup-srcs"></a>srcs |  The list of targets/files that are components of the rust-stdlib file group   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |


<a id="rust_toolchain"></a>

## rust_toolchain

<pre>
rust_toolchain(<a href="#rust_toolchain-name">name</a>, <a href="#rust_toolchain-allocator_library">allocator_library</a>, <a href="#rust_toolchain-binary_ext">binary_ext</a>, <a href="#rust_toolchain-cargo">cargo</a>, <a href="#rust_toolchain-clippy_driver">clippy_driver</a>, <a href="#rust_toolchain-debug_info">debug_info</a>,
               <a href="#rust_toolchain-default_edition">default_edition</a>, <a href="#rust_toolchain-dylib_ext">dylib_ext</a>, <a href="#rust_toolchain-env">env</a>, <a href="#rust_toolchain-exec_triple">exec_triple</a>, <a href="#rust_toolchain-experimental_use_cc_common_link">experimental_use_cc_common_link</a>,
               <a href="#rust_toolchain-llvm_cov">llvm_cov</a>, <a href="#rust_toolchain-llvm_profdata">llvm_profdata</a>, <a href="#rust_toolchain-llvm_tools">llvm_tools</a>, <a href="#rust_toolchain-opt_level">opt_level</a>, <a href="#rust_toolchain-os">os</a>, <a href="#rust_toolchain-rust_doc">rust_doc</a>, <a href="#rust_toolchain-rust_lib">rust_lib</a>, <a href="#rust_toolchain-rust_std">rust_std</a>,
               <a href="#rust_toolchain-rustc">rustc</a>, <a href="#rust_toolchain-rustc_lib">rustc_lib</a>, <a href="#rust_toolchain-rustc_srcs">rustc_srcs</a>, <a href="#rust_toolchain-rustfmt">rustfmt</a>, <a href="#rust_toolchain-staticlib_ext">staticlib_ext</a>, <a href="#rust_toolchain-stdlib_linkflags">stdlib_linkflags</a>, <a href="#rust_toolchain-target_json">target_json</a>,
               <a href="#rust_toolchain-target_triple">target_triple</a>)
</pre>

Declares a Rust toolchain for use.

This is for declaring a custom toolchain, eg. for configuring a particular version of rust or supporting a new platform.

Example:

Suppose the core rust team has ported the compiler to a new target CPU, called `cpuX`. This support can be used in Bazel by defining a new toolchain definition and declaration:

```python
load('@rules_rust//rust:toolchain.bzl', 'rust_toolchain')

rust_toolchain(
    name = "rust_cpuX_impl",
    rustc = "@rust_cpuX//:rustc",
    rustc_lib = "@rust_cpuX//:rustc_lib",
    rust_std = "@rust_cpuX//:rust_std",
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

See @rules_rust//rust:repositories.bzl for examples of defining the @rust_cpuX repository with the actual binaries and libraries.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_toolchain-allocator_library"></a>allocator_library |  Target that provides allocator functions when rust_library targets are embedded in a cc_binary.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-binary_ext"></a>binary_ext |  The extension for binaries created from rustc.   | String | required |  |
| <a id="rust_toolchain-cargo"></a>cargo |  The location of the <code>cargo</code> binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-clippy_driver"></a>clippy_driver |  The location of the <code>clippy-driver</code> binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-debug_info"></a>debug_info |  Rustc debug info levels per opt level   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {"dbg": "2", "fastbuild": "0", "opt": "0"} |
| <a id="rust_toolchain-default_edition"></a>default_edition |  The edition to use for rust_* rules that don't specify an edition. If absent, every rule is required to specify its <code>edition</code> attribute.   | String | optional | "" |
| <a id="rust_toolchain-dylib_ext"></a>dylib_ext |  The extension for dynamic libraries created from rustc.   | String | required |  |
| <a id="rust_toolchain-env"></a>env |  Environment variables to set in actions.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="rust_toolchain-exec_triple"></a>exec_triple |  The platform triple for the toolchains execution environment. For more details see: https://docs.bazel.build/versions/master/skylark/rules.html#configurations   | String | required |  |
| <a id="rust_toolchain-experimental_use_cc_common_link"></a>experimental_use_cc_common_link |  Label to a boolean build setting that controls whether cc_common.link is used to link rust binaries.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //rust/settings:experimental_use_cc_common_link |
| <a id="rust_toolchain-llvm_cov"></a>llvm_cov |  The location of the <code>llvm-cov</code> binary. Can be a direct source or a filegroup containing one item. If None, rust code is not instrumented for coverage.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-llvm_profdata"></a>llvm_profdata |  The location of the <code>llvm-profdata</code> binary. Can be a direct source or a filegroup containing one item. If <code>llvm_cov</code> is None, this can be None as well and rust code is not instrumented for coverage.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-llvm_tools"></a>llvm_tools |  LLVM tools that are shipped with the Rust toolchain.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-opt_level"></a>opt_level |  Rustc optimization levels.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {"dbg": "0", "fastbuild": "0", "opt": "3"} |
| <a id="rust_toolchain-os"></a>os |  The operating system for the current toolchain   | String | required |  |
| <a id="rust_toolchain-rust_doc"></a>rust_doc |  The location of the <code>rustdoc</code> binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="rust_toolchain-rust_lib"></a>rust_lib |  **Deprecated**: Use <code>rust_std</code>   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-rust_std"></a>rust_std |  The Rust standard library.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-rustc"></a>rustc |  The location of the <code>rustc</code> binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="rust_toolchain-rustc_lib"></a>rustc_lib |  The libraries used by rustc during compilation.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-rustc_srcs"></a>rustc_srcs |  The source code of rustc.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-rustfmt"></a>rustfmt |  The location of the <code>rustfmt</code> binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-staticlib_ext"></a>staticlib_ext |  The extension for static libraries created from rustc.   | String | required |  |
| <a id="rust_toolchain-stdlib_linkflags"></a>stdlib_linkflags |  Additional linker flags to use when Rust standard library is linked by a C++ linker (rustc will deal with these automatically). Subject to location expansion with respect to the srcs of the <code>rust_std</code> attribute.   | List of strings | required |  |
| <a id="rust_toolchain-target_json"></a>target_json |  Override the target_triple with a custom target specification. For more details see: https://doc.rust-lang.org/rustc/targets/custom.html   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-target_triple"></a>target_triple |  The platform triple for the toolchains target environment. For more details see: https://docs.bazel.build/versions/master/skylark/rules.html#configurations   | String | optional | "" |


<a id="rust_toolchain_repository_proxy"></a>

## rust_toolchain_repository_proxy

<pre>
rust_toolchain_repository_proxy(<a href="#rust_toolchain_repository_proxy-name">name</a>, <a href="#rust_toolchain_repository_proxy-exec_compatible_with">exec_compatible_with</a>, <a href="#rust_toolchain_repository_proxy-repo_mapping">repo_mapping</a>, <a href="#rust_toolchain_repository_proxy-target_compatible_with">target_compatible_with</a>,
                                <a href="#rust_toolchain_repository_proxy-toolchain">toolchain</a>, <a href="#rust_toolchain_repository_proxy-toolchain_type">toolchain_type</a>)
</pre>

Generates a toolchain-bearing repository that declares the toolchains from some other rust_toolchain_repository.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_toolchain_repository_proxy-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_toolchain_repository_proxy-exec_compatible_with"></a>exec_compatible_with |  A list of constraints for the execution platform for this toolchain.   | List of strings | optional | [] |
| <a id="rust_toolchain_repository_proxy-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | required |  |
| <a id="rust_toolchain_repository_proxy-target_compatible_with"></a>target_compatible_with |  A list of constraints for the target platform for this toolchain.   | List of strings | optional | [] |
| <a id="rust_toolchain_repository_proxy-toolchain"></a>toolchain |  The name of the toolchain implementation target.   | String | required |  |
| <a id="rust_toolchain_repository_proxy-toolchain_type"></a>toolchain_type |  The toolchain type of the toolchain to declare   | String | required |  |


<a id="rust_toolchain_tools_repository"></a>

## rust_toolchain_tools_repository

<pre>
rust_toolchain_tools_repository(<a href="#rust_toolchain_tools_repository-name">name</a>, <a href="#rust_toolchain_tools_repository-allocator_library">allocator_library</a>, <a href="#rust_toolchain_tools_repository-auth">auth</a>, <a href="#rust_toolchain_tools_repository-dev_components">dev_components</a>, <a href="#rust_toolchain_tools_repository-edition">edition</a>, <a href="#rust_toolchain_tools_repository-exec_triple">exec_triple</a>,
                                <a href="#rust_toolchain_tools_repository-include_rustc_srcs">include_rustc_srcs</a>, <a href="#rust_toolchain_tools_repository-iso_date">iso_date</a>, <a href="#rust_toolchain_tools_repository-repo_mapping">repo_mapping</a>, <a href="#rust_toolchain_tools_repository-rustfmt_version">rustfmt_version</a>, <a href="#rust_toolchain_tools_repository-sha256s">sha256s</a>,
                                <a href="#rust_toolchain_tools_repository-target_triple">target_triple</a>, <a href="#rust_toolchain_tools_repository-urls">urls</a>, <a href="#rust_toolchain_tools_repository-version">version</a>)
</pre>

Composes a single workspace containing the toolchain components for compiling on a given platform to a series of target platforms.

A given instance of this rule should be accompanied by a toolchain_repository_proxy invocation to declare its toolchains to Bazel; the indirection allows separating toolchain selection from toolchain fetching.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_toolchain_tools_repository-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_toolchain_tools_repository-allocator_library"></a>allocator_library |  Target that provides allocator functions when rust_library targets are embedded in a cc_binary.   | String | optional | "" |
| <a id="rust_toolchain_tools_repository-auth"></a>auth |  Auth object compatible with repository_ctx.download to use when downloading files. See [repository_ctx.download](https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download) for more details.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="rust_toolchain_tools_repository-dev_components"></a>dev_components |  Whether to download the rustc-dev components (defaults to False). Requires version to be "nightly".   | Boolean | optional | False |
| <a id="rust_toolchain_tools_repository-edition"></a>edition |  The rust edition to be used by default (2015, 2018, or 2021). If absent, every rule is required to specify its <code>edition</code> attribute.   | String | optional | "" |
| <a id="rust_toolchain_tools_repository-exec_triple"></a>exec_triple |  The Rust-style target that this compiler runs on   | String | required |  |
| <a id="rust_toolchain_tools_repository-include_rustc_srcs"></a>include_rustc_srcs |  Whether to download and unpack the rustc source files. These are very large, and slow to unpack, but are required to support rust analyzer. An environment variable <code>RULES_RUST_TOOLCHAIN_INCLUDE_RUSTC_SRCS</code> can also be used to control this attribute. This variable will take precedence over the hard coded attribute. Setting it to <code>true</code> to activates this attribute where all other values deactivate it.   | Boolean | optional | False |
| <a id="rust_toolchain_tools_repository-iso_date"></a>iso_date |  The date of the tool (or None, if the version is a specific version).   | String | optional | "" |
| <a id="rust_toolchain_tools_repository-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | required |  |
| <a id="rust_toolchain_tools_repository-rustfmt_version"></a>rustfmt_version |  The version of the tool among "nightly", "beta", or an exact version.   | String | optional | "" |
| <a id="rust_toolchain_tools_repository-sha256s"></a>sha256s |  A dict associating tool subdirectories to sha256 hashes. See [rust_repositories](#rust_repositories) for more details.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="rust_toolchain_tools_repository-target_triple"></a>target_triple |  The Rust-style target that this compiler builds for   | String | required |  |
| <a id="rust_toolchain_tools_repository-urls"></a>urls |  A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format).   | List of strings | optional | ["https://static.rust-lang.org/dist/{}.tar.gz"] |
| <a id="rust_toolchain_tools_repository-version"></a>version |  The version of the tool among "nightly", "beta", or an exact version.   | String | required |  |


<a id="rules_rust_dependencies"></a>

## rules_rust_dependencies

<pre>
rules_rust_dependencies()
</pre>

Dependencies used in the implementation of `rules_rust`.



<a id="rust_register_toolchains"></a>

## rust_register_toolchains

<pre>
rust_register_toolchains(<a href="#rust_register_toolchains-dev_components">dev_components</a>, <a href="#rust_register_toolchains-edition">edition</a>, <a href="#rust_register_toolchains-include_rustc_srcs">include_rustc_srcs</a>, <a href="#rust_register_toolchains-allocator_library">allocator_library</a>, <a href="#rust_register_toolchains-iso_date">iso_date</a>,
                         <a href="#rust_register_toolchains-register_toolchains">register_toolchains</a>, <a href="#rust_register_toolchains-rustfmt_version">rustfmt_version</a>, <a href="#rust_register_toolchains-sha256s">sha256s</a>, <a href="#rust_register_toolchains-extra_target_triples">extra_target_triples</a>, <a href="#rust_register_toolchains-urls">urls</a>,
                         <a href="#rust_register_toolchains-version">version</a>)
</pre>

Emits a default set of toolchains for Linux, MacOS, and Freebsd

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

See `load_arbitrary_tool` in `@rules_rust//rust:repositories.bzl` for more details.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rust_register_toolchains-dev_components"></a>dev_components |  Whether to download the rustc-dev components (defaults to False). Requires version to be "nightly".   |  <code>False</code> |
| <a id="rust_register_toolchains-edition"></a>edition |  The rust edition to be used by default (2015, 2018, or 2021). If absent, every target is required to specify its <code>edition</code> attribute.   |  <code>None</code> |
| <a id="rust_register_toolchains-include_rustc_srcs"></a>include_rustc_srcs |  Whether to download rustc's src code. This is required in order to use rust-analyzer support. See [rust_toolchain_repository.include_rustc_srcs](#rust_toolchain_repository-include_rustc_srcs). for more details   |  <code>False</code> |
| <a id="rust_register_toolchains-allocator_library"></a>allocator_library |  Target that provides allocator functions when rust_library targets are embedded in a cc_binary.   |  <code>None</code> |
| <a id="rust_register_toolchains-iso_date"></a>iso_date |  The date of the nightly or beta release (ignored if the version is a specific version).   |  <code>None</code> |
| <a id="rust_register_toolchains-register_toolchains"></a>register_toolchains |  If true, repositories will be generated to produce and register <code>rust_toolchain</code> targets.   |  <code>True</code> |
| <a id="rust_register_toolchains-rustfmt_version"></a>rustfmt_version |  The version of rustfmt. Either "nightly", "beta", or an exact version. Defaults to <code>version</code> if not specified.   |  <code>None</code> |
| <a id="rust_register_toolchains-sha256s"></a>sha256s |  A dict associating tool subdirectories to sha256 hashes.   |  <code>None</code> |
| <a id="rust_register_toolchains-extra_target_triples"></a>extra_target_triples |  Additional rust-style targets that rust toolchains should support.   |  <code>["wasm32-unknown-unknown", "wasm32-wasi"]</code> |
| <a id="rust_register_toolchains-urls"></a>urls |  A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format).   |  <code>["https://static.rust-lang.org/dist/{}.tar.gz"]</code> |
| <a id="rust_register_toolchains-version"></a>version |  The version of Rust. Either "nightly", "beta", or an exact version. Defaults to a modern version.   |  <code>"1.63.0"</code> |


<a id="rust_repositories"></a>

## rust_repositories

<pre>
rust_repositories(<a href="#rust_repositories-kwargs">kwargs</a>)
</pre>

**Deprecated**: Use [rules_rust_dependencies](#rules_rust_dependencies)     and [rust_register_toolchains](#rust_register_toolchains) directly.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rust_repositories-kwargs"></a>kwargs |  Keyword arguments for the <code>rust_register_toolchains</code> macro.   |  none |


<a id="rust_repository_set"></a>

## rust_repository_set

<pre>
rust_repository_set(<a href="#rust_repository_set-name">name</a>, <a href="#rust_repository_set-version">version</a>, <a href="#rust_repository_set-exec_triple">exec_triple</a>, <a href="#rust_repository_set-include_rustc_srcs">include_rustc_srcs</a>, <a href="#rust_repository_set-allocator_library">allocator_library</a>,
                    <a href="#rust_repository_set-extra_target_triples">extra_target_triples</a>, <a href="#rust_repository_set-iso_date">iso_date</a>, <a href="#rust_repository_set-rustfmt_version">rustfmt_version</a>, <a href="#rust_repository_set-edition">edition</a>, <a href="#rust_repository_set-dev_components">dev_components</a>, <a href="#rust_repository_set-sha256s">sha256s</a>,
                    <a href="#rust_repository_set-urls">urls</a>, <a href="#rust_repository_set-auth">auth</a>, <a href="#rust_repository_set-register_toolchain">register_toolchain</a>)
</pre>

Assembles a remote repository for the given toolchain params, produces a proxy repository     to contain the toolchain declaration, and registers the toolchains.

N.B. A "proxy repository" is needed to allow for registering the toolchain (with constraints)     without actually downloading the toolchain.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rust_repository_set-name"></a>name |  The name of the generated repository   |  none |
| <a id="rust_repository_set-version"></a>version |  The version of the tool among "nightly", "beta', or an exact version.   |  none |
| <a id="rust_repository_set-exec_triple"></a>exec_triple |  The Rust-style target that this compiler runs on   |  none |
| <a id="rust_repository_set-include_rustc_srcs"></a>include_rustc_srcs |  Whether to download rustc's src code. This is required in order to use rust-analyzer support. Defaults to False.   |  <code>False</code> |
| <a id="rust_repository_set-allocator_library"></a>allocator_library |  Target that provides allocator functions when rust_library targets are embedded in a cc_binary.   |  <code>None</code> |
| <a id="rust_repository_set-extra_target_triples"></a>extra_target_triples |  Additional rust-style targets that this set of toolchains should support. Defaults to [].   |  <code>[]</code> |
| <a id="rust_repository_set-iso_date"></a>iso_date |  The date of the tool. Defaults to None.   |  <code>None</code> |
| <a id="rust_repository_set-rustfmt_version"></a>rustfmt_version |  The version of rustfmt to be associated with the toolchain. Defaults to None.   |  <code>None</code> |
| <a id="rust_repository_set-edition"></a>edition |  The rust edition to be used by default (2015, 2018, or 2021). If absent, every rule is required to specify its <code>edition</code> attribute.   |  <code>None</code> |
| <a id="rust_repository_set-dev_components"></a>dev_components |  Whether to download the rustc-dev components. Requires version to be "nightly". Defaults to False.   |  <code>False</code> |
| <a id="rust_repository_set-sha256s"></a>sha256s |  A dict associating tool subdirectories to sha256 hashes. See [rust_repositories](#rust_repositories) for more details.   |  <code>None</code> |
| <a id="rust_repository_set-urls"></a>urls |  A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format). Defaults to ['https://static.rust-lang.org/dist/{}.tar.gz']   |  <code>["https://static.rust-lang.org/dist/{}.tar.gz"]</code> |
| <a id="rust_repository_set-auth"></a>auth |  Auth object compatible with repository_ctx.download to use when downloading files. See [repository_ctx.download](https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download) for more details.   |  <code>None</code> |
| <a id="rust_repository_set-register_toolchain"></a>register_toolchain |  If True, the generated <code>rust_toolchain</code> target will become a registered toolchain.   |  <code>True</code> |


<a id="rust_toolchain_repository"></a>

## rust_toolchain_repository

<pre>
rust_toolchain_repository(<a href="#rust_toolchain_repository-name">name</a>, <a href="#rust_toolchain_repository-version">version</a>, <a href="#rust_toolchain_repository-exec_triple">exec_triple</a>, <a href="#rust_toolchain_repository-target_triple">target_triple</a>, <a href="#rust_toolchain_repository-exec_compatible_with">exec_compatible_with</a>,
                          <a href="#rust_toolchain_repository-target_compatible_with">target_compatible_with</a>, <a href="#rust_toolchain_repository-include_rustc_srcs">include_rustc_srcs</a>, <a href="#rust_toolchain_repository-allocator_library">allocator_library</a>, <a href="#rust_toolchain_repository-iso_date">iso_date</a>,
                          <a href="#rust_toolchain_repository-rustfmt_version">rustfmt_version</a>, <a href="#rust_toolchain_repository-edition">edition</a>, <a href="#rust_toolchain_repository-dev_components">dev_components</a>, <a href="#rust_toolchain_repository-sha256s">sha256s</a>, <a href="#rust_toolchain_repository-urls">urls</a>, <a href="#rust_toolchain_repository-auth">auth</a>)
</pre>

Assembles a remote repository for the given toolchain params, produces a proxy repository     to contain the toolchain declaration, and registers the toolchains.

N.B. A "proxy repository" is needed to allow for registering the toolchain (with constraints)     without actually downloading the toolchain.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rust_toolchain_repository-name"></a>name |  The name of the generated repository   |  none |
| <a id="rust_toolchain_repository-version"></a>version |  The version of the tool among "nightly", "beta', or an exact version.   |  none |
| <a id="rust_toolchain_repository-exec_triple"></a>exec_triple |  The Rust-style target that this compiler runs on.   |  none |
| <a id="rust_toolchain_repository-target_triple"></a>target_triple |  The Rust-style target to build for.   |  none |
| <a id="rust_toolchain_repository-exec_compatible_with"></a>exec_compatible_with |  A list of constraints for the execution platform for this toolchain.   |  <code>None</code> |
| <a id="rust_toolchain_repository-target_compatible_with"></a>target_compatible_with |  A list of constraints for the target platform for this toolchain.   |  <code>None</code> |
| <a id="rust_toolchain_repository-include_rustc_srcs"></a>include_rustc_srcs |  Whether to download rustc's src code. This is required in order to use rust-analyzer support.   |  <code>False</code> |
| <a id="rust_toolchain_repository-allocator_library"></a>allocator_library |  Target that provides allocator functions when rust_library targets are embedded in a cc_binary.   |  <code>None</code> |
| <a id="rust_toolchain_repository-iso_date"></a>iso_date |  The date of the tool.   |  <code>None</code> |
| <a id="rust_toolchain_repository-rustfmt_version"></a>rustfmt_version |  The version of rustfmt to be associated with the toolchain.   |  <code>None</code> |
| <a id="rust_toolchain_repository-edition"></a>edition |  The rust edition to be used by default (2015, 2018, or 2021). If absent, every rule is required to specify its <code>edition</code> attribute.   |  <code>None</code> |
| <a id="rust_toolchain_repository-dev_components"></a>dev_components |  Whether to download the rustc-dev components. Requires version to be "nightly". Defaults to False.   |  <code>False</code> |
| <a id="rust_toolchain_repository-sha256s"></a>sha256s |  A dict associating tool subdirectories to sha256 hashes. See [rust_repositories](#rust_repositories) for more details.   |  <code>None</code> |
| <a id="rust_toolchain_repository-urls"></a>urls |  A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format). Defaults to ['https://static.rust-lang.org/dist/{}.tar.gz']   |  <code>["https://static.rust-lang.org/dist/{}.tar.gz"]</code> |
| <a id="rust_toolchain_repository-auth"></a>auth |  Auth object compatible with repository_ctx.download to use when downloading files. See [repository_ctx.download](https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download) for more details.   |  <code>None</code> |

**RETURNS**

str: The name of the registerable toolchain created by this rule.


