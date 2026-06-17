"""Defines a test rule providing UnstableSelfProfileInfo"""

load("@rules_rust//rust:rust_common.bzl", "UnstableSelfProfileInfo")

def _get_self_profiling_flag_impl(_ctx):
    return UnstableSelfProfileInfo(
        events = [("//:sample_binary", "all")],
    )

unstable_self_profiling_flags = rule(
    attrs = {},
    provides = [UnstableSelfProfileInfo],
    implementation = _get_self_profiling_flag_impl,
)
