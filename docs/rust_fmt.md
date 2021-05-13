# Rust Fmt

* [rustfmt](#rustfmt)
* [rustfmt_aspect](#rustfmt_aspect)
* [rustfmt_check](#rustfmt_check)

<a id="#rustfmt_check"></a>

## rustfmt_check

<pre>
rustfmt_check(<a href="#rustfmt_check-name">name</a>, <a href="#rustfmt_check-targets">targets</a>)
</pre>

A rule for defining a target which runs `rustfmt` in `--check` mode on an explicit list of targets

For more information on the use of `rustfmt` directly, see [rustfmt_aspect](#rustfmt_aspect).


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rustfmt_check-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rustfmt_check-targets"></a>targets |  Rust targets to run rustfmt on.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |


<a id="#rustfmt"></a>

## rustfmt

<pre>
rustfmt(<a href="#rustfmt-name">name</a>, <a href="#rustfmt-config">config</a>)
</pre>

A macro defining a [rustfmt](https://github.com/rust-lang/rustfmt#readme) runner.

This macro is used to generate a rustfmt binary which can be run to format the Rust source
files of `rules_rust` targets in the workspace. To define this target, simply load and call
it in a BUILD file.

eg: `//:BUILD.bazel`

```python
load("@rules_rust//rust:defs.bzl", "rustfmt")

rustfmt(
    name = "rustfmt",
)
```

This now allows users to run `bazel run //:rustfmt` to format any target which provides `CrateInfo`.

This binary also supports accepts a [label](https://docs.bazel.build/versions/master/build-ref.html#labels) or
pattern (`//my/package/...`) to allow for more granular control over what targets get formatted. This
can be useful when dealing with larger projects as `rustfmt` can only be run on a target which successfully
builds. Given the following workspace layout:

```
WORKSPACE.bazel
BUILD.bazel
package_a/
    BUILD.bazel
    src/
        lib.rs
        mod_a.rs
        mod_b.rs
package_b/
    BUILD.bazel
    subpackage_1/
        BUILD.bazel
        main.rs
    subpackage_2/
        BUILD.bazel
        main.rs
```

Users can choose to only format the `rust_lib` target in `package_a` using `bazel run //:rustfmt -- //package_a:rust_lib`.
Additionally, users can format all of `package_b` using `bazel run //:rustfmt -- //package_b/...`.

Users not looking to add a custom `rustfmt` config can simply run the `@rules_rust//tools/rustfmt` to avoid defining their
own target.

Note that generated sources will be ignored and targets tagged as `norustfmt` will be skipped.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rustfmt-name"></a>name |  The name of the rustfmt runner   |  none |
| <a id="rustfmt-config"></a>config |  The [rustfmt config](https://rust-lang.github.io/rustfmt/) to use.   |  <code>Label("//tools/rustfmt:rustfmt.toml")</code> |


<a id="#rustfmt_aspect"></a>

## rustfmt_aspect

<pre>
rustfmt_aspect(<a href="#rustfmt_aspect-name">name</a>)
</pre>

This aspect is used to gather information about a crate for use in rustfmt and perform rustfmt checks

Output Groups:

- `rustfmt_manifest`: The `rustfmt_manifest` output is used directly by [rustfmt](#rustfmt) targets
to determine the appropriate flags to use when formatting Rust sources. For more details on how to
format source code, see the [rustfmt](#rustfmt) rule.

- `rustfmt_checks`: Executes rustfmt in `--check` mode on the specified target. To enable this check
for your workspace, simply add the following to the `.bazelrc` file in the root of any workspace
which loads `rules_rust`:
```
build --aspects=@rules_rust//rust:defs.bzl%rustfmt_aspect
build --output_groups=+rustfmt_checks
```

This aspect is executed on any target which provides the `CrateInfo` provider. However
users may tag a target with `norustfmt` to have it skipped. Additionally, generated
source files are also ignored by this aspect.


**ASPECT ATTRIBUTES**



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rustfmt_aspect-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |   |


