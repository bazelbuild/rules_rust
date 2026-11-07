"""Tests of the collector that collects the coverage of a `rust_test`."""

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

_FAKE_COLLECTOR_DATA = "test/unit/coverage/fake_collector_data.txt"

def _short_paths(files):
    return [file.short_path for file in files.to_list()]

def _coverage_collector_flag_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    collector = target[RunEnvironmentInfo].environment["CC_CODE_COVERAGE_SCRIPT"]
    asserts.true(
        env,
        collector.endswith("/test/unit/coverage/fake_collector") or collector.endswith("/test/unit/coverage/fake_collector.exe"),
        "Coverage collector must be the one that the flag selects: " + collector,
    )
    return analysistest.end(env)

coverage_collector_flag_test = analysistest.make(
    _coverage_collector_flag_test_impl,
    config_settings = {
        "//command_line_option:collect_code_coverage": True,
        str(Label("//rust/settings:coverage_collector")): str(Label(":fake_collector")),
    },
)

def _coverage_collector_metadata_files_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.true(
        env,
        _FAKE_COLLECTOR_DATA in _short_paths(target[InstrumentedFilesInfo].metadata_files),
        "The coverage collector's runfiles must be coverage metadata files of the test",
    )
    asserts.false(
        env,
        _FAKE_COLLECTOR_DATA in _short_paths(target[DefaultInfo].default_runfiles.files),
        "The coverage collector's runfiles must not be runfiles of the test",
    )
    return analysistest.end(env)

coverage_collector_metadata_files_test = analysistest.make(
    _coverage_collector_metadata_files_test_impl,
    config_settings = {
        "//command_line_option:collect_code_coverage": True,
        str(Label("//rust/settings:coverage_collector")): str(Label(":fake_collector")),
        str(Label("//rust/settings:experimental_use_coverage_metadata_files")): True,
    },
)

def _coverage_collector_runfiles_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.true(
        env,
        _FAKE_COLLECTOR_DATA in _short_paths(target[DefaultInfo].default_runfiles.files),
        "The coverage collector's runfiles must be runfiles of the test",
    )
    return analysistest.end(env)

coverage_collector_runfiles_test = analysistest.make(
    _coverage_collector_runfiles_test_impl,
    config_settings = {
        "//command_line_option:collect_code_coverage": True,
        str(Label("//rust/settings:coverage_collector")): str(Label(":fake_collector")),
        str(Label("//rust/settings:experimental_use_coverage_metadata_files")): False,
    },
)
