"""# PyO3 extension

Load PyO3 rules from `@rules_rust//extensions/pyo3:defs.bzl`. The legacy
`@rules_rust_pyo3` repository is only needed as a compatibility layer for older
load and toolchain labels.
"""

load(
    "//extensions/pyo3/private:pyo3.bzl",
    _pyo3_extension = "pyo3_extension",
)
load(
    "//extensions/pyo3/private:pyo3_toolchain.bzl",
    _pyo3_toolchain = "pyo3_toolchain",
    _rust_pyo3_toolchain = "rust_pyo3_toolchain",
)

pyo3_extension = _pyo3_extension
pyo3_toolchain = _pyo3_toolchain
rust_pyo3_toolchain = _rust_pyo3_toolchain
