This directory contains code from [tinyjson](https://github.com/rhysd/tinyjson).

It's vendored in rules_rust as a workaround for an issue where, if tinyjson were built as an independent crate, the resulting library would contain absolute path strings pointing into the Bazel sandbox directory, breaking build reproducibility. (https://github.com/bazelbuild/rules_rust/issues/1530)
