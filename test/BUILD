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
    name ="hello_lib_rule_test",
    generates = ["libhello_lib.rlib"],
    provides = {
        "rust_lib": "/libhello_lib.rlib>\\?$",
        "transitive_libs": "^\\[\\]$"
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
    generates = ["libhello_lib.rlib"],
    rule = "@examples//hello_lib:hello_lib",
)

