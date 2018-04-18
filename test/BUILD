load(
    "//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)
load(
    # TODO(katre): Remove the fork of test_rules when the fixed version is released.
    #"@bazel_tools//tools/build_rules:test_rules.bzl",
    ":test_rules.bzl",
    "rule_test",
)

rule_test(
    name = "hello_lib_rule_test",
    generates = ["libhello_lib--1343350674.rlib"],
    provides = {
        "rust_lib": "/libhello_lib--1343350674.rlib>\\?$",
        "transitive_rlibs": "^\\[\\]$",
        "transitive_dylibs": "^\\[\\]$",
        "transitive_staticlibs": "^\\[\\]$",
    },
    rule = "@examples//hello_lib:hello_lib",
)

rule_test(
    name = "hello_world_rule_test",
    generates = ["hello_world"],
    rule = "@examples//hello_world:hello_world",
)

rule_test(
    name = "greeting_rule_test",
    generates = ["libhello_lib--1343350674.rlib"],
    rule = "@examples//hello_lib:hello_lib",
)
