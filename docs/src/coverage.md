# Code Coverage

Rules Rust supports collecting code coverage data using `bazel coverage`, leveraging LLVM's source-based coverage instrumentation.

## Basic Usage

```sh
bazel coverage //my_project/...
```

This instruments all targets matching the default `--instrumentation_filter` and produces an LCOV report at `bazel-out/_coverage/_coverage_report.dat`.

## Controlling Instrumentation

Rules Rust respects Bazel's standard [`--instrumentation_filter`](https://bazel.build/reference/command-line-reference#flag--instrumentation_filter) flag to control which targets get compiled with `-Cinstrument-coverage`. Only targets whose label matches the filter are instrumented, consistent with how coverage works for other languages (C++, Java).

### Recommended `.bazelrc` Settings

For projects with vendored or third-party dependencies, restrict instrumentation to workspace targets to avoid unnecessary recompilation:

```text
coverage --instrumentation_filter=^//
```

To further exclude specific directories:

```text
coverage --instrumentation_filter=^//,-^//third_party
```

### `rust_test` with a `crate` attribute

When a `rust_test` target uses the `crate` attribute, Rust compiles the library source code directly into the test binary. Rules Rust automatically checks whether the underlying crate should be instrumented, so library code compiled into the test binary produces coverage data without needing `--instrument_test_targets`.

Note: because the entire crate (including `#[cfg(test)]` code) is compiled as one unit, test-specific code in the crate will also be instrumented. This is a known inconsistency with the usual Bazel convention where test code is only instrumented when `--instrument_test_targets` is set.

### `--instrument_test_targets`

By default, Bazel excludes test targets from instrumentation. If you want coverage of the test code itself (not just the libraries it exercises), add:

```text
coverage --instrument_test_targets
```

### Flags Summary

| Flag | Purpose |
|------|---------|
| `--instrumentation_filter=<regex>` | Controls which targets are instrumented. Default: `-/javatests[/:],-/test/java[/:]` |
| `--instrument_test_targets` | Also instrument test targets. Not required for library coverage via `rust_test` with `crate`. |
| `--combined_report=lcov` | Produce a combined LCOV report (set by default with `bazel coverage`). |
