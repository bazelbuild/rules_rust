"""A module defining the dependencies of the third party target OpenSSL"""

load("@rules_foreign_cc//:workspace_definitions.bzl", "rules_foreign_cc_dependencies")

def pcre_deps():
    rules_foreign_cc_dependencies()
