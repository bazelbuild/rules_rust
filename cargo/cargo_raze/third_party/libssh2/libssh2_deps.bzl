"""A module defining the dependencies of the third party target libssh2"""

load("@rules_foreign_cc//:workspace_definitions.bzl", "rules_foreign_cc_dependencies")

def libssh2_deps():
    rules_foreign_cc_dependencies()
