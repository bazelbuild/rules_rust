# Rust Persistent Worker

The Rust Persistent Worker is itself implemented in Rust. It is built by invoking Cargo in bootstrap.bzl.

## Using the worker

Place the following in your project's .bazelrc:

```
build --@io_bazel_rules_rust//worker:use_worker=True
build:windows --worker_quit_after_build
```

This code is still experimental, and has not had a lot of testing. It may
change or go away at any time.

## Why is this built by invoking Cargo directly?

Because the rust_binary() and similar rules depend on a worker toolchain (even a dummy one), we can't
use them to build the worker binary - it results in a cyclic dependency. So bootstrap.bzl calls
cargo to fetch the dependencies and build the worker.

## How about rewriting the worker in C++?

That is certainly an option!
