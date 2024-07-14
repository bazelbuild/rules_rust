"""A module defining dependencies of the `rules_rust` tests"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//test/generated_inputs:external_repo.bzl", "generated_inputs_in_external_repo")
load("//test/load_arbitrary_tool:load_arbitrary_tool_test.bzl", "load_arbitrary_tool_test")
load("//test/unit/toolchain:toolchain_test_utils.bzl", "rules_rust_toolchain_test_target_json_repository")

_LIBC_BUILD_FILE_CONTENT = """\
load("@rules_rust//rust:defs.bzl", "rust_library")

rust_library(
    name = "libc",
    srcs = glob(["src/**/*.rs"]),
    edition = "2015",
    rustc_flags = [
        # In most cases, warnings in 3rd party crates are not interesting as
        # they're out of the control of consumers. The flag here silences
        # warnings. For more details see:
        # https://doc.rust-lang.org/rustc/lints/levels.html
        "--cap-lints=allow",
    ],
    visibility = ["//visibility:public"],
)
"""

def rules_rust_test_deps():
    """Load dependencies for rules_rust tests

    Returns:
        list[struct(repo=str, is_dev_dep=bool)]: A list of the repositories
        defined by this macro.
    """

    direct_deps = load_arbitrary_tool_test()
    direct_deps.extend(generated_inputs_in_external_repo())

    maybe(
        http_archive,
        name = "libc",
        build_file_content = _LIBC_BUILD_FILE_CONTENT,
        sha256 = "1ac4c2ac6ed5a8fb9020c166bc63316205f1dc78d4b964ad31f4f21eb73f0c6d",
        strip_prefix = "libc-0.2.20",
        urls = [
            "https://mirror.bazel.build/github.com/rust-lang/libc/archive/0.2.20.zip",
            "https://github.com/rust-lang/libc/archive/0.2.20.zip",
        ],
    )

    maybe(
        rules_rust_toolchain_test_target_json_repository,
        name = "rules_rust_toolchain_test_target_json",
        target_json = Label("//test/unit/toolchain:toolchain-test-triple.json"),
    )

    maybe(
        http_archive,
        name = "com_google_googleapis",
        urls = [
            "https://github.com/googleapis/googleapis/archive/18becb1d1426feb7399db144d7beeb3284f1ccb0.zip",
        ],
        strip_prefix = "googleapis-18becb1d1426feb7399db144d7beeb3284f1ccb0",
        sha256 = "b8c487191eb942361af905e40172644eab490190e717c3d09bf83e87f3994fff",
    )

    maybe(
        http_archive,
        name = "rules_python",
        sha256 = "778aaeab3e6cfd56d681c89f5c10d7ad6bf8d2f1a72de9de55b23081b2d31618",
        strip_prefix = "rules_python-0.34.0",
        url = "https://github.com/bazelbuild/rules_python/releases/download/0.34.0/rules_python-0.34.0.tar.gz",
    )

    direct_deps.extend([
        struct(repo = "libc", is_dev_dep = True),
        struct(repo = "rules_rust_toolchain_test_target_json", is_dev_dep = True),
        struct(repo = "com_google_googleapis", is_dev_dep = True),
        struct(repo = "rules_python", is_dev_dep = True),
    ])

    return direct_deps
