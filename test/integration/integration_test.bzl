load("//:bazel_versions.bzl", "CURRENT_BAZEL_VERSION")
load(
    "@contrib_rules_bazel_integration_test//bazel_integration_test:defs.bzl",
    "bazel_integration_test",
    "bazel_integration_tests",
    "default_test_runner",
    "integration_test_utils",
)
load(
    "@rules_rust//rust:defs.bzl",
    "rust_test",
)

def rules_rust_bazel_integration_test(name, srcs, deps = []):
    rust_test(
        name = name + "_test",
        srcs = srcs,
        deps = deps + ["//test/integration"],
        edition = "2018",
    )
    bazel_integration_test(
        name = name,
        bazel_version = CURRENT_BAZEL_VERSION,
        test_runner = name + "_test",
        workspace_files = integration_test_utils.glob_workspace_files("workspace") + [
            "//:all_files",
        ],
        workspace_path = "workspace",
    )
