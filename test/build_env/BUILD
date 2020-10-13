load(
    "//rust:rust.bzl",
    "rust_test",
)

package(default_visibility = ["//visibility:public"])

rust_test(
    name = "conflicting_deps_test",
    srcs = ["tests/manifest_dir.rs"],
    data = ["src/manifest_dir_file.txt"],
)

rust_test(
    name = "arbitrary_env_test",
    srcs = ["tests/arbitrary_env.rs"],
    rustc_env = {
        "USER_DEFINED_KEY": "USER_DEFINED_VALUE",
    },
)
