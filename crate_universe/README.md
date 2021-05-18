# Crate Universe

## How to use

**Note**: `crate_universe` is experimental, and may have breaking API changes at any time. These instructions may also change without notice.

Find the most up-to-date `crate_universe` release at https://github.com/bazelbuild/rules_rust/releases
and add the `crate_universe_defaults.bzl` file to your workspace (eg
`./3rdparty/rules_rust/crate_universe_defaults.bzl).

With this in place, the following can be added to your `WORKSPACE.bazel` file.

```python
load("//3rdparty/rules_rust:crate_universe_defaults.bzl", "DEFAULT_URL_TEMPLATE", "DEFAULT_SHA256_CHECKSUMS")

load("@rules_rust//crate_universe:defs.bzl", "crate_universe_deps")

crate_universe_deps(url_template = DEFAULT_URL_TEMPLATE, sha256s = DEFAULT_SHA256_CHECKSUMS)
```

The `crate_universe` macro can now be used within your workspace. See the [examples](../examples/crate_universe) for
more context.
