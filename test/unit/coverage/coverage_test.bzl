"""The collector runs with the test, which can have its own execution platform."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

_CollectorInfo = provider(
    "The configured collector and expected execution platform output root.",
    fields = {"expected_root": "Output root for the test platform", "path": "Collector execution path"},
)

def _platform_marker_impl(ctx):
    marker = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(marker, "")
    return [DefaultInfo(files = depset([marker]))]

platform_marker = rule(implementation = _platform_marker_impl)

def _collector_probe_impl(ctx):
    # Forward only analysis information. Coverage must not build the fixture's
    # outputs on its synthetic execution platforms.
    return [
        _CollectorInfo(
            path = ctx.attr.dep[RunEnvironmentInfo].environment["CC_CODE_COVERAGE_SCRIPT"],
            expected_root = ctx.file.marker.root.path,
        ),
        DefaultInfo(files = depset()),
    ]

collector_probe = rule(
    implementation = _collector_probe_impl,
    attrs = {
        "dep": attr.label(providers = [RunEnvironmentInfo]),
        "marker": attr.label(allow_single_file = True, cfg = "exec"),
    },
)

def _collector_platform_test_impl(ctx):
    env = analysistest.begin(ctx)
    collector = analysistest.target_under_test(env)[_CollectorInfo]
    asserts.true(env, collector.path.startswith(collector.expected_root + "/"), "Coverage collector must use the test execution platform: " + collector.path + " (expected " + collector.expected_root + ")")
    return analysistest.end(env)

collector_platform_test = analysistest.make(
    _collector_platform_test_impl,
    config_settings = {
        "//command_line_option:collect_code_coverage": True,
        "//command_line_option:extra_execution_platforms": [
            str(Label(":compiler_platform")),
            str(Label(":test_platform")),
        ],
        "//command_line_option:platforms": str(Label(":test_platform")),
        "//command_line_option:use_target_platform_for_tests": False,
        # Inspect the collector without requesting the synthetic fixture's
        # executable and tools as coverage report metadata.
        str(Label("//rust/settings:experimental_use_coverage_metadata_files")): False,
    } | ({
        str(Label("@bazel_tools//tools/test:incompatible_use_default_test_toolchain")): True,
    } if bazel_features.toolchains.has_default_test_toolchain_type else {}),
)
