# Rules Rust

This repository provides rules for building [Rust][rust] projects with [Bazel][bazel].

[bazel]: https://bazel.build/
[rust]: http://www.rust-lang.org/

<!-- TODO: Render generated docs on the github pages site again, https://bazelbuild.github.io/rules_rust/ -->

<a name="setup"></a>

## Setup

The rules are released, and releases can be found on [the GitHub Releases page](https://github.com/bazelbuild/rules_rust/releases). We recommend using the latest release from that page.

### Bzlmod

Note that rules_rust bzlmod support is still a work in progress. Most features should work, but bugs are more likely. This is not a desired end-state - please report (or better yet, help fix!) bugs you run into.

To use `rules_rust` in a project using bzlmod, add the following to your `MODULE.bazel` file:

```python
bazel_dep(name = "rules_rust", version = "0.63.0")
```

Don't forget to substitute in your desired release's version number.

### WORKSPACE

To use `rules_rust` in a project using a WORKSPACE file, add the following to your `WORKSPACE` file to add the external repositories for the Rust toolchain:

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# To find additional information on this release or newer ones visit:
# https://github.com/bazelbuild/rules_rust/releases
http_archive(
    name = "rules_rust",
    integrity = "sha256-Weev1uz2QztBlDA88JX6A1N72SucD1V8lBsaliM0TTg=",
    urls = ["https://github.com/bazelbuild/rules_rust/releases/download/0.48.0/rules_rust-v0.48.0.tar.gz"],
)

load("@rules_rust//rust:repositories.bzl", "rules_rust_dependencies", "rust_register_toolchains")

rules_rust_dependencies()

rust_register_toolchains()
```

Don't forget to substitute in your desired release's version number and integrity hash.

## Specifying Rust version

### Bzlmod

To use a particular version of the Rust compiler, pass that version to the `toolchain` method of the `rust` extension, like this:

```python
rust = use_extension("@rules_rust//rust:extensions.bzl", "rust")
rust.toolchain(
    edition = "2024",
    versions = [ "1.85.0" ],
)
```

As well as an exact version, `versions` can accept `nightly/{iso_date}` and `beta/{iso_date}` strings for toolchains from different release channels, as in

```python
rust.toolchain(
    edition = "2021",
    versions = [ "nightly/1.85.0" ],
)
```

By default, a `stable` and `nightly` toolchain will be registered if no `toolchain` method is called (and thus no specific versions are registered). However, if only 1 version is passed and it is from the `nightly` or `beta` release channels (i.e. __not__ `stable`), then the following build setting flag must be present, either on the command line or set in the project's `.bazelrc` file:

```text
build --@rules_rust//rust/toolchain/channel=nightly
```

Failure to do so will result in rules attempting to match a `stable` toolchain when one was not registered, thus raising an error.

### WORKSPACE

To build with a particular version of the Rust compiler when using a WORKSPACE file, pass that version to `rust_register_toolchains`:

```python
rust_register_toolchains(
    edition = "2021",
    versions = [
        "1.79.0"
    ],
)
```

Like in the Bzlmod approach, as well as an exact version, `versions` can accept `nightly/{iso_date}` and `beta/{iso_date}` strings for toolchains from different release channels.

```python
rust_register_toolchains(
    edition = "2021",
    versions = [
        "nightly/2024-06-13",
    ],
)
```

Here too a `stable` and `nightly` toolchain will be registered by default if no versions are passed to `rust_register_toolchains`. However,
if only 1 version is passed and it is from the `nightly` or `beta` release channels (i.e. __not__ `stable`), then the following build setting flag must
also be set either in the command line or in the project's `.bazelrc` file.

```text
build --@rules_rust//rust/toolchain/channel=nightly
```

Failure to do so will result in rules attempting to match a `stable` toolchain when one was not registered, thus raising an error.

## Supported bazel versions

The oldest version of Bazel the `main` branch is tested against is `7.4.1`. Previous versions may still be functional in certain environments, but this is the minimum version we strive to fully support.

We test these rules against the latest rolling releases of Bazel, and aim for compatibility with them, but prioritise stable releases over rolling releases where necessary.

### WORKSPACE support

WORKSPACE support is officially tested with Bazel 7 for as long as that is the min supported version. While it may work with later versions, compatibility with those versions is not guaranteed or actively verified.

## Supported platforms

We aim to support Linux and macOS.

We do not have sufficient maintainer expertise to support Windows. Most things probably work, but we have had to disable many tests in CI because we lack the expertise to fix them. We welcome contributions to help improve its support.
