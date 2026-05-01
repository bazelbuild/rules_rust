"""A module defining dependencies of the `rules_rust` tests"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//test/determinism/3rdparty/crates:crates.bzl", determinism_test_crate_repositories = "crate_repositories")
load("//test/generated_inputs:external_repo.bzl", "generated_inputs_in_external_repo")
load("//test/rust_analyzer/3rdparty/crates:crates.bzl", rust_analyzer_test_crate_repositories = "crate_repositories")
load("//test/unit/toolchain:toolchain_test_utils.bzl", "rules_rust_toolchain_test_target_json_repository")
load("//test/vscode/3rdparty/crates:crates.bzl", vscode_test_crate_repositories = "crate_repositories")

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

    direct_deps = []
    direct_deps.extend(generated_inputs_in_external_repo())
    direct_deps.extend(rust_analyzer_test_crate_repositories())
    direct_deps.extend(vscode_test_crate_repositories())
    direct_deps.extend(determinism_test_crate_repositories())

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

    direct_deps.extend([
        struct(repo = "libc", is_dev_dep = True),
        struct(repo = "rules_rust_toolchain_test_target_json", is_dev_dep = True),
    ])

    return direct_deps
