<!-- Generated with Stardoc: http://skydoc.bazel.build -->
# Rust Repositories

* [rust_cargo_repository](#rust_cargo_repository)
* [rust_cargo_toolchain](#rust_cargo_toolchain)
* [rust_clippy_repository](#rust_clippy_repository)
* [rust_clippy_toolchain](#rust_clippy_toolchain)
* [rust_exec_toolchain_repository](#rust_exec_toolchain_repository)
* [rust_exec_toolchain](#rust_exec_toolchain)
* [rust_repositories](#rust_repositories)
* [rust_repository_set](#rust_repository_set)
* [rust_rustc_repository](#rust_rustc_repository)
* [rust_rustfmt_repository](#rust_rustfmt_repository)
* [rust_rustfmt_toolchain](#rust_rustfmt_toolchain)
* [rust_stdlib_filegroup](#rust_stdlib_filegroup)
* [rust_stdlib_repository](#rust_stdlib_repository)
* [rust_target_toolchain_repository](#rust_target_toolchain_repository)
* [rust_target_toolchain](#rust_target_toolchain)
* [rust_toolchain](#rust_toolchain)

<a id="#rust_cargo_repository"></a>

## rust_cargo_repository

<pre>
rust_cargo_repository(<a href="#rust_cargo_repository-name">name</a>, <a href="#rust_cargo_repository-auth">auth</a>, <a href="#rust_cargo_repository-iso_date">iso_date</a>, <a href="#rust_cargo_repository-repo_mapping">repo_mapping</a>, <a href="#rust_cargo_repository-sha256">sha256</a>, <a href="#rust_cargo_repository-triple">triple</a>, <a href="#rust_cargo_repository-urls">urls</a>, <a href="#rust_cargo_repository-version">version</a>)
</pre>

A repository rule for downloading a [Cargo](https://doc.rust-lang.org/cargo/) artifact for use in a `rust_cargo_toolchain`.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_cargo_repository-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_cargo_repository-auth"></a>auth |  Auth object compatible with repository_ctx.download to use when downloading files. See https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download for more details.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="rust_cargo_repository-iso_date"></a>iso_date |  The date of the tool (or None, if the version is a specific version).   | String | optional | "" |
| <a id="rust_cargo_repository-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | required |  |
| <a id="rust_cargo_repository-sha256"></a>sha256 |  The sha256 of the cargo artifact.   | String | optional | "" |
| <a id="rust_cargo_repository-triple"></a>triple |  The Rust-style target that this compiler runs on   | String | required |  |
| <a id="rust_cargo_repository-urls"></a>urls |  A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format).   | List of strings | optional | ["https://static.rust-lang.org/dist/{}.tar.gz"] |
| <a id="rust_cargo_repository-version"></a>version |  The version of the tool among "nightly", "beta", or an exact version.   | String | required |  |


<a id="#rust_cargo_toolchain"></a>

## rust_cargo_toolchain

<pre>
rust_cargo_toolchain(<a href="#rust_cargo_toolchain-name">name</a>, <a href="#rust_cargo_toolchain-cargo">cargo</a>)
</pre>

Declares a [Cargo](https://doc.rust-lang.org/cargo/) toolchain for use.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_cargo_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_cargo_toolchain-cargo"></a>cargo |  The location of the <code>cargo</code> binary.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |


<a id="#rust_clippy_repository"></a>

## rust_clippy_repository

<pre>
rust_clippy_repository(<a href="#rust_clippy_repository-name">name</a>, <a href="#rust_clippy_repository-auth">auth</a>, <a href="#rust_clippy_repository-iso_date">iso_date</a>, <a href="#rust_clippy_repository-repo_mapping">repo_mapping</a>, <a href="#rust_clippy_repository-sha256">sha256</a>, <a href="#rust_clippy_repository-triple">triple</a>, <a href="#rust_clippy_repository-urls">urls</a>, <a href="#rust_clippy_repository-version">version</a>)
</pre>

A repository rule for defining a `rust_clippy_toolchain` from the requested version of [Clippy](https://github.com/rust-lang/rust-clippy#readme)

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_clippy_repository-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_clippy_repository-auth"></a>auth |  Auth object compatible with repository_ctx.download to use when downloading files. See https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download for more details.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="rust_clippy_repository-iso_date"></a>iso_date |  The date of the tool (or None, if the version is a specific version).   | String | optional | "" |
| <a id="rust_clippy_repository-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | required |  |
| <a id="rust_clippy_repository-sha256"></a>sha256 |  The sha256 of the clippy-driver artifact.   | String | optional | "" |
| <a id="rust_clippy_repository-triple"></a>triple |  The Rust-style target that this compiler runs on   | String | required |  |
| <a id="rust_clippy_repository-urls"></a>urls |  A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format).   | List of strings | optional | ["https://static.rust-lang.org/dist/{}.tar.gz"] |
| <a id="rust_clippy_repository-version"></a>version |  The version of the tool among "nightly", "beta", or an exact version.   | String | required |  |


<a id="#rust_clippy_toolchain"></a>

## rust_clippy_toolchain

<pre>
rust_clippy_toolchain(<a href="#rust_clippy_toolchain-name">name</a>, <a href="#rust_clippy_toolchain-clippy_driver">clippy_driver</a>)
</pre>

Declares a [Clippy](https://github.com/rust-lang/rust-clippy#readme) toolchain for use.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_clippy_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_clippy_toolchain-clippy_driver"></a>clippy_driver |  The location of the <code>clippy-driver</code> binary.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |


<a id="#rust_exec_toolchain"></a>

## rust_exec_toolchain

<pre>
rust_exec_toolchain(<a href="#rust_exec_toolchain-name">name</a>, <a href="#rust_exec_toolchain-default_edition">default_edition</a>, <a href="#rust_exec_toolchain-iso_date">iso_date</a>, <a href="#rust_exec_toolchain-os">os</a>, <a href="#rust_exec_toolchain-rustc">rustc</a>, <a href="#rust_exec_toolchain-rustc_lib">rustc_lib</a>, <a href="#rust_exec_toolchain-rustc_srcs">rustc_srcs</a>, <a href="#rust_exec_toolchain-rustdoc">rustdoc</a>,
                    <a href="#rust_exec_toolchain-triple">triple</a>, <a href="#rust_exec_toolchain-version">version</a>)
</pre>

Declares a Rust exec/host toolchain for use.

This is for declaring a custom host toolchain (as described by [The rustc book](https://doc.rust-lang.org/stable/rustc/platform-support.html)),
eg. for configuring a particular version of rust or supporting a new platform.

Example:

Suppose the core rust team has ported the compiler to a new target CPU, called `cpuX`. This
support can be used in Bazel by defining a new toolchain definition and declaration:

```python
load('@rules_rust//rust:toolchain.bzl', 'rust_exec_toolchain')

rust_exec_toolchain(
    name = "rust_cpuX_impl",
    # see attributes...
)

toolchain(
    name = "rust_cpuX",
    exec_compatible_with = [
        "@platforms//cpu:cpuX",
    ],
    toolchain = ":rust_cpuX_impl",
    toolchain_type = "@rules_rust//rust:exec_toolchain",
)
```

Then, either add the label of the toolchain rule to `register_toolchains` in the WORKSPACE, or pass
it to the `"--extra_toolchains"` flag for Bazel, and it will be used.

See @rules_rust//rust:repositories.bzl for examples of defining the @rust_cpuX repository
with the actual binaries and libraries.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_exec_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_exec_toolchain-default_edition"></a>default_edition |  The edition to use for rust_* rules that don't specify an edition.   | String | optional | "1.55.0" |
| <a id="rust_exec_toolchain-iso_date"></a>iso_date |  The date of the tool (or None, if the version is a specific version).   | String | optional | "" |
| <a id="rust_exec_toolchain-os"></a>os |  The operating system for the current toolchain   | String | required |  |
| <a id="rust_exec_toolchain-rustc"></a>rustc |  The location of the <code>rustc</code> binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="rust_exec_toolchain-rustc_lib"></a>rustc_lib |  The location of the <code>rustc</code> binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="rust_exec_toolchain-rustc_srcs"></a>rustc_srcs |  The source code of rustc.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_exec_toolchain-rustdoc"></a>rustdoc |  The location of the <code>rustdoc</code> binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_exec_toolchain-triple"></a>triple |  The platform triple for the toolchains execution environment. For more details see: https://docs.bazel.build/versions/master/skylark/rules.html#configurations   | String | optional | "" |
| <a id="rust_exec_toolchain-version"></a>version |  The date of the tool (or None, if the version is a specific version).   | String | required |  |


<a id="#rust_rustc_repository"></a>

## rust_rustc_repository

<pre>
rust_rustc_repository(<a href="#rust_rustc_repository-name">name</a>, <a href="#rust_rustc_repository-auth">auth</a>, <a href="#rust_rustc_repository-dev_components">dev_components</a>, <a href="#rust_rustc_repository-iso_date">iso_date</a>, <a href="#rust_rustc_repository-repo_mapping">repo_mapping</a>, <a href="#rust_rustc_repository-sha256s">sha256s</a>, <a href="#rust_rustc_repository-triple">triple</a>, <a href="#rust_rustc_repository-urls">urls</a>,
                      <a href="#rust_rustc_repository-version">version</a>)
</pre>

must be a host toolchain

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_rustc_repository-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_rustc_repository-auth"></a>auth |  Auth object compatible with repository_ctx.download to use when downloading files. See https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download for more details.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="rust_rustc_repository-dev_components"></a>dev_components |  Whether to download the rustc-dev components (defaults to False). Requires version to be "nightly".   | Boolean | optional | False |
| <a id="rust_rustc_repository-iso_date"></a>iso_date |  The date of the tool (or None, if the version is a specific version).   | String | optional | "" |
| <a id="rust_rustc_repository-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | required |  |
| <a id="rust_rustc_repository-sha256s"></a>sha256s |  A dict associating tool subdirectories to sha256 hashes. See [rust_repositories](#rust_repositories) for more details.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="rust_rustc_repository-triple"></a>triple |  The Rust-style target that this compiler runs on   | String | required |  |
| <a id="rust_rustc_repository-urls"></a>urls |  A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format).   | List of strings | optional | ["https://static.rust-lang.org/dist/{}.tar.gz"] |
| <a id="rust_rustc_repository-version"></a>version |  The version of the tool among "nightly", "beta", or an exact version.   | String | required |  |


<a id="#rust_rustfmt_repository"></a>

## rust_rustfmt_repository

<pre>
rust_rustfmt_repository(<a href="#rust_rustfmt_repository-name">name</a>, <a href="#rust_rustfmt_repository-auth">auth</a>, <a href="#rust_rustfmt_repository-iso_date">iso_date</a>, <a href="#rust_rustfmt_repository-repo_mapping">repo_mapping</a>, <a href="#rust_rustfmt_repository-sha256">sha256</a>, <a href="#rust_rustfmt_repository-triple">triple</a>, <a href="#rust_rustfmt_repository-urls">urls</a>, <a href="#rust_rustfmt_repository-version">version</a>)
</pre>

A repository rule for downloading a [Rustfmt](https://github.com/rust-lang/rustfmt#readme) artifact for use in a `rust_rustfmt_toolchain`.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_rustfmt_repository-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_rustfmt_repository-auth"></a>auth |  Auth object compatible with repository_ctx.download to use when downloading files. See https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download for more details.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="rust_rustfmt_repository-iso_date"></a>iso_date |  The date of the tool (or None, if the version is a specific version).   | String | optional | "" |
| <a id="rust_rustfmt_repository-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | required |  |
| <a id="rust_rustfmt_repository-sha256"></a>sha256 |  The sha256 of the rustfmt artifact.   | String | optional | "" |
| <a id="rust_rustfmt_repository-triple"></a>triple |  The Rust-style target that this compiler runs on   | String | required |  |
| <a id="rust_rustfmt_repository-urls"></a>urls |  A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format).   | List of strings | optional | ["https://static.rust-lang.org/dist/{}.tar.gz"] |
| <a id="rust_rustfmt_repository-version"></a>version |  The version of the tool among "nightly", "beta", or an exact version.   | String | required |  |


<a id="#rust_rustfmt_toolchain"></a>

## rust_rustfmt_toolchain

<pre>
rust_rustfmt_toolchain(<a href="#rust_rustfmt_toolchain-name">name</a>, <a href="#rust_rustfmt_toolchain-rustfmt">rustfmt</a>)
</pre>

Declares a [Rustfmt](https://github.com/rust-lang/rustfmt#readme) toolchain for use.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_rustfmt_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_rustfmt_toolchain-rustfmt"></a>rustfmt |  The location of the <code>rustfmt</code> binary.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |


<a id="#rust_stdlib_filegroup"></a>

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


<a id="#rust_stdlib_repository"></a>

## rust_stdlib_repository

<pre>
rust_stdlib_repository(<a href="#rust_stdlib_repository-name">name</a>, <a href="#rust_stdlib_repository-auth">auth</a>, <a href="#rust_stdlib_repository-iso_date">iso_date</a>, <a href="#rust_stdlib_repository-repo_mapping">repo_mapping</a>, <a href="#rust_stdlib_repository-sha256s">sha256s</a>, <a href="#rust_stdlib_repository-triple">triple</a>, <a href="#rust_stdlib_repository-urls">urls</a>, <a href="#rust_stdlib_repository-version">version</a>)
</pre>

A repository rule for fetching the `rust-std` ([Rust Standard Library](https://doc.rust-lang.org/std/)) artifact for the requested platform.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_stdlib_repository-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_stdlib_repository-auth"></a>auth |  Auth object compatible with repository_ctx.download to use when downloading files. See https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download for more details.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="rust_stdlib_repository-iso_date"></a>iso_date |  The date of the tool (or None, if the version is a specific version).   | String | optional | "" |
| <a id="rust_stdlib_repository-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | required |  |
| <a id="rust_stdlib_repository-sha256s"></a>sha256s |  A dict associating tool subdirectories to sha256 hashes. See [rust_repositories](#rust_repositories) for more details.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="rust_stdlib_repository-triple"></a>triple |  The Rust-style target that this compiler runs on   | String | required |  |
| <a id="rust_stdlib_repository-urls"></a>urls |  A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format).   | List of strings | optional | ["https://static.rust-lang.org/dist/{}.tar.gz"] |
| <a id="rust_stdlib_repository-version"></a>version |  The version of the tool among "nightly", "beta", or an exact version.   | String | required |  |


<a id="#rust_target_toolchain"></a>

## rust_target_toolchain

<pre>
rust_target_toolchain(<a href="#rust_target_toolchain-name">name</a>, <a href="#rust_target_toolchain-allocator_library">allocator_library</a>, <a href="#rust_target_toolchain-binary_ext">binary_ext</a>, <a href="#rust_target_toolchain-debug_info">debug_info</a>, <a href="#rust_target_toolchain-dylib_ext">dylib_ext</a>, <a href="#rust_target_toolchain-iso_date">iso_date</a>,
                      <a href="#rust_target_toolchain-opt_level">opt_level</a>, <a href="#rust_target_toolchain-os">os</a>, <a href="#rust_target_toolchain-rust_stdlib">rust_stdlib</a>, <a href="#rust_target_toolchain-staticlib_ext">staticlib_ext</a>, <a href="#rust_target_toolchain-stdlib_linkflags">stdlib_linkflags</a>, <a href="#rust_target_toolchain-target_json">target_json</a>,
                      <a href="#rust_target_toolchain-triple">triple</a>, <a href="#rust_target_toolchain-version">version</a>)
</pre>

Declares a Rust target toolchain for use.

This is for declaring a custom toolchain which contains details about the target platform as well as
provide a `rust-std` artifact to the sysroot for targets that depend on the stardard library.

Example:

Suppose the core rust team has added a new platform to tier 2 support with a `rust-std` artifact called
`aarch256-raven-microcyber`. This support can be used in Bazel by defining a new toolchain definition
and declaration:

```python
load('@rules_rust//rust:toolchain.bzl', 'rust_target_toolchain')

rust_target_toolchain(
    name = "rust_aarch256_raven_microcyber_impl",
    # see attributes...
)

toolchain(
    name = "rust_aarch256_raven_microcyber",
    target_compatible_with = [
        "@platforms//cpu:aarch2077",
        "@platforms//os:microcyber",
    ],
    toolchain = ":rust_aarch256_raven_microcyber_impl",
    toolchain_type = "@rules_rust//rust:target_toolchain",
)
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_target_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_target_toolchain-allocator_library"></a>allocator_library |  Target that provides allocator functions when rust_library targets are embedded in a cc_binary.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_target_toolchain-binary_ext"></a>binary_ext |  The extension for binaries created from rustc.   | String | required |  |
| <a id="rust_target_toolchain-debug_info"></a>debug_info |  Rustc debug info levels per opt level   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {"dbg": "2", "fastbuild": "0", "opt": "0"} |
| <a id="rust_target_toolchain-dylib_ext"></a>dylib_ext |  The extension for dynamic libraries created from rustc.   | String | required |  |
| <a id="rust_target_toolchain-iso_date"></a>iso_date |  The date of the tool (or None, if the version is a specific version).   | String | optional | "" |
| <a id="rust_target_toolchain-opt_level"></a>opt_level |  Rustc optimization levels.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {"dbg": "0", "fastbuild": "0", "opt": "3"} |
| <a id="rust_target_toolchain-os"></a>os |  The operating system for the current toolchain   | String | required |  |
| <a id="rust_target_toolchain-rust_stdlib"></a>rust_stdlib |  The rust standard library.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="rust_target_toolchain-staticlib_ext"></a>staticlib_ext |  The extension for static libraries created from rustc.   | String | required |  |
| <a id="rust_target_toolchain-stdlib_linkflags"></a>stdlib_linkflags |  Additional linker libs used when std lib is linked, see https://github.com/rust-lang/rust/blob/master/src/libstd/build.rs   | List of strings | required |  |
| <a id="rust_target_toolchain-target_json"></a>target_json |  Override the target_triple with a custom target specification. For more details see: https://doc.rust-lang.org/rustc/targets/custom.html   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="rust_target_toolchain-triple"></a>triple |  The platform triple for the toolchains execution environment. For more details see: https://docs.bazel.build/versions/master/skylark/rules.html#configurations   | String | optional | "" |
| <a id="rust_target_toolchain-version"></a>version |  The version of the tool among "nightly", "beta", or an exact version.   | String | required |  |


<a id="#rust_toolchain"></a>

## rust_toolchain

<pre>
rust_toolchain(<a href="#rust_toolchain-name">name</a>)
</pre>

Declares a Rust exec/host + target toolchain for use.

This takes a [rust_exec_toolchain](#rust_exec_toolchain) and a [rust_target_toolchain](#rust_target_toolchain) and creates
a [sysroot](https://doc.rust-lang.org/stable/rustc/command-line-arguments.html#--sysroot-override-the-system-root)
containing all Rust components needed to build in the execution environment for the target platform. This
toolchain allows Bazel's toolchain resolution to, on-demand, gather the necessary components to perform an action
without forcing users to generate complete sysroots for all combinations of `exec -> target(s)` expected to be
built.

A generated sysroot is expected to look like the following:

```text
rust/toolchain/current/
    bin/
        rustc -> ${CACHE_LOCATION}/rustc
        rustdoc -> ${CACHE_LOCATION}/rustdoc
    lib/
        lib*.so -> ${CACHE_LOCATION}/lib*.so
        ...
        rustlib/
            x86_64-unknown-linux-gnu/
                bin/
                    rust-lld -> ${CACHE_LOCATION}/rust-lld
                lib/
                    lib*.rlib -> ${CACHE_LOCATION}/lib*.rlib
                    ...
    rules_rust.sysroot -> ${CACHE_LOCATION}/rules_rust.sysroot
```

The tree above assumes that the contents of `rust_exec_toolchain` and `rust_target_toolchain` can
be directly used in the sysroot, meaning the files use the same paths from the root of their
repositories and are not expected to contain any conflicts. Though, both toolchains may provide
contents for the same directory, where above `./lib/rustlib/x86_64-unknown-linux-gnu` contains a
`bin` directory from the exec toolchain and a `lib` directory from the target toolchain.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |


<a id="#rust_exec_toolchain_repository"></a>

## rust_exec_toolchain_repository

<pre>
rust_exec_toolchain_repository(<a href="#rust_exec_toolchain_repository-name">name</a>, <a href="#rust_exec_toolchain_repository-triple">triple</a>, <a href="#rust_exec_toolchain_repository-dev_components">dev_components</a>, <a href="#rust_exec_toolchain_repository-edition">edition</a>, <a href="#rust_exec_toolchain_repository-exec_compatible_with">exec_compatible_with</a>,
                               <a href="#rust_exec_toolchain_repository-include_rustc_srcs">include_rustc_srcs</a>, <a href="#rust_exec_toolchain_repository-iso_date">iso_date</a>, <a href="#rust_exec_toolchain_repository-rustfmt_iso_date">rustfmt_iso_date</a>, <a href="#rust_exec_toolchain_repository-rustfmt_version">rustfmt_version</a>,
                               <a href="#rust_exec_toolchain_repository-sha256s">sha256s</a>, <a href="#rust_exec_toolchain_repository-target_compatible_with">target_compatible_with</a>, <a href="#rust_exec_toolchain_repository-urls">urls</a>, <a href="#rust_exec_toolchain_repository-version">version</a>)
</pre>

A repository rule for defining a [rust_exec_toolchain](#rust_exec_toolchain).

This repository rule generates repositories for host tools (as described by [The rustc book][trc]) and wires
them into a `rust_exec_toolchain` target. Note that the `rust_exec_toolchain` only includes `rustc` and it's
dependencies. Additional host tools such as `Cargo`, `Clippy`, and `Rustfmt` are all declared as separate
toolchains. This rule should be used to define more customized exec toolchains than those created by
`rust_repositories`.

Tool Repositories Created:
- [rust_cargo_repository](#rust_cargo_repository)
- [rust_clippy_repository](#rust_clippy_repository)
- [rust_rustc_repository](#rust_rustc_repository)
- [rust_rustfmt_repository](#rust_rustfmt_repository)
- [rust_srcs_repository](#rust_srcs_repository)

Toolchains Created:
- [rust_exec_toolchain](#rust_exec_toolchain)
- [rust_cargo_toolchain](#rust_cargo_toolchain)
- [rust_clippy_toolchain](#rust_clippy_toolchain)
- [rust_rustfmt_toolchain](#rust_rustfmt_toolchain)


[trc]: https://doc.rust-lang.org/stable/rustc/platform-support.html


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rust_exec_toolchain_repository-name"></a>name |  The name of the toolchain repository as well as the prefix for each individual 'tool repository'.   |  none |
| <a id="rust_exec_toolchain_repository-triple"></a>triple |  The platform triple of the execution environment.   |  none |
| <a id="rust_exec_toolchain_repository-dev_components"></a>dev_components |  [description]. Defaults to False.   |  <code>False</code> |
| <a id="rust_exec_toolchain_repository-edition"></a>edition |  The rust edition to be used by default.   |  <code>"2018"</code> |
| <a id="rust_exec_toolchain_repository-exec_compatible_with"></a>exec_compatible_with |  Optional exec constraints for the toolchain. If unset, a default will be used based on the value of <code>triple</code>. See <code>@rules_rust//rust/platform:triple_mappings.bzl</code> for more details.   |  <code>None</code> |
| <a id="rust_exec_toolchain_repository-include_rustc_srcs"></a>include_rustc_srcs |  Whether to download and unpack the rustc source files. These are very large, and slow to unpack, but are required to support rust analyzer.   |  <code>False</code> |
| <a id="rust_exec_toolchain_repository-iso_date"></a>iso_date |  The date of the tool (or None, if the version is a specific version).   |  <code>None</code> |
| <a id="rust_exec_toolchain_repository-rustfmt_iso_date"></a>rustfmt_iso_date |  Similar to <code>iso_date</code> but specific to Rustfmt. If unspecified, <code>iso_date</code> will be used.   |  <code>None</code> |
| <a id="rust_exec_toolchain_repository-rustfmt_version"></a>rustfmt_version |  Similar to <code>version</code> but specific to Rustfmt. If unspecified, <code>version</code> will be used.   |  <code>None</code> |
| <a id="rust_exec_toolchain_repository-sha256s"></a>sha256s |  A dict associating tool subdirectories to sha256 hashes.   |  <code>None</code> |
| <a id="rust_exec_toolchain_repository-target_compatible_with"></a>target_compatible_with |  Optional target constraints for the toolchain.   |  <code>[]</code> |
| <a id="rust_exec_toolchain_repository-urls"></a>urls |  A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format).   |  <code>["https://static.rust-lang.org/dist/{}.tar.gz"]</code> |
| <a id="rust_exec_toolchain_repository-version"></a>version |  The version of the tool among "nightly", "beta", or an exact version.   |  <code>"1.55.0"</code> |


<a id="#rust_repositories"></a>

## rust_repositories

<pre>
rust_repositories(<a href="#rust_repositories-dev_components">dev_components</a>, <a href="#rust_repositories-edition">edition</a>, <a href="#rust_repositories-include_rustc_srcs">include_rustc_srcs</a>, <a href="#rust_repositories-iso_date">iso_date</a>, <a href="#rust_repositories-prefix">prefix</a>,
                  <a href="#rust_repositories-register_toolchains">register_toolchains</a>, <a href="#rust_repositories-rustfmt_version">rustfmt_version</a>, <a href="#rust_repositories-sha256s">sha256s</a>, <a href="#rust_repositories-urls">urls</a>, <a href="#rust_repositories-version">version</a>)
</pre>

Instantiate repositories and toolchains required by `rules_rust`.

Skip this macro and call the [rust_exec_toolchain_repository](#rust_exec_toolchain_repository) or
[rust_target_toolchain_repository](#rust_target_toolchain_repository) rules directly if you need a
compiler for other hosts or for additional target triples.

The `sha256` attribute represents a dict associating tool subdirectories to sha256 hashes. As an example:
```python
{
    "rust-1.46.0-x86_64-unknown-linux-gnu": "e3b98bc3440fe92817881933f9564389eccb396f5f431f33d48b979fa2fbdcf5",
    "rustfmt-1.4.12-x86_64-unknown-linux-gnu": "1894e76913303d66bf40885a601462844eec15fca9e76a6d13c390d7000d64b0",
    "rust-std-1.46.0-x86_64-unknown-linux-gnu": "ac04aef80423f612c0079829b504902de27a6997214eb58ab0765d02f7ec1dbc",
}
```


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rust_repositories-dev_components"></a>dev_components |  Whether to download the rustc-dev components.   |  <code>False</code> |
| <a id="rust_repositories-edition"></a>edition |  The rust edition to be used by default (2015, 2018 (default), or 2021)   |  <code>"2018"</code> |
| <a id="rust_repositories-include_rustc_srcs"></a>include_rustc_srcs |  Whether to download rustc's src code. This is required in order to use rust-analyzer support. See [rust_toolchain_repository.include_rustc_srcs](#rust_toolchain_repository-include_rustc_srcs). for more details   |  <code>False</code> |
| <a id="rust_repositories-iso_date"></a>iso_date |  The date of the nightly or beta release (or None, if the version is a specific version).   |  <code>None</code> |
| <a id="rust_repositories-prefix"></a>prefix |  The prefix used for all generated repositories. Eg. <code>{prefix}_{repository}</code>.   |  <code>"rules_rust"</code> |
| <a id="rust_repositories-register_toolchains"></a>register_toolchains |  Whether or not to register any toolchains. Setting this to false will allow for other repositories the rules depend on to get defined while allowing users to have full control over their toolchains   |  <code>True</code> |
| <a id="rust_repositories-rustfmt_version"></a>rustfmt_version |  Same as <code>version</code> but is only used for <code>rustfmt</code>   |  <code>None</code> |
| <a id="rust_repositories-sha256s"></a>sha256s |  A dict associating tool subdirectories to sha256 hashes.   |  <code>None</code> |
| <a id="rust_repositories-urls"></a>urls |  A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format).   |  <code>["https://static.rust-lang.org/dist/{}.tar.gz"]</code> |
| <a id="rust_repositories-version"></a>version |  The version of Rust. Either "nightly", "beta", or an exact version. Defaults to a modern version.   |  <code>"1.55.0"</code> |


<a id="#rust_repository_set"></a>

## rust_repository_set

<pre>
rust_repository_set(<a href="#rust_repository_set-name">name</a>, <a href="#rust_repository_set-version">version</a>, <a href="#rust_repository_set-exec_triple">exec_triple</a>, <a href="#rust_repository_set-include_rustc_srcs">include_rustc_srcs</a>, <a href="#rust_repository_set-extra_target_triples">extra_target_triples</a>, <a href="#rust_repository_set-iso_date">iso_date</a>,
                    <a href="#rust_repository_set-rustfmt_version">rustfmt_version</a>, <a href="#rust_repository_set-edition">edition</a>, <a href="#rust_repository_set-dev_components">dev_components</a>, <a href="#rust_repository_set-sha256s">sha256s</a>, <a href="#rust_repository_set-urls">urls</a>, <a href="#rust_repository_set-auth">auth</a>)
</pre>

A convenience macro for defining an exec toolchain and a collection of extra target toolchains.

For more information see on what specifically is generated by this macro, see the
[rust_exec_toolchain_repository](#rust_exec_toolchain_repository) and
[rust_target_toolchain_repository](#rust_target_toolchain_repository) rules.


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
| <a id="rust_repository_set-edition"></a>edition |  The rust edition to be used by default (2015, 2018 (if None), or 2021).   |  <code>None</code> |
| <a id="rust_repository_set-dev_components"></a>dev_components |  Whether to download the rustc-dev components. Requires version to be "nightly". Defaults to False.   |  <code>False</code> |
| <a id="rust_repository_set-sha256s"></a>sha256s |  A dict associating tool subdirectories to sha256 hashes. See [rust_repositories](#rust_repositories) for more details.   |  <code>None</code> |
| <a id="rust_repository_set-urls"></a>urls |  A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format).   |  <code>["https://static.rust-lang.org/dist/{}.tar.gz"]</code> |
| <a id="rust_repository_set-auth"></a>auth |  Auth object compatible with repository_ctx.download to use when downloading files. See https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download for more details.   |  <code>None</code> |


<a id="#rust_target_toolchain_repository"></a>

## rust_target_toolchain_repository

<pre>
rust_target_toolchain_repository(<a href="#rust_target_toolchain_repository-name">name</a>, <a href="#rust_target_toolchain_repository-triple">triple</a>, <a href="#rust_target_toolchain_repository-allocator_library">allocator_library</a>, <a href="#rust_target_toolchain_repository-exec_compatible_with">exec_compatible_with</a>, <a href="#rust_target_toolchain_repository-iso_date">iso_date</a>,
                                 <a href="#rust_target_toolchain_repository-sha256s">sha256s</a>, <a href="#rust_target_toolchain_repository-stdlib_linkflags">stdlib_linkflags</a>, <a href="#rust_target_toolchain_repository-target_compatible_with">target_compatible_with</a>, <a href="#rust_target_toolchain_repository-urls">urls</a>, <a href="#rust_target_toolchain_repository-version">version</a>)
</pre>

A repository rule for defining a [rust_target_toolchain](#rust_target_toolchain).

This rule declares repository rules for components that may be required to build for the target platform
such as the `rust-std` artifact. The targets that represent these components are wired into the
`rust_target_toolchain` that's created which is then consumed by a `rust_toolchain` target for generating
the sysroot to use in a `Rustc` action. This rule should be used to define more customized target toolchains
than those created by `rust_repositories`.

Tool Repositories Created:
- [rust_stdlib_repository](#rust_stdlib_repository)

Toolchains Created:
- [rust_target_toolchain](#rust_target_toolchain)


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rust_target_toolchain_repository-name"></a>name |  The name of the toolchain repository as well as the prefix for each individual 'tool repository'.   |  none |
| <a id="rust_target_toolchain_repository-triple"></a>triple |  The platform triple of the target environment.   |  none |
| <a id="rust_target_toolchain_repository-allocator_library"></a>allocator_library |  Target that provides allocator functions when rust_library targets are embedded in a <code>cc_binary</code>.   |  <code>None</code> |
| <a id="rust_target_toolchain_repository-exec_compatible_with"></a>exec_compatible_with |  Optional exec constraints for the toolchain.   |  <code>[]</code> |
| <a id="rust_target_toolchain_repository-iso_date"></a>iso_date |  The date of the tool (or None, if the version is a specific version).   |  <code>None</code> |
| <a id="rust_target_toolchain_repository-sha256s"></a>sha256s |  A dict associating tool subdirectories to sha256 hashes.   |  <code>None</code> |
| <a id="rust_target_toolchain_repository-stdlib_linkflags"></a>stdlib_linkflags |  The repository name for a <code>rust_stdlib_repository</code>.   |  <code>None</code> |
| <a id="rust_target_toolchain_repository-target_compatible_with"></a>target_compatible_with |  Optional target constraints for the toolchain. If unset, a default will be used based on the value of <code>triple</code>. See <code>@rules_rust//rust/platform:triple_mappings.bzl</code> for more details.   |  <code>None</code> |
| <a id="rust_target_toolchain_repository-urls"></a>urls |  A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format).   |  <code>["https://static.rust-lang.org/dist/{}.tar.gz"]</code> |
| <a id="rust_target_toolchain_repository-version"></a>version |  The version of the tool among "nightly", "beta", or an exact version.   |  <code>"1.55.0"</code> |


