load(
    "//rust:rust.bzl",
    "rust_test",
)

load(
    "//cargo:cargo_build_script.bzl",
    "cargo_build_script",
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

rust_test(
    # Intentionally uses a mix of -s and _s because those normalisations are part of what is being tested.
    name = "cargo_env-vars_test",
    srcs = ["tests/cargo.rs"],
    deps = [":cargo_build_script_env-vars_build_script"],
)

cargo_build_script(
    name = "cargo_build_script_env-vars_build_script",
    srcs = ["src/build.rs"],
)
