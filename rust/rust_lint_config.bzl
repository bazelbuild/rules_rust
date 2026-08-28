"""# rust_lint_config.bzl"""

load(
    "//rust/private:lints.bzl",
    _rust_lint_config = "rust_lint_config",
)

rust_lint_config = _rust_lint_config
