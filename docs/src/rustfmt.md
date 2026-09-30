# Rustfmt

[Rustfmt][rustfmt] is a tool for formatting Rust code according to style guidelines.
By default, Rustfmt uses a style which conforms to the [Rust style guide][rsg] that
has been formalized through the [style RFC process][rfcp]. A complete list of all
configuration options can be found in the [Rustfmt GitHub Pages][rgp].

[rustfmt]: https://github.com/rust-lang/rustfmt#readme
[rsg]: https://github.com/rust-lang-nursery/fmt-rfcs/blob/master/guide/guide.md
[rfcp]: https://github.com/rust-lang-nursery/fmt-rfcs
[rgp]: https://rust-lang.github.io/rustfmt/

## Setup

Formatting your Rust targets' source code requires no setup outside of loading `rules_rust`
in your workspace. Simply run `bazel run @rules_rust//:rustfmt` to format source code.

The runner accepts two sets of arguments separated by a trailing `--`:

```text
bazel run @rules_rust//:rustfmt -- <runner args> -- <rustfmt args>
```

Arguments before the separator scope which packages/targets are formatted (e.g.
`//my/pkg/...`). Arguments after the separator are forwarded directly to
`rustfmt`. To pass only `rustfmt` flags, use an empty runner arg list:

```text
bazel run @rules_rust//:rustfmt -- -- --check
```

In addition to this formatter, a simple check can be performed using the
[rustfmt_aspect](./rustfmt_aspect.md) aspect by running:

```text
bazel build --aspects=@rules_rust//rust:defs.bzl%rustfmt_aspect --output_groups=rustfmt_checks
```

Add the following to a `.bazelrc` file to enable this check during the build phase:

```text
build --aspects=@rules_rust//rust:defs.bzl%rustfmt_aspect
build --output_groups=+rustfmt_checks
```

It's recommended to only enable this aspect in your CI environment so formatting issues do
not impact users' ability to rapidly iterate on changes.

The `rustfmt_aspect` also uses a `--@rules_rust//rust/settings:rustfmt.toml` setting which
determines the [configuration file][rgp] used by the formatter (`@rules_rust//tools/rustfmt`)
and the aspect. This flag can be added to your `.bazelrc` file to ensure a consistent config
file is used whenever `rustfmt` is run:

```text
build --@rules_rust//rust/settings:rustfmt.toml=//:rustfmt.toml
```

## Rules

- [rustfmt_aspect](./rustfmt_aspect.md) — Aspect that runs `rustfmt --check` on every Rust
  target in the build. Attach in `.bazelrc` (as shown in Setup) to gate CI on formatting.
- [rustfmt_test](./rustfmt_test.md) — Test rule that reports rustfmt findings as a test
  failure for a specific target.
