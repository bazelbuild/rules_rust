
This directory demonstrates an example of how to rebuild the standard library
for an arbitrary platform and custom configurations.

TODO: Write up on how the toolchain bootrapping process works.

To build an end-user rust_library target for specific target, run

```
bazel build //hello_lib --platforms=//:aarch64-apple-darwin
```

for `aarch64-apple-darwin` or

```
bazel build //hello_lib --platforms=//:wasm32-wasi
```

for `wasm32-wasi`.

The toolchains orderly registered in WORKSPACE and _beta_channel_transition ensure
that the standard library is rebuilt for the given platform.

To only rebuild std, run

```
bazel build @stdlbs//:std --platforms=//:aarch64-apple-darwin
```

or

```
bazel build @stdlbs//:std --platforms=//:wasm32-wasi
```
