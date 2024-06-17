"""# Crate Universe

Crate Universe is a set of Bazel rule for generating Rust targets using Cargo.

This doc describes using crate_universe with bzlmod.

If you're using a WORKSPACE file, please see [the WORKSPACE equivalent of this doc](crate_universe.html).

There are some examples of using crate_universe with bzlmod:

* https://github.com/bazelbuild/rules_rust/blob/main/examples/bzlmod/hello_world/MODULE.bazel
* https://github.com/bazelbuild/rules_rust/blob/main/examples/bzlmod/override_target/MODULE.bazel
* https://github.com/bazelbuild/rules_rust/blob/main/examples/bzlmod/all_crate_deps/MODULE.bazel
"""

load(
    "//crate_universe:extension.bzl",
    _crate = "crate",
)

crate = _crate
