# rules_rust_pyo3

Bazel rules for [PyO3](https://pyo3.rs/v0.29.0/).

## Documentation

More information can be found in the [rules_rust documentation](https://bazelbuild.github.io/rules_rust/rust_pyo3.html).

## Embedding CPython on Linux

A Rust executable can embed a standard shared CPython from the selected
`rules_python` toolchain. Configure a non-`abi3` PyO3 dependency with the
target Python version, then link `libpython` on the executable.

For PyO3 0.29.3, add the following annotation to the crate universe hub that
contains PyO3. The annotation keeps the same crate graph usable by both the
executable and extension modules, which resolve Python symbols from the
interpreter that imports them.

```starlark
# MODULE.bazel
register_toolchains("@rules_rust_pyo3//toolchains:toolchain")

crate.annotation(
    crate = "pyo3-ffi",
    version = "0.29.3",
    repositories = ["my_crates"],
    build_script_env = {
        "PYO3_BUILD_EXTENSION_MODULE": "1",
        "PYO3_CROSS_PYTHON_VERSION": "$(PYO3_CROSS_PYTHON_VERSION)",
        "PYO3_NO_PYTHON": "1",
    },
    build_script_toolchains = ["@rules_rust_pyo3//:current_pyo3_toolchain"],
)
```

Use the annotated PyO3 crate from both `rust_shared_library` and the embedding
executable. Add the C library dependency to the embedding executable's
`link_deps`.

```starlark
rust_binary(
    name = "embed_python",
    srcs = ["main.rs"],
    edition = "2021",
    deps = ["@my_crates//pyo3"],
    link_deps = ["@rules_python//python/cc:current_py_cc_libs"],
)
```

To make the toolchain's standard library available at runtime, include
`@rules_python//python:current_py_toolchain` in its runfiles and configure
Python's module search path before initializing the interpreter. The
[embedding test](test/embedding/) sets `PYTHONHOME` to the runtime's
installation directory.
