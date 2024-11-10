# rules_rust with bazel_env

This example uses [bazel_env.bzl](https://github.com/buildbuddy-io/bazel_env.bzl) to
provide `cargo`, `cargo-clippy`, `rustc` and `rustfmt` from the bazel toolchains
to the user. They will be available directly in the PATH when the user
enters this directory and has [direnv](https://direnv.net/) set up.

Advantages:

- The user doesn't have to install the toolchains themselves.
- The tool versions will always match exactly those that bazel uses.
