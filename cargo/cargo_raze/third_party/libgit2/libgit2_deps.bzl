"""A module defining the dependencies of the third party target libgit2"""

load("@rules_foreign_cc//:workspace_definitions.bzl", "rules_foreign_cc_dependencies")

def libgit2_deps():
    rules_foreign_cc_dependencies()
