# rust_test Output Path Uniqueness

## Overview of the problem

On some platforms, including Windows, Bazel runs local actions in a shared
execroot without sandboxing (`--spawn_strategy=standalone`). If two actions
generate intermediate files with the same path, then executing them concurrently
may cause non-deterministic failures due to one action overwriting the files
created by another.

This is known to affect `rust_test` and `rust_binary` targets when built from
the same crate. A representative error message that may occur is:

```
= note: bin_with_transitive_proc_macro.bin_with_transitive_proc_macro.573369dc-cgu.3.rcgu.o :
  error LNK2019:
  unresolved external symbol _ZN4test16test_main_static17h3f2f4fbff47df3a8E
  referenced in function _ZN30bin_with_transitive_proc_macro4main17h28726504dc060f8dE
```

## The hash prefix workaround

PR [rules_rust#1434](https://github.com/bazelbuild/rules_rust/pull/1434) added
a workaround by configuring `rust_test` targets to write their output files to
a hash prefix computed from the crate info and Bazel label. This workaround is
transparent to most users, as it does not affect the behavior or output of
`bazel test //path/to:my_rust_test`.

## Disabling

In some cases the path of the `rust_test` binary must be made predictable, for
example when they need to be located in the runfiles of a wrapper test. To
disable the `rust_test` hash prefix workaround, set the Bazel build setting
`@rules_rust//rust/settings:rust_test_prefix_output_files` to `false`.
