"""Unittests to check that we don't create stdlib link args duplicates."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_library")

def _stdlib_link_args_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    argv = tut.actions[0].argv

    link_args = None
    for arg in argv:
        if arg.startswith("link-args="):
            link_args = arg
            break
    asserts.true(env, link_args != None)

    # Make sure that each stdlib linkflag is only present once
    linkflags = []
    for flag in link_args.split(" "):
        # Ideally we would only do this check for args that are in `stdlib_linkflags`
        # but that would require access to the rust toolchain.
        asserts.false(env, flag in linkflags)
        linkflags.append(flag)

    return analysistest.end(env)

stdlib_link_args_test = analysistest.make(_stdlib_link_args_test_impl)

def _stdlib_link_args_test():
    rust_library(
        name = "a",
        srcs = ["a.rs"],
        deps = [":ba", ":bb"],
    )
    rust_library(
        name = "ba",
        srcs = ["ba.rs"],
        deps = [":ca"],
    )
    rust_library(
        name = "bb",
        srcs = ["bb.rs"],
        deps = [":cb"],
    )
    rust_library(
        name = "ca",
        srcs = ["ca.rs"],
    )
    rust_library(
        name = "cb",
        srcs = ["cb.rs"],
    )

    stdlib_link_args_test(
        name = "stdlib_link_args_test",
        target_under_test = ":a",
    )

def stdlib_link_args_test_suite(name):
    _stdlib_link_args_test()

    native.test_suite(
        name = name,
        tests = [
            ":stdlib_link_args_test",
        ],
    )
