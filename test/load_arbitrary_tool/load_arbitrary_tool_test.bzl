# buildifier: disable=module-docstring
load("//rust:repositories.bzl", "load_arbitrary_tool")

def _load_arbitrary_tool_test_impl(repository_ctx):
    if "mac" in repository_ctx.os.name:
        target_triple = "x86_64-apple-darwin"
    elif "windows" in repository_ctx.os.name:
        target_triple = "x86_64-pc-windows-msvc"
    else:
        target_triple = "x86_64-unknown-linux-gnu"

    # Download cargo
    load_arbitrary_tool(
        ctx = repository_ctx,
        tool_name = "cargo",
        tool_subdirectories = ["cargo"],
        version = "1.52.1",
        iso_date = None,
        target_triple = target_triple,
    )

    repo_path = repository_ctx.path(".")
    repository_ctx.file(
        "{}/BUILD.bazel".format(repo_path),
        content = "exports_files([\"bin/cargo\"])",
    )

_load_arbitrary_tool_test = repository_rule(
    implementation = _load_arbitrary_tool_test_impl,
    doc = (
        "A test repository rule ensuring `load_arbitrary_tool` functions " +
        "without requiring any attributes on a repository rule"
    ),
)

def load_arbitrary_tool_test():
    """Define the a test repository for ensuring `load_arbitrary_tool` has no attribute requirements"""
    _load_arbitrary_tool_test(
        name = "rules_rust_test_load_arbitrary_tool",
    )
