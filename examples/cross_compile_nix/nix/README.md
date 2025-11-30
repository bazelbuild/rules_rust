# Nix

Nix Flake that supplies toolchains and SDKs for cross compiling.

This is kept in its own package so that when using the Nix `path:` syntax, only
this directory is copied to the Nix Store instead of the entire `rules_rust`
repository.

See also: `//bazel/nix_repositories.bzl`
