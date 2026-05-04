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
coverage --instrument_test_targets
```

The `--instrument_test_targets` flag is recommended because Rust test binaries (`rust_test`) often compile library source code directly into the test binary (e.g., when using the `crate` attribute). Without this flag, test targets are excluded from instrumentation by default, which means library code compiled into the test binary would not produce coverage data.

To further exclude specific directories:

```text
coverage --instrumentation_filter=^//,-^//third_party
```

### Flags Summary

| Flag | Purpose |
|------|---------|
| `--instrumentation_filter=<regex>` | Controls which targets are instrumented. Default: `-/javatests[/:],-/test/java[/:]` |
| `--instrument_test_targets` | Also instrument test targets. Recommended for Rust. |
| `--combined_report=lcov` | Produce a combined LCOV report (set by default with `bazel coverage`). |
