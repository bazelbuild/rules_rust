load("@rules_foreign_cc//tools/build_defs:configure.bzl", "configure_make")

config_setting(
    name = "darwin",
    values = {"cpu": "darwin"},
    visibility = ["//visibility:public"],
)

config_setting(
    name = "linux",
    values = {"cpu": "k8"},
    visibility = ["//visibility:public"],
)

filegroup(
    name = "srcs",
    srcs = glob(
        ["**"],
        exclude = ["BUILD.bazel"],
    ),
)

configure_make(
    name = "openssl",
    configure_command = "config",
    configure_env_vars = select({
        # On Darwin, the cc_toolchain uses libtool instead of ar, but these do not take compatible arguments.
        # By default it will set AR to point at libtool.
        # So set AR to an empty value so that Darwin falls back to the system-default ar instead.
        ":darwin": {
            "AR": "",
        },
        ":linux": {},
    }),
    lib_source = ":srcs",
    shared_libraries = select({
        ":darwin": [
            "libcrypto.dylib",
            "libssl.dylib",
        ],
        ":linux": [
            "libcrypto.so",
            "libssl.so",
        ],
    }),
    static_libraries = [
        "libcrypto.a",
        "libssl.a",
    ],
    visibility = ["//visibility:public"],
)
