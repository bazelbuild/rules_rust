# insta snapshot tests

An example for working with [insta](https://crates.io/crates/insta) snapshot tests.

The `rust_snapshot_test` macro creates a `rust_test` rule with an accompanying executable
rule that updates snapshots in the source tree, similar to a [write_source_files](https://registry.bazel.build/docs/bazel_lib/3.0.0#lib-write_source_files-bzl) flow.

Run snapshot tests:
```bash
bazel test //:test
```

Update snapshots in the source tree:
```bash
bazel run //:test_update_snapshots
```

## Limitations

* Does not include a helpful message like write_source_files that outputs the update command when snapshot tests fail.
* Always writes snapshots to the source tree even if they haven't changed.
* This is intended as a toy example; there are probably edge cases not covered.
