"""Defines a test rule providing UnstableRustFeaturesInfo"""

load("@rules_rust//rust:rust_common.bzl", "UnstableRustFeaturesInfo")

def _unstable_rust_features_for_test_impl_fn(label):
    if str(label).endswith(":unstable_features_test"):
        return ["core_intrinsics"]
    return []

def _unstable_rust_features_for_test_impl(_ctx):
    return UnstableRustFeaturesInfo(
        unstable_rust_features_config = _unstable_rust_features_for_test_impl_fn,
    )

unstable_rust_features_for_test_rule = rule(
    attrs = {},
    provides = [UnstableRustFeaturesInfo],
    implementation = _unstable_rust_features_for_test_impl,
)
