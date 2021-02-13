"""A module defining the transitive dependencies of third party deps for cargo-raze"""

load("@rules_foreign_cc//:workspace_definitions.bzl", "rules_foreign_cc_dependencies")

def third_party_transitive_deps():
    """Loads all dependnecies from repositories defiend in third_party_repositories"""
    rules_foreign_cc_dependencies()
