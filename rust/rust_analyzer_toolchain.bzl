"""# Rust Analyzer Toolchain"""

load(
    "//rust/private:rust_analyzer.bzl",
    _rust_analyzer_toolchain = "rust_analyzer_toolchain",
)

rust_analyzer_toolchain = _rust_analyzer_toolchain
