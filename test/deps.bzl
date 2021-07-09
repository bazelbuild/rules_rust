"""A module defining dependencies of the `rules_rust` tests"""

load("//test/load_arbitrary_tool:load_arbitrary_tool_test.bzl", "load_arbitrary_tool_test")

def rules_rust_test_deps():
    """Load dependencies for rules_rust tests"""

    load_arbitrary_tool_test()
