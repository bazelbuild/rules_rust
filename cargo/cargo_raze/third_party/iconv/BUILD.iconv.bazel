"""libiconv is only expected to be used on MacOS systems"""

load("@rules_foreign_cc//tools/build_defs:configure.bzl", "configure_make")

filegroup(
    name = "all",
    srcs = glob(["**"]),
)

configure_make(
    name = "iconv",
    configure_env_vars = select({
        "@platforms//os:macos": {"AR": ""},
        "//conditions:default": {},
    }),
    configure_in_place = True,
    configure_options = [
        "--enable-relocatable",
        "--enable-shared=no",
        "--enable-static=yes",
    ],
    lib_source = "@iconv//:all",
    make_commands = ["make install-lib"],
    static_libraries = [
        "libiconv.a",
    ],
    visibility = ["//visibility:public"],
)
