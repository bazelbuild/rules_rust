# Ring Example

This example demonstrates how to use the `ring` cryptographic crate with Bazel using the `from_cargo` API.

## Setup

The example uses:
- `Cargo.toml` with ring 0.17.4 as a dependency
- `MODULE.bazel` that uses the crate_universe extension with `from_cargo`
- A simple Rust binary that demonstrates ring functionality

## Building

### Build the ring crate only:
```bash
bazel build --noremote_accept_cached @crates//:ring
```

### Build the demo application:
```bash
bazel build //:ring_demo
```

### Run the demo application:
```bash
bazel run //:ring_demo
```

## Target Names

The ring crate is available with these target names:
- `@crates//:ring` - Generic alias
- `@crates//:ring-0.17.14` - Version-specific name (version may vary)

## Notes

- The example resolves ring 0.17.4 to 0.17.14 (latest compatible version)
- Uses `from_cargo` with a standard `Cargo.toml` and `Cargo.lock`
- Demonstrates both SHA-256 hashing and random number generation with ring 
