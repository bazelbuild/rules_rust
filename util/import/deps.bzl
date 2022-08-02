"""
The dependencies for running the gen_rust_project binary.
"""

load("//util/import/3rdparty/crates:defs.bzl", "crate_repositories")

def import_deps():
    crate_repositories()

# For legacy support
gen_rust_project_dependencies = import_deps
