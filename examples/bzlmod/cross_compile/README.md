# bzlmod cross-compile example

This example shows how to use `rules_rust` through bzlmod to invoke Rust cross-compilation.

It should be possible to `bazel build //:hello_world_aarch64` and `bazel build //:hello_world_x86_64` regardless of your
host platform (as long as it is supported by Bazel and rustc).
