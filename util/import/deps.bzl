"""
The dependencies for running the gen_rust_project binary.
"""

load("//util/import/raze:crates.bzl", "rules_rust_util_import_fetch_remote_crates")

def import_deps():
    rules_rust_util_import_fetch_remote_crates()

# For legacy support
gen_rust_project_dependencies = import_deps
