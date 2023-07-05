"""Dependencies for Rust Prost rules"""

load("//proto/prost/private/3rdparty/crates:crates.bzl", "crate_repositories")

def rust_prost_dependencies():
    """Prost repository dependencies."""
    crate_repositories()
