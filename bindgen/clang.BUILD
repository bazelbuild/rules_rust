package(default_visibility = ["//visibility:public"])

sh_binary(
    name = "clang",
    srcs = ["bin/clang"],
    data = glob(["lib/**"]),
)

cc_library(
    name = "libclang.so",
    srcs = [
        "lib/libclang.so",
    ],
)
