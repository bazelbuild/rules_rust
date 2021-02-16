"""
The dependencies for running the gen_rust_project binary.
"""

load("//tools/rust_analyzer/raze:crates.bzl", "rules_rust_tools_rust_analyzer_fetch_remote_crates")

def gen_rust_project_dependencies():
    rules_rust_tools_rust_analyzer_fetch_remote_crates()