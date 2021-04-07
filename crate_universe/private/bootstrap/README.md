# Crate Universe Bootstrap

This workspace contains tools for bootstrapping `crate_universe` binaries.

## Build

Users can use Bazel to build a binary for the current host by running `bazel run //:build`.

If a user is looking to build binaries for all supported platforms, they should simply run
`./build.sh` directly.

### Dependencies

When running `./build.sh` directly, the script expects [Cargo](https://doc.rust-lang.org/cargo/) to be
installed on the host and will attempt to find or install [cross](https://github.com/rust-embedded/cross)
which depends on [Docker](https://www.docker.com/).

#### Installing Dependencies

- `Cargo`: use [rustup](https://rustup.rs/).
- `Cross`: run `cargo install cross`
- `Docker`: Follow [this guide](https://docs.docker.com/engine/install/)

### Artifacts

Artifacts can be found in `./bin` once `./build.sh` is run.
