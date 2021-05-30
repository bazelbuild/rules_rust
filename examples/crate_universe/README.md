# `crate_universe` examples

### Instructions

Set the `RULES_RUST_CRATE_UNIVERSE_BOOTSTRAP` environment variable to `true`

```bash
$ export RULES_RUST_CRATE_UNIVERSE_BOOTSTRAP=true
```

Build the examples

```bash
$ bazel build //...
```

Run the examples' tests

```bash
$ bazel test //...
```

