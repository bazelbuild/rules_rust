<!-- Generated with Stardoc: http://skydoc.bazel.build -->
# Rust Repositories

* [rust_repositories](#rust_repositories)
* [rust_repository_set](#rust_repository_set)
* [rust_toolchain](#rust_toolchain)
* [rust_toolchain_repository](#rust_toolchain_repository)
* [rust_toolchain_repository_proxy](#rust_toolchain_repository_proxy)

<a id="#rust_toolchain"></a>

## rust_toolchain

<pre>
rust_toolchain(<a href="#rust_toolchain-name">name</a>, <a href="#rust_toolchain-allocator_library">allocator_library</a>, <a href="#rust_toolchain-binary_ext">binary_ext</a>, <a href="#rust_toolchain-cargo">cargo</a>, <a href="#rust_toolchain-clippy_driver">clippy_driver</a>, <a href="#rust_toolchain-debug_info">debug_info</a>,
               <a href="#rust_toolchain-default_edition">default_edition</a>, <a href="#rust_toolchain-dylib_ext">dylib_ext</a>, <a href="#rust_toolchain-exec_triple">exec_triple</a>, <a href="#rust_toolchain-opt_level">opt_level</a>, <a href="#rust_toolchain-os">os</a>, <a href="#rust_toolchain-rust_doc">rust_doc</a>, <a href="#rust_toolchain-rust_lib">rust_lib</a>, <a href="#rust_toolchain-rustc">rustc</a>,
               <a href="#rust_toolchain-rustc_lib">rustc_lib</a>, <a href="#rust_toolchain-rustc_srcs">rustc_srcs</a>, <a href="#rust_toolchain-rustfmt">rustfmt</a>, <a href="#rust_toolchain-staticlib_ext">staticlib_ext</a>, <a href="#rust_toolchain-stdlib_linkflags">stdlib_linkflags</a>, <a href="#rust_toolchain-target_triple">target_triple</a>)
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
| <a id="rust_toolchain-default_edition"></a>default_edition |  The edition to use for rust_* rules that don't specify an edition.   | String | optional | "2015" |
| <a id="rust_toolchain-dylib_ext"></a>dylib_ext |  The extension for dynamic libraries created from rustc.   | String | required |  |
| <a id="rust_toolchain-exec_triple"></a>exec_triple |  The platform triple for the toolchains execution environment. For more details see: https://docs.bazel.build/versions/master/skylark/rules.html#configurations   | String | optional | "" |
| <a id="rust_toolchain-opt_level"></a>opt_level |  Rustc optimization levels.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {"dbg": "0", "fastbuild": "0", "opt": "3"} |
| <a id="rust_toolchain-os"></a>os |  The operating system for the current toolchain   | String | required |  |
| <a id="rust_toolchain-rust_doc"></a>rust_doc |  The location of the <code>rustdoc</code> binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-rust_lib"></a>rust_lib |  The rust standard library.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-rustc"></a>rustc |  The location of the <code>rustc</code> binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-rustc_lib"></a>rustc_lib |  The libraries used by rustc during compilation.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-rustc_srcs"></a>rustc_srcs |  The source code of rustc.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-rustfmt"></a>rustfmt |  The location of the <code>rustfmt</code> binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_toolchain-staticlib_ext"></a>staticlib_ext |  The extension for static libraries created from rustc.   | String | required |  |
| <a id="rust_toolchain-stdlib_linkflags"></a>stdlib_linkflags |  Additional linker libs used when std lib is linked, see https://github.com/rust-lang/rust/blob/master/src/libstd/build.rs   | List of strings | required |  |
| <a id="rust_toolchain-target_triple"></a>target_triple |  The platform triple for the toolchains target environment. For more details see: https://docs.bazel.build/versions/master/skylark/rules.html#configurations   | String | optional | "" |


<a id="#rust_toolchain_repository"></a>

## rust_toolchain_repository

<pre>
rust_toolchain_repository(<a href="#rust_toolchain_repository-name">name</a>, <a href="#rust_toolchain_repository-dev_components">dev_components</a>, <a href="#rust_toolchain_repository-edition">edition</a>, <a href="#rust_toolchain_repository-exec_triple">exec_triple</a>, <a href="#rust_toolchain_repository-extra_target_triples">extra_target_triples</a>,
                          <a href="#rust_toolchain_repository-include_rustc_srcs">include_rustc_srcs</a>, <a href="#rust_toolchain_repository-iso_date">iso_date</a>, <a href="#rust_toolchain_repository-repo_mapping">repo_mapping</a>, <a href="#rust_toolchain_repository-rustfmt_version">rustfmt_version</a>, <a href="#rust_toolchain_repository-sha256s">sha256s</a>,
                          <a href="#rust_toolchain_repository-toolchain_name_prefix">toolchain_name_prefix</a>, <a href="#rust_toolchain_repository-urls">urls</a>, <a href="#rust_toolchain_repository-version">version</a>)
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
| <a id="rust_toolchain_repository-include_rustc_srcs"></a>include_rustc_srcs |  Whether to download and unpack the rustc source files. These are very large, and slow to unpack, but are required to support rust analyzer. An environment variable <code>RULES_RUST_TOOLCHAIN_INCLUDE_RUSTC_SRCS</code> can also be used to control this attribute. This variable will take precedence over the hard coded attribute. Setting it to <code>true</code> to activates this attribute where all other values deactivate it.   | Boolean | optional | False |
| <a id="rust_toolchain_repository-iso_date"></a>iso_date |  The date of the tool (or None, if the version is a specific version).   | String | optional | "" |
| <a id="rust_toolchain_repository-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | required |  |
| <a id="rust_toolchain_repository-rustfmt_version"></a>rustfmt_version |  The version of the tool among "nightly", "beta", or an exact version.   | String | optional | "" |
| <a id="rust_toolchain_repository-sha256s"></a>sha256s |  A dict associating tool subdirectories to sha256 hashes. See [rust_repositories](#rust_repositories) for more details.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="rust_toolchain_repository-toolchain_name_prefix"></a>toolchain_name_prefix |  The per-target prefix expected for the rust_toolchain declarations in the parent workspace.   | String | optional | "" |
| <a id="rust_toolchain_repository-urls"></a>urls |  A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format).   | List of strings | optional | ["https://static.rust-lang.org/dist/{}.tar.gz"] |
| <a id="rust_toolchain_repository-version"></a>version |  The version of the tool among "nightly", "beta", or an exact version.   | String | required |  |


<a id="#rust_toolchain_repository_proxy"></a>

## rust_toolchain_repository_proxy

<pre>
rust_toolchain_repository_proxy(<a href="#rust_toolchain_repository_proxy-name">name</a>, <a href="#rust_toolchain_repository_proxy-exec_triple">exec_triple</a>, <a href="#rust_toolchain_repository_proxy-extra_target_triples">extra_target_triples</a>, <a href="#rust_toolchain_repository_proxy-parent_workspace_name">parent_workspace_name</a>,
                                <a href="#rust_toolchain_repository_proxy-repo_mapping">repo_mapping</a>, <a href="#rust_toolchain_repository_proxy-toolchain_name_prefix">toolchain_name_prefix</a>)
</pre>

Generates a toolchain-bearing repository that declares the toolchains from some other rust_toolchain_repository.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_toolchain_repository_proxy-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_toolchain_repository_proxy-exec_triple"></a>exec_triple |  The Rust-style target triple for the compilation platform   | String | required |  |
| <a id="rust_toolchain_repository_proxy-extra_target_triples"></a>extra_target_triples |  The Rust-style triples for extra compilation targets   | List of strings | optional | [] |
| <a id="rust_toolchain_repository_proxy-parent_workspace_name"></a>parent_workspace_name |  The name of the other rust_toolchain_repository   | String | required |  |
| <a id="rust_toolchain_repository_proxy-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | required |  |
| <a id="rust_toolchain_repository_proxy-toolchain_name_prefix"></a>toolchain_name_prefix |  The per-target prefix expected for the rust_toolchain declarations in the parent workspace.   | String | optional | "" |


<a id="#rust_repositories"></a>

## rust_repositories

<pre>
rust_repositories(<a href="#rust_repositories-version">version</a>, <a href="#rust_repositories-iso_date">iso_date</a>, <a href="#rust_repositories-rustfmt_version">rustfmt_version</a>, <a href="#rust_repositories-edition">edition</a>, <a href="#rust_repositories-dev_components">dev_components</a>, <a href="#rust_repositories-sha256s">sha256s</a>,
                  <a href="#rust_repositories-include_rustc_srcs">include_rustc_srcs</a>, <a href="#rust_repositories-urls">urls</a>)
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
| <a id="rust_repositories-version"></a>version |  The version of Rust. Either "nightly", "beta", or an exact version. Defaults to a modern version.   |  <code>"1.53.0"</code> |
| <a id="rust_repositories-iso_date"></a>iso_date |  The date of the nightly or beta release (or None, if the version is a specific version).   |  <code>None</code> |
| <a id="rust_repositories-rustfmt_version"></a>rustfmt_version |  The version of rustfmt. Either "nightly", "beta", or an exact version. Defaults to <code>version</code> if not specified.   |  <code>None</code> |
| <a id="rust_repositories-edition"></a>edition |  The rust edition to be used by default (2015 (default) or 2018)   |  <code>None</code> |
| <a id="rust_repositories-dev_components"></a>dev_components |  Whether to download the rustc-dev components (defaults to False). Requires version to be "nightly".   |  <code>False</code> |
| <a id="rust_repositories-sha256s"></a>sha256s |  A dict associating tool subdirectories to sha256 hashes. Defaults to None.   |  <code>None</code> |
| <a id="rust_repositories-include_rustc_srcs"></a>include_rustc_srcs |  Whether to download rustc's src code. This is required in order to use rust-analyzer support. See [rust_toolchain_repository.include_rustc_srcs](#rust_toolchain_repository-include_rustc_srcs). for more details   |  <code>False</code> |
| <a id="rust_repositories-urls"></a>urls |  A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format). Defaults to ['https://static.rust-lang.org/dist/{}.tar.gz']   |  <code>["https://static.rust-lang.org/dist/{}.tar.gz"]</code> |


<a id="#rust_repository_set"></a>

## rust_repository_set

<pre>
rust_repository_set(<a href="#rust_repository_set-name">name</a>, <a href="#rust_repository_set-version">version</a>, <a href="#rust_repository_set-exec_triple">exec_triple</a>, <a href="#rust_repository_set-include_rustc_srcs">include_rustc_srcs</a>, <a href="#rust_repository_set-extra_target_triples">extra_target_triples</a>, <a href="#rust_repository_set-iso_date">iso_date</a>,
                    <a href="#rust_repository_set-rustfmt_version">rustfmt_version</a>, <a href="#rust_repository_set-edition">edition</a>, <a href="#rust_repository_set-dev_components">dev_components</a>, <a href="#rust_repository_set-sha256s">sha256s</a>, <a href="#rust_repository_set-urls">urls</a>)
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
| <a id="rust_repository_set-extra_target_triples"></a>extra_target_triples |  Additional rust-style targets that this set of toolchains should support. Defaults to [].   |  <code>[]</code> |
| <a id="rust_repository_set-iso_date"></a>iso_date |  The date of the tool. Defaults to None.   |  <code>None</code> |
| <a id="rust_repository_set-rustfmt_version"></a>rustfmt_version |  The version of rustfmt to be associated with the toolchain. Defaults to None.   |  <code>None</code> |
| <a id="rust_repository_set-edition"></a>edition |  The rust edition to be used by default (2015 (if None) or 2018).   |  <code>None</code> |
| <a id="rust_repository_set-dev_components"></a>dev_components |  Whether to download the rustc-dev components. Requires version to be "nightly". Defaults to False.   |  <code>False</code> |
| <a id="rust_repository_set-sha256s"></a>sha256s |  A dict associating tool subdirectories to sha256 hashes. See [rust_repositories](#rust_repositories) for more details.   |  <code>None</code> |
| <a id="rust_repository_set-urls"></a>urls |  A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format). Defaults to ['https://static.rust-lang.org/dist/{}.tar.gz']   |  <code>["https://static.rust-lang.org/dist/{}.tar.gz"]</code> |


