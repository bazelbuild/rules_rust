load("@bazel_skylib//rules:select_file.bzl", "select_file")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "all_srcs",
    srcs = glob(["**"]),
)

select_file(
    name = "perl",
    srcs = ":all_srcs",
    subpath = "perl/bin/perl.exe",
)
