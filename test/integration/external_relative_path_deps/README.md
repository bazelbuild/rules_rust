# External Relative Path Dependencies Test (Issue #3089)

This test validates that crate_universe correctly handles Cargo workspace members
with path dependencies that point **outside the Cargo workspace root** (but still
inside the Bazel workspace).

## Structure

```
external_relative_path_deps/     # Bazel workspace root
├── MODULE.bazel
├── BUILD.bazel
├── external_crate/              # Outside Cargo workspace, inside Bazel workspace
│   ├── Cargo.toml
│   └── src/lib.rs
└── cargo_workspace/             # Cargo workspace root
    ├── Cargo.toml               # [workspace] with members = ["member"]
    ├── Cargo.lock
    └── member/
        ├── Cargo.toml           # Has path = "../../external_crate"
        └── src/lib.rs
```

## The Bug

When `cargo_workspace/member/Cargo.toml` has:
```toml
[dependencies]
external_crate = { path = "../../external_crate" }
```

crate_universe fails because it doesn't copy `external_crate` into the temp
directory used for splicing.

## Running the test

```sh
cd test/integration/external_relative_path_deps
bazel build //cargo_workspace/member
```
