# Contributing

## Tour of the codebase

We start at `defs.bzl`, which invokes the resolver.

The resolver:

- `config.rs`: Deserializes the Config
- `parser.rs`: Parses the Config, any `Cargo.toml` files, and any additional packages, into a single unified `Cargo.toml` file
- `resolver.rs`: Resolves all of the crates.
- `consolidator.rs`: Patches in any WORKSPACE-specified overrides, and deals with platform-specific concerns.
- `renderer.rs`: Generates BUILD files for each crate, as well as functions that can be called from BUILD files.

The code started off as a very hacky Week of Code project, and there are some clear remnants of that in the codebase - nothing is sacred, feel free to improve anything!

Some areas have unit testing, there are a few (very brittle) integration tests, and some examples.

## How to test local changes

To use a local version, first bootstrap it:

```console
rules_rust $ ./bootstrap.sh
```

This will build `crate_universe_resolver` and generate a `crate_universe.bazelrc` file which contains
[override_repository](https://docs.bazel.build/versions/master/command-line-reference.html#flag--override_repository)
definitions fo the newly built binary. For more details on the build process, see
[crate_universe/private/bootstrap/README.md](./private/bootstrap/README.md).

To get verbose logging, edit `defs.bzl` to set `RUST_LOG` to `debug` or `trace` instead of `info`. In particular, that will print out the generated `Cargo.toml`, and the path to the generated workspace file.

Note that you may need to `bazel shutdown` between Bazel commands. Hopefully not, but if you're seeing stale results, try it out. This only affects local development.

## Testing

To test with the `resolver` built from source:

```bash
bin/test
```
