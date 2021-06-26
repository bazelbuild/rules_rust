# Crate Universe

## Experimental!

**Note**: `crate_universe` is experimental, and may have breaking API changes at any time. These instructions may also change without notice.

## What is it?

Crate Universe is akin to a modified version of cargo-raze that can be run as
part of a Bazel build. Instead of generating BUILD files in advance with
cargo-raze, the BUILD files can be created automatically at build time. It can
expose crates gathered from Cargo.toml files like cargo-raze does, and also
supports declaring crates directly in BUILD files, for cases where compatibility
with Cargo is not required.

## Workspace installation

To avoid having to build a Rust binary, pre-made releases are made
available.

1. Find the most up-to-date `crate_universe` release at https://github.com/bazelbuild/rules_rust/releases.
2. Copy and paste the text into a file like `crate_universe_defaults.bzl` in your repo.
3. Add something like the following to your `WORKSPACE.bazel` file:

```python
load("//3rdparty/rules_rust:crate_universe_defaults.bzl", "DEFAULT_URL_TEMPLATE", "DEFAULT_SHA256_CHECKSUMS")

load("@rules_rust//crate_universe:defs.bzl", "crate", "crate_universe")

crate_universe(
    name = "crates",
    cargo_toml_files = [
        "//some_crate:Cargo.toml",
        "//some_other:Cargo.toml",
    ],
    resolver_download_url_template = DEFAULT_URL_TEMPLATE,
    resolver_sha256s = DEFAULT_SHA256_CHECKSUMS,
    # leave unset for default multi-platform support
    supported_targets = [
        "x86_64-apple-darwin",
        "x86_64-unknown-linux-gnu",
    ],
    # [package.metadata.raze.xxx] lines in Cargo.toml files are ignored;
    # the overrides need to be declared in the repo rule instead.
    overrides = {
        "example-sys": crate.override(
            extra_build_script_env_vars = {"PATH": "/usr/bin"},
        ),
    },
    # to use a lockfile, uncomment the following line,
    # create an empty file in the location, and then build
    # with REPIN=1 bazel build ...
    #lockfile = "//:crate_universe.lock",
)

load("@crates//:defs.bzl", "pinned_rust_install")

pinned_rust_install()
```

In the above example, two separate Cargo.toml files have been
provided. Multiple Cargo.toml can be provided, and crate_universe
will combine them together to ensure each crate uses a common version.

This is similar to a Cargo workspace, and can be used with an existing
workspace. But some things to note:

- the top level workspace Cargo.toml, if one exists, should not be
  included in cargo_toml_files, as it does not list any dependencies by itself
- presently any existing Cargo.lock file is ignored, as crate_universe does its
  own resolution and locking. You can uncomment the lockfile line above to
  enable a separate lockfile for crate_universe; if left disabled, versions will
  float, like if you were to remove the Cargo.lock file each time you updated a
  Cargo.toml file in a Cargo workspace. Currently the lockfile is in a custom
  format; in the future, the Cargo.lock file may be used instead.

## Build file usage

With the crates declared in the workspace, they can now be referenced in BUILD
files. For example:

```python
load("@crates//:defs.bzl", "build_crates_from", "crates_from")

cargo_build_script(
    name = "build",
    srcs = ["build.rs"],
    deps = build_crates_from("//some_crate:Cargo.toml"),
)

rust_library(
    name = "some_crate",
    srcs = [
        "lib.rs",
    ],
    deps = crates_from("//some_crate:Cargo.toml") + [":build"]
)
```

If you prefer, you can also list out each crate individually, eg:

```python
load("@crates//:defs.bzl", "crate")

rust_library(
    name = "some_crate",
    srcs = [
        "lib.rs",
    ],
    deps = [crate("serde"), crate("log"), ":build"]
)
```

See [some more examples](../examples/crate_universe) and the [API docs](https://bazelbuild.github.io/rules_rust/crate_universe.html) for more info.
