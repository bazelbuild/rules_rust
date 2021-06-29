<!-- Generated with Stardoc: http://skydoc.bazel.build -->
# Crate Universe

* [crate_universe](#crate_universe)
* [crate](#crate)

<a id="#crate_universe"></a>

## crate_universe

<pre>
crate_universe(<a href="#crate_universe-name">name</a>, <a href="#crate_universe-cargo_toml_files">cargo_toml_files</a>, <a href="#crate_universe-crate_registry_template">crate_registry_template</a>, <a href="#crate_universe-iso_date">iso_date</a>, <a href="#crate_universe-lockfile">lockfile</a>, <a href="#crate_universe-overrides">overrides</a>,
               <a href="#crate_universe-packages">packages</a>, <a href="#crate_universe-repo_mapping">repo_mapping</a>, <a href="#crate_universe-resolver_download_url_template">resolver_download_url_template</a>, <a href="#crate_universe-resolver_sha256s">resolver_sha256s</a>,
               <a href="#crate_universe-rust_toolchain_repository_template">rust_toolchain_repository_template</a>, <a href="#crate_universe-sha256s">sha256s</a>, <a href="#crate_universe-supported_targets">supported_targets</a>, <a href="#crate_universe-version">version</a>)
</pre>

A rule for downloading Rust dependencies (crates).

__WARNING__: This rule experimental and subject to change without warning.

Environment Variables:
- `REPIN`: Re-pin the lockfile if set (useful for repinning deps from multiple rulesets).
- `RULES_RUST_REPIN`: Re-pin the lockfile if set (useful for only repinning Rust deps).
- `RULES_RUST_CRATE_UNIVERSE_RESOLVER_URL_OVERRIDE`: Override URL to use to download resolver binary 
    - for local paths use a `file://` URL.
- `RULES_RUST_CRATE_UNIVERSE_RESOLVER_URL_OVERRIDE_SHA256`: An optional sha256 value for the binary at the override url location.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="crate_universe-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="crate_universe-cargo_toml_files"></a>cargo_toml_files |  A list of Cargo manifests (<code>Cargo.toml</code> files).   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="crate_universe-crate_registry_template"></a>crate_registry_template |  A template for where to download crates from for the default crate registry. This must contain <code>{version}</code> and <code>{crate}</code> templates.   | String | optional | "https://crates.io/api/v1/crates/{crate}/{version}/download" |
| <a id="crate_universe-iso_date"></a>iso_date |  The iso_date of cargo binary the resolver should use. Note: This can only be set if <code>version</code> is <code>beta</code> or <code>nightly</code>   | String | optional | "" |
| <a id="crate_universe-lockfile"></a>lockfile |  The path to a file which stores pinned information about the generated dependency graph. this target must be a file and will be updated by the repository rule when the <code>REPIN</code> environment variable is set. If this is not set, dependencies will be re-resolved more often, setting this allows caching resolves, but will error if the cache is stale.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="crate_universe-overrides"></a>overrides |  Mapping of crate name to specification overrides. See [crate.override](#crateoverride)  for more details.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="crate_universe-packages"></a>packages |  A list of crate specifications. See [crate.spec](#cratespec) for more details.   | List of strings | optional | [] |
| <a id="crate_universe-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | required |  |
| <a id="crate_universe-resolver_download_url_template"></a>resolver_download_url_template |  URL template from which to download the resolver binary. {host_triple} and {extension} will be filled in according to the host platform.   | String | optional | "{host_triple}{extension}" |
| <a id="crate_universe-resolver_sha256s"></a>resolver_sha256s |  Dictionary of host_triple -&gt; sha256 for resolver binary.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {"aarch64-apple-darwin": "{aarch64-apple-darwin--sha256}", "aarch64-unknown-linux-gnu": "{aarch64-unknown-linux-gnu--sha256}", "x86_64-apple-darwin": "{x86_64-apple-darwin--sha256}", "x86_64-pc-windows-gnu": "{x86_64-pc-windows-gnu--sha256}", "x86_64-unknown-linux-gnu": "{x86_64-unknown-linux-gnu--sha256}"} |
| <a id="crate_universe-rust_toolchain_repository_template"></a>rust_toolchain_repository_template |  The template to use for finding the host <code>rust_toolchain</code> repository. <code>{version}</code> (eg. '1.53.0'), <code>{triple}</code> (eg. 'x86_64-unknown-linux-gnu'), <code>{system}</code> (eg. 'darwin'), and <code>{arch}</code> (eg. 'aarch64') will be replaced in the string if present.   | String | optional | "rust_{system}_{arch}" |
| <a id="crate_universe-sha256s"></a>sha256s |  The sha256 checksum of the desired rust artifacts   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="crate_universe-supported_targets"></a>supported_targets |  A list of supported [platform triples](https://doc.rust-lang.org/nightly/rustc/platform-support.html) to consider when resoliving dependencies.   | List of strings | optional | ["aarch64-apple-darwin", "aarch64-unknown-linux-gnu", "x86_64-apple-darwin", "x86_64-pc-windows-msvc", "x86_64-unknown-freebsd", "x86_64-unknown-linux-gnu"] |
| <a id="crate_universe-version"></a>version |  The version of cargo the resolver should use   | String | optional | "1.53.0" |


<a id="#crate.spec"></a>

## crate.spec

<pre>
crate.spec(<a href="#crate.spec-name">name</a>, <a href="#crate.spec-semver">semver</a>, <a href="#crate.spec-features">features</a>)
</pre>

A simple crate definition for use in the `crate_universe` rule.

__WARNING__: This rule experimental and subject to change without warning.

Example:

```python
load("@rules_rust//crate_universe:defs.bzl", "crate_universe", "crate")

crate_universe(
    name = "spec_example",
    packages = [
        crate.spec(
            name = "lazy_static",
            semver = "=1.4",
        ),
    ],
)
```


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="crate.spec-name"></a>name |  The name of the crate as it would appear in a crate registry.   |  none |
| <a id="crate.spec-semver"></a>semver |  The desired version ([semver](https://semver.org/)) of the crate   |  none |
| <a id="crate.spec-features"></a>features |  A list of desired [features](https://doc.rust-lang.org/cargo/reference/features.html).   |  <code>None</code> |


<a id="#crate.override"></a>

## crate.override

<pre>
crate.override(<a href="#crate.override-extra_bazel_data_deps">extra_bazel_data_deps</a>, <a href="#crate.override-extra_bazel_deps">extra_bazel_deps</a>, <a href="#crate.override-extra_build_script_bazel_data_deps">extra_build_script_bazel_data_deps</a>,
               <a href="#crate.override-extra_build_script_bazel_deps">extra_build_script_bazel_deps</a>, <a href="#crate.override-extra_build_script_env_vars">extra_build_script_env_vars</a>, <a href="#crate.override-extra_rustc_env_vars">extra_rustc_env_vars</a>,
               <a href="#crate.override-features_to_remove">features_to_remove</a>)
</pre>

A map of overrides for a particular crate

__WARNING__: This rule experimental and subject to change without warning.

Example:

```python
load("@rules_rust//crate_universe:defs.bzl", "crate_universe", "crate")

crate_universe(
    name = "override_example",
    # [...]
    overrides = {
        "tokio": crate.override(
            extra_rustc_env_vars = {
                "MY_ENV_VAR": "MY_ENV_VALUE",
            },
            extra_build_script_env_vars = {
                "MY_BUILD_SCRIPT_ENV_VAR": "MY_ENV_VALUE",
            },
            extra_bazel_deps = {
                # Extra dependencies are per target. They are additive.
                "cfg(unix)": ["@somerepo//:foo"],  # cfg() predicate.
                "x86_64-apple-darwin": ["@somerepo//:bar"],  # Specific triple.
                "cfg(all())": ["@somerepo//:baz"],  # Applies to all targets ("regular dependency").
            },
            extra_build_script_bazel_deps = {
                # Extra dependencies are per target. They are additive.
                "cfg(unix)": ["@buildscriptdep//:foo"],
                "x86_64-apple-darwin": ["@buildscriptdep//:bar"],
                "cfg(all())": ["@buildscriptdep//:baz"],
            },
            extra_bazel_data_deps = {
                # ...
            },
            extra_build_script_bazel_data_deps = {
                # ...
            },
        ),
    },
)
```


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="crate.override-extra_bazel_data_deps"></a>extra_bazel_data_deps |  Targets to add to the <code>data</code> attribute of the generated target (eg: [rust_library.data](./defs.md#rust_library-data)).   |  <code>None</code> |
| <a id="crate.override-extra_bazel_deps"></a>extra_bazel_deps |  Targets to add to the <code>deps</code> attribute of the generated target (eg: [rust_library.deps](./defs.md#rust_library-data)).   |  <code>None</code> |
| <a id="crate.override-extra_build_script_bazel_data_deps"></a>extra_build_script_bazel_data_deps |  Targets to add to the [data](./cargo_build_script.md#cargo_build_script-data) attribute of the generated <code>cargo_build_script</code> target.   |  <code>None</code> |
| <a id="crate.override-extra_build_script_bazel_deps"></a>extra_build_script_bazel_deps |  Targets to add to the [deps](./cargo_build_script.md#cargo_build_script-deps) attribute of the generated <code>cargo_build_script</code> target.   |  <code>None</code> |
| <a id="crate.override-extra_build_script_env_vars"></a>extra_build_script_env_vars |  Environment variables to add to the [build_script_env](./cargo_build_script.md#cargo_build_script-build_script_env) attribute of the generated <code>cargo_build_script</code> target.   |  <code>None</code> |
| <a id="crate.override-extra_rustc_env_vars"></a>extra_rustc_env_vars |  Environment variables to add to the <code>rustc_env</code> attribute for the generated target (eg: [rust_library.rustc_env](./defs.md#rust_library-rustc_env)).   |  <code>None</code> |
| <a id="crate.override-features_to_remove"></a>features_to_remove |  A list of features to remove from a generated target.   |  <code>[]</code> |


