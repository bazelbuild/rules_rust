<!-- Generated with Stardoc: http://skydoc.bazel.build -->
# Rust Fmt

* [rustfmt_aspect](#rustfmt_aspect)
* [rustfmt_test](#rustfmt_test)


## Overview


[Rustfmt][rustfmt] is a tool for formatting Rust code according to style guidelines. 
By default, Rustfmt uses a style which conforms to the [Rust style guide][rsg] that
has been formalized through the [style RFC process][rfcp]. A complete list of all
configuration options can be found in the [Rustfmt GitHub Pages][rgp].



### Setup


Formatting your Rust targets' source code requires no setup outside of loading `rules_rust`
in your workspace. Simply run `bazel run @rules_rust//:rustfmt` to format source code.

In addition to this formatter, a check can be added to your build phase using the [rustfmt_aspect](#rustfmt-aspect)
aspect. Simply add the following to a `.bazelrc` file to enable this check.

```text
build --aspects=@rules_rust//rust:defs.bzl%rustfmt_aspect
build --output_groups=+rustfmt_checks
```

It's recommended to only enable this aspect in your CI environment so formatting issues do not
impact user's ability to rapidly iterate on changes.

The `rustfmt_aspect` also uses a `--@rules_rust//:rustfmt.toml` setting which determines the
[configuration file][rgp] used by the formatter (`@rules_rust//tools/rustfmt`) and the aspect
(`rustfmt_aspect`). This flag can be added to your `.bazelrc` file to ensure a consistent config
file is used whenever `rustfmt` is run:

```text
build --@rules_rust//:rustfmt.toml=//:rustfmt.toml
```

[rustfmt]: https://github.com/rust-lang/rustfmt#readme
[rsg]: https://github.com/rust-lang-nursery/fmt-rfcs/blob/master/guide/guide.md
[rfcp]: https://github.com/rust-lang-nursery/fmt-rfcs
[rgp]: https://rust-lang.github.io/rustfmt/

<a id="rustfmt_test"></a>

## rustfmt_test

<pre>
rustfmt_test(<a href="#rustfmt_test-name">name</a>, <a href="#rustfmt_test-targets">targets</a>)
</pre>

A test rule for performing `rustfmt --check` on a set of targets

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rustfmt_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="rustfmt_test-targets"></a>targets |  Rust targets to run <code>rustfmt --check</code> on.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |


<a id="rustfmt_aspect"></a>

## rustfmt_aspect

<pre>
rustfmt_aspect(<a href="#rustfmt_aspect-name">name</a>)
</pre>

This aspect is used to gather information about a crate for use in rustfmt and perform rustfmt checks

Output Groups:

- `rustfmt_manifest`: A manifest used by rustfmt binaries to provide crate specific settings.
- `rustfmt_checks`: Executes `rustfmt --check` on the specified target.

The build setting `@rules_rust//:rustfmt.toml` is used to control the Rustfmt [configuration settings][cs]
used at runtime.

[cs]: https://rust-lang.github.io/rustfmt/

This aspect is executed on any target which provides the `CrateInfo` provider. However
users may tag a target with `no-rustfmt` or `no-format` to have it skipped. Additionally,
generated source files are also ignored by this aspect.


**ASPECT ATTRIBUTES**



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rustfmt_aspect-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |   |


