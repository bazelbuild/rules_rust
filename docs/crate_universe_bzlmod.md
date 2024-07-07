<!-- Generated with Stardoc: http://skydoc.bazel.build -->

# Crate Universe

Crate Universe is a set of Bazel rule for generating Rust targets using Cargo.

This doc describes using crate_universe with bzlmod.

If you're using a WORKSPACE file, please see [the WORKSPACE equivalent of this doc](crate_universe.html).

There are some examples of using crate_universe with bzlmod:

* https://github.com/bazelbuild/rules_rust/blob/main/examples/bzlmod/hello_world/MODULE.bazel
* https://github.com/bazelbuild/rules_rust/blob/main/examples/bzlmod/override_target/MODULE.bazel
* https://github.com/bazelbuild/rules_rust/blob/main/examples/bzlmod/all_crate_deps/MODULE.bazel

<a id="crate"></a>

## crate

<pre>
crate = use_extension("@rules_rust//crate_universe:docs_bzlmod.bzl", "crate")
crate.from_cargo(<a href="#crate.from_cargo-name">name</a>, <a href="#crate.from_cargo-cargo_config">cargo_config</a>, <a href="#crate.from_cargo-cargo_lockfile">cargo_lockfile</a>, <a href="#crate.from_cargo-generate_binaries">generate_binaries</a>, <a href="#crate.from_cargo-generate_build_scripts">generate_build_scripts</a>,
                 <a href="#crate.from_cargo-manifests">manifests</a>, <a href="#crate.from_cargo-supported_platform_triples">supported_platform_triples</a>)
crate.annotation(<a href="#crate.annotation-deps">deps</a>, <a href="#crate.annotation-data">data</a>, <a href="#crate.annotation-additive_build_file">additive_build_file</a>, <a href="#crate.annotation-additive_build_file_content">additive_build_file_content</a>, <a href="#crate.annotation-alias_rule">alias_rule</a>,
                 <a href="#crate.annotation-build_script_data">build_script_data</a>, <a href="#crate.annotation-build_script_data_glob">build_script_data_glob</a>, <a href="#crate.annotation-build_script_deps">build_script_deps</a>, <a href="#crate.annotation-build_script_env">build_script_env</a>,
                 <a href="#crate.annotation-build_script_proc_macro_deps">build_script_proc_macro_deps</a>, <a href="#crate.annotation-build_script_rundir">build_script_rundir</a>, <a href="#crate.annotation-build_script_rustc_env">build_script_rustc_env</a>,
                 <a href="#crate.annotation-build_script_toolchains">build_script_toolchains</a>, <a href="#crate.annotation-build_script_tools">build_script_tools</a>, <a href="#crate.annotation-compile_data">compile_data</a>, <a href="#crate.annotation-compile_data_glob">compile_data_glob</a>, <a href="#crate.annotation-crate">crate</a>,
                 <a href="#crate.annotation-crate_features">crate_features</a>, <a href="#crate.annotation-data_glob">data_glob</a>, <a href="#crate.annotation-disable_pipelining">disable_pipelining</a>, <a href="#crate.annotation-extra_aliased_targets">extra_aliased_targets</a>,
                 <a href="#crate.annotation-gen_all_binaries">gen_all_binaries</a>, <a href="#crate.annotation-gen_binaries">gen_binaries</a>, <a href="#crate.annotation-gen_build_script">gen_build_script</a>, <a href="#crate.annotation-override_target_bin">override_target_bin</a>,
                 <a href="#crate.annotation-override_target_build_script">override_target_build_script</a>, <a href="#crate.annotation-override_target_lib">override_target_lib</a>, <a href="#crate.annotation-override_target_proc_macro">override_target_proc_macro</a>,
                 <a href="#crate.annotation-patch_args">patch_args</a>, <a href="#crate.annotation-patch_tool">patch_tool</a>, <a href="#crate.annotation-patches">patches</a>, <a href="#crate.annotation-proc_macro_deps">proc_macro_deps</a>, <a href="#crate.annotation-repositories">repositories</a>, <a href="#crate.annotation-rustc_env">rustc_env</a>,
                 <a href="#crate.annotation-rustc_env_files">rustc_env_files</a>, <a href="#crate.annotation-rustc_flags">rustc_flags</a>, <a href="#crate.annotation-shallow_since">shallow_since</a>, <a href="#crate.annotation-version">version</a>)
crate.from_specs(<a href="#crate.from_specs-name">name</a>, <a href="#crate.from_specs-cargo_config">cargo_config</a>, <a href="#crate.from_specs-generate_binaries">generate_binaries</a>, <a href="#crate.from_specs-generate_build_scripts">generate_build_scripts</a>,
                 <a href="#crate.from_specs-supported_platform_triples">supported_platform_triples</a>)
