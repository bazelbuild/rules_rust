"""A module defining the dependencies of the third party target curl"""

load("@rules_foreign_cc//:workspace_definitions.bzl", "rules_foreign_cc_dependencies")

def curl_deps():
    rules_foreign_cc_dependencies()
