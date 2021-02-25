load(
    "@bazel_tools//tools/build_rules:test_rules.bzl",
    "rule_test",
)

rule_test(
    name = "hello_lib_rule_test",
    generates = ["libhello_lib--1343350674.rlib"],
    rule = "@examples//hello_lib:hello_lib",
)

config_setting(
    name = "is_windows",
    constraint_values = ["@platforms//os:windows"],
)

rule_test(
    name = "hello_world_rule_test",
    generates = select({
        ":is_windows": ["hello_world.exe"],
        "//conditions:default": ["hello_world"],
    }),
    rule = "@examples//hello_world:hello_world",
)

rule_test(
    name = "greeting_rule_test",
    generates = ["libhello_lib--1343350674.rlib"],
    rule = "@examples//hello_lib:hello_lib",
)