crate.spec(<a href="#crate.spec-artifact">artifact</a>, <a href="#crate.spec-branch">branch</a>, <a href="#crate.spec-default_features">default_features</a>, <a href="#crate.spec-features">features</a>, <a href="#crate.spec-git">git</a>, <a href="#crate.spec-lib">lib</a>, <a href="#crate.spec-package">package</a>, <a href="#crate.spec-rev">rev</a>, <a href="#crate.spec-tag">tag</a>, <a href="#crate.spec-version">version</a>)
</pre>


**TAG CLASSES**

<a id="crate.from_cargo"></a>

### from_cargo

Generates a repo @crates from a Cargo.toml / Cargo.lock pair

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="crate.from_cargo-name"></a>name |  The name of the repo to generate   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | optional |  `"crates"`  |
| <a id="crate.from_cargo-cargo_config"></a>cargo_config |  A [Cargo configuration](https://doc.rust-lang.org/cargo/reference/config.html) file.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="crate.from_cargo-cargo_lockfile"></a>cargo_lockfile |  The path to an existing `Cargo.lock` file   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="crate.from_cargo-generate_binaries"></a>generate_binaries |  Whether to generate `rust_binary` targets for all the binary crates in every package. By default only the `rust_library` targets are generated.   | Boolean | optional |  `False`  |
| <a id="crate.from_cargo-generate_build_scripts"></a>generate_build_scripts |  Whether or not to generate [cargo build scripts](https://doc.rust-lang.org/cargo/reference/build-scripts.html) by default.   | Boolean | optional |  `True`  |
| <a id="crate.from_cargo-manifests"></a>manifests |  A list of Cargo manifests (`Cargo.toml` files).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="crate.from_cargo-supported_platform_triples"></a>supported_platform_triples |  A set of all platform triples to consider when generating dependencies.   | List of strings | optional |  `["aarch64-unknown-linux-gnu", "aarch64-unknown-nixos-gnu", "i686-apple-darwin", "i686-pc-windows-msvc", "i686-unknown-linux-gnu", "x86_64-apple-darwin", "x86_64-pc-windows-msvc", "x86_64-unknown-linux-gnu", "x86_64-unknown-nixos-gnu", "aarch64-apple-darwin", "aarch64-apple-ios-sim", "aarch64-apple-ios", "aarch64-fuchsia", "aarch64-linux-android", "aarch64-pc-windows-msvc", "arm-unknown-linux-gnueabi", "armv7-linux-androideabi", "armv7-unknown-linux-gnueabi", "i686-linux-android", "i686-unknown-freebsd", "powerpc-unknown-linux-gnu", "riscv32imc-unknown-none-elf", "riscv64gc-unknown-none-elf", "s390x-unknown-linux-gnu", "thumbv7em-none-eabi", "thumbv8m.main-none-eabi", "wasm32-unknown-unknown", "wasm32-wasi", "x86_64-apple-ios", "x86_64-fuchsia", "x86_64-linux-android", "x86_64-unknown-freebsd", "x86_64-unknown-none", "aarch64-unknown-nto-qnx710"]`  |

<a id="crate.annotation"></a>

### annotation

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="crate.annotation-deps"></a>deps |  A list of labels to add to a crate's `rust_library::deps` attribute.   | List of strings | optional |  `[]`  |
| <a id="crate.annotation-data"></a>data |  A list of labels to add to a crate's `rust_library::data` attribute.   | List of strings | optional |  `[]`  |
| <a id="crate.annotation-additive_build_file"></a>additive_build_file |  A file containing extra contents to write to the bottom of generated BUILD files.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="crate.annotation-additive_build_file_content"></a>additive_build_file_content |  Extra contents to write to the bottom of generated BUILD files.   | String | optional |  `""`  |
| <a id="crate.annotation-alias_rule"></a>alias_rule |  Alias rule to use instead of `native.alias()`.  Overrides [render_config](#render_config)'s 'default_alias_rule'.   | String | optional |  `""`  |
| <a id="crate.annotation-build_script_data"></a>build_script_data |  A list of labels to add to a crate's `cargo_build_script::data` attribute.   | List of strings | optional |  `[]`  |
| <a id="crate.annotation-build_script_data_glob"></a>build_script_data_glob |  A list of glob patterns to add to a crate's `cargo_build_script::data` attribute   | List of strings | optional |  `[]`  |
| <a id="crate.annotation-build_script_deps"></a>build_script_deps |  A list of labels to add to a crate's `cargo_build_script::deps` attribute.   | List of strings | optional |  `[]`  |
| <a id="crate.annotation-build_script_env"></a>build_script_env |  Additional environment variables to set on a crate's `cargo_build_script::env` attribute.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="crate.annotation-build_script_proc_macro_deps"></a>build_script_proc_macro_deps |  A list of labels to add to a crate's `cargo_build_script::proc_macro_deps` attribute.   | List of strings | optional |  `[]`  |
| <a id="crate.annotation-build_script_rundir"></a>build_script_rundir |  An override for the build script's rundir attribute.   | String | optional |  `""`  |
| <a id="crate.annotation-build_script_rustc_env"></a>build_script_rustc_env |  Additional environment variables to set on a crate's `cargo_build_script::env` attribute.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="crate.annotation-build_script_toolchains"></a>build_script_toolchains |  A list of labels to set on a crates's `cargo_build_script::toolchains` attribute.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="crate.annotation-build_script_tools"></a>build_script_tools |  A list of labels to add to a crate's `cargo_build_script::tools` attribute.   | List of strings | optional |  `[]`  |
| <a id="crate.annotation-compile_data"></a>compile_data |  A list of labels to add to a crate's `rust_library::compile_data` attribute.   | List of strings | optional |  `[]`  |
| <a id="crate.annotation-compile_data_glob"></a>compile_data_glob |  A list of glob patterns to add to a crate's `rust_library::compile_data` attribute.   | List of strings | optional |  `[]`  |
| <a id="crate.annotation-crate"></a>crate |  The name of the crate the annotation is applied to   | String | required |  |
| <a id="crate.annotation-crate_features"></a>crate_features |  A list of strings to add to a crate's `rust_library::crate_features` attribute.   | List of strings | optional |  `[]`  |
| <a id="crate.annotation-data_glob"></a>data_glob |  A list of glob patterns to add to a crate's `rust_library::data` attribute.   | List of strings | optional |  `[]`  |
| <a id="crate.annotation-disable_pipelining"></a>disable_pipelining |  If True, disables pipelining for library targets for this crate.   | Boolean | optional |  `False`  |
| <a id="crate.annotation-extra_aliased_targets"></a>extra_aliased_targets |  A list of targets to add to the generated aliases in the root crate_universe repository.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="crate.annotation-gen_all_binaries"></a>gen_all_binaries |  If true, generates `rust_binary` targets for all of the crates bins   | Boolean | optional |  `False`  |
| <a id="crate.annotation-gen_binaries"></a>gen_binaries |  As a list, the subset of the crate's bins that should get `rust_binary` targets produced.   | List of strings | optional |  `[]`  |
| <a id="crate.annotation-gen_build_script"></a>gen_build_script |  An authorative flag to determine whether or not to produce `cargo_build_script` targets for the current crate. Supported values are 'on', 'off', and 'auto'.   | String | optional |  `"auto"`  |
| <a id="crate.annotation-override_target_bin"></a>override_target_bin |  An optional alternate taget to use when something depends on this crate to allow the parent repo to provide its own version of this dependency.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="crate.annotation-override_target_build_script"></a>override_target_build_script |  An optional alternate taget to use when something depends on this crate to allow the parent repo to provide its own version of this dependency.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="crate.annotation-override_target_lib"></a>override_target_lib |  An optional alternate taget to use when something depends on this crate to allow the parent repo to provide its own version of this dependency.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="crate.annotation-override_target_proc_macro"></a>override_target_proc_macro |  An optional alternate taget to use when something depends on this crate to allow the parent repo to provide its own version of this dependency.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="crate.annotation-patch_args"></a>patch_args |  The `patch_args` attribute of a Bazel repository rule. See [http_archive.patch_args](https://docs.bazel.build/versions/main/repo/http.html#http_archive-patch_args)   | List of strings | optional |  `[]`  |
| <a id="crate.annotation-patch_tool"></a>patch_tool |  The `patch_tool` attribute of a Bazel repository rule. See [http_archive.patch_tool](https://docs.bazel.build/versions/main/repo/http.html#http_archive-patch_tool)   | String | optional |  `""`  |
| <a id="crate.annotation-patches"></a>patches |  The `patches` attribute of a Bazel repository rule. See [http_archive.patches](https://docs.bazel.build/versions/main/repo/http.html#http_archive-patches)   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="crate.annotation-proc_macro_deps"></a>proc_macro_deps |  A list of labels to add to a crate's `rust_library::proc_macro_deps` attribute.   | List of strings | optional |  `[]`  |
| <a id="crate.annotation-repositories"></a>repositories |  A list of repository names specified from `crate.from_cargo(name=...)` that this annotation is applied to. Defaults to all repositories.   | List of strings | optional |  `[]`  |
| <a id="crate.annotation-rustc_env"></a>rustc_env |  Additional variables to set on a crate's `rust_library::rustc_env` attribute.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="crate.annotation-rustc_env_files"></a>rustc_env_files |  A list of labels to set on a crate's `rust_library::rustc_env_files` attribute.   | List of strings | optional |  `[]`  |
| <a id="crate.annotation-rustc_flags"></a>rustc_flags |  A list of strings to set on a crate's `rust_library::rustc_flags` attribute.   | List of strings | optional |  `[]`  |
| <a id="crate.annotation-shallow_since"></a>shallow_since |  An optional timestamp used for crates originating from a git repository instead of a crate registry. This flag optimizes fetching the source code.   | String | optional |  `""`  |
| <a id="crate.annotation-version"></a>version |  The versions of the crate the annotation is applied to. Defaults to all versions.   | String | optional |  `"*"`  |

<a id="crate.from_specs"></a>

### from_specs

Generates a repo @crates from the defined `spec` tags

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="crate.from_specs-name"></a>name |  The name of the repo to generate   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | optional |  `"crates"`  |
| <a id="crate.from_specs-cargo_config"></a>cargo_config |  A [Cargo configuration](https://doc.rust-lang.org/cargo/reference/config.html) file.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="crate.from_specs-generate_binaries"></a>generate_binaries |  Whether to generate `rust_binary` targets for all the binary crates in every package. By default only the `rust_library` targets are generated.   | Boolean | optional |  `False`  |
| <a id="crate.from_specs-generate_build_scripts"></a>generate_build_scripts |  Whether or not to generate [cargo build scripts](https://doc.rust-lang.org/cargo/reference/build-scripts.html) by default.   | Boolean | optional |  `True`  |
| <a id="crate.from_specs-supported_platform_triples"></a>supported_platform_triples |  A set of all platform triples to consider when generating dependencies.   | List of strings | optional |  `["aarch64-unknown-linux-gnu", "aarch64-unknown-nixos-gnu", "i686-apple-darwin", "i686-pc-windows-msvc", "i686-unknown-linux-gnu", "x86_64-apple-darwin", "x86_64-pc-windows-msvc", "x86_64-unknown-linux-gnu", "x86_64-unknown-nixos-gnu", "aarch64-apple-darwin", "aarch64-apple-ios-sim", "aarch64-apple-ios", "aarch64-fuchsia", "aarch64-linux-android", "aarch64-pc-windows-msvc", "arm-unknown-linux-gnueabi", "armv7-linux-androideabi", "armv7-unknown-linux-gnueabi", "i686-linux-android", "i686-unknown-freebsd", "powerpc-unknown-linux-gnu", "riscv32imc-unknown-none-elf", "riscv64gc-unknown-none-elf", "s390x-unknown-linux-gnu", "thumbv7em-none-eabi", "thumbv8m.main-none-eabi", "wasm32-unknown-unknown", "wasm32-wasi", "x86_64-apple-ios", "x86_64-fuchsia", "x86_64-linux-android", "x86_64-unknown-freebsd", "x86_64-unknown-none", "aarch64-unknown-nto-qnx710"]`  |

<a id="crate.spec"></a>

### spec

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="crate.spec-artifact"></a>artifact |  Set to 'bin' to pull in a binary crate as an artifact dependency. Requires a nightly Cargo.   | String | optional |  `""`  |
| <a id="crate.spec-branch"></a>branch |  The git branch of the remote crate. Tied with the `git` param. Only one of branch, tag or rev may be specified. Specifying `rev` is recommended for fully-reproducible builds.   | String | optional |  `""`  |
| <a id="crate.spec-default_features"></a>default_features |  Maps to the `default-features` flag.   | Boolean | optional |  `True`  |
| <a id="crate.spec-features"></a>features |  A list of features to use for the crate.   | List of strings | optional |  `[]`  |
| <a id="crate.spec-git"></a>git |  The Git url to use for the crate. Cannot be used with `version`.   | String | optional |  `""`  |
| <a id="crate.spec-lib"></a>lib |  If using `artifact = 'bin'`, additionally setting `lib = True` declares a dependency on both the package's library and binary, as opposed to just the binary.   | Boolean | optional |  `False`  |
| <a id="crate.spec-package"></a>package |  The explicit name of the package.   | String | required |  |
| <a id="crate.spec-rev"></a>rev |  The git revision of the remote crate. Tied with the `git` param. Only one of branch, tag or rev may be specified.   | String | optional |  `""`  |
| <a id="crate.spec-tag"></a>tag |  The git tag of the remote crate. Tied with the `git` param. Only one of branch, tag or rev may be specified. Specifying `rev` is recommended for fully-reproducible builds.   | String | optional |  `""`  |
| <a id="crate.spec-version"></a>version |  The exact version of the crate. Cannot be used with `git`.   | String | optional |  `""`  |


