"""Analysis test for rust_analyzer_aspect rust_generated_srcs propagation."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_rust//rust:defs.bzl", "rust_analyzer_aspect")

def _rust_generated_src_impl(ctx):
    out = ctx.actions.declare_file(ctx.attr.out)
    ctx.actions.write(output = out, content = ctx.attr.content)
    return [
        DefaultInfo(files = depset([out])),
        OutputGroupInfo(rust_generated_srcs = depset([out])),
    ]

rust_generated_src = rule(
    implementation = _rust_generated_src_impl,
    attrs = {
        "content": attr.string(mandatory = True),
        "out": attr.string(mandatory = True),
    },
    doc = "Test helper that generates a .rs file and provides rust_generated_srcs output group.",
)

def _rust_generated_srcs_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    rust_generated_srcs = target[OutputGroupInfo].rust_generated_srcs.to_list()
    asserts.equals(env, ["generated.rs"], [f.basename for f in rust_generated_srcs])

    return analysistest.end(env)

rust_generated_srcs_test = analysistest.make(
    _rust_generated_srcs_test_impl,
    extra_target_under_test_aspects = [rust_analyzer_aspect],
)

def generated_srcs_analysis_test_suite(name):
    """Test suite for rust_analyzer_aspect rust_generated_srcs propagation.

    Args:
        name: Name of the test suite.
    """
    rust_generated_srcs_test(
        name = "rust_generated_srcs_propagation_test",
        target_under_test = ":generated_srcs",
    )

    native.test_suite(
        name = name,
        tests = [
            ":rust_generated_srcs_propagation_test",
        ],
    )
