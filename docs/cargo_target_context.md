# Cargo target context

Generators implementing Cargo resolver v2 can set
`@rules_rust//cargo/settings:cargo_target_triple` to `target/<triple>` before
entering a dependency graph. This optional string setting identifies the original
Cargo target. It does not select a compiler toolchain or change the Bazel platform.
The empty default leaves the feature disabled.

Rust target configurations retain the `target/` marker. When a dependency enters
an execution configuration, its Rust rule removes the marker. The original triple
then remains available to selects even when the actual compiler target is the host
platform. This also distinguishes the target and execution copies on native builds.

For example, a generator can select target features using
`target/aarch64-apple-darwin` and build-dependency features using
`aarch64-apple-darwin`. The latter may be compiled for a different execution host.
The generator is responsible for setting the original value and generating the
corresponding config settings; rules_rust does not resolve Cargo features.

`cargo_target_triple_map` optionally canonicalizes execution contexts for a rule.
Use it only when mapped contexts have identical dependencies and features. Values
must be stable under repeated application, including in dependencies that inherit
them. Target configurations are never remapped. `cargo_build_script` forwards the
map to the Rust binary that compiles its build script.

```starlark
rust_library(
    name = "shared_build_dependency",
    srcs = ["lib.rs"],
    cargo_target_triple_map = {
        "aarch64-apple-darwin": "invariant",
        "x86_64-unknown-linux-gnu": "invariant",
    },
)
```

The build setting uses the default universal scope, preserving it through Bazel's
execution transitions. No setting is needed for ordinary rules_rust users.
