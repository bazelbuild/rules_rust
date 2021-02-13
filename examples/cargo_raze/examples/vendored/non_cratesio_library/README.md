# non_cratesio_library

## How to build

In order to build this example, the dependencies must be vendored. This can be achieved by performing the following:

1. Navigate to `./examples/vendored/non_cratesio_library` from the root of the `cargo-raze` checkout
2. Run `cargo vendor --versioned-dirs cargo/vendor`
3. Rerun `cargo raze` to regenerate the Bazel BUILD files

At this point you should now be able to run `bazel build ...` to compile the source code.
