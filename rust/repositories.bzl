load(":known_shas.bzl", "FILE_KEY_TO_SHA")
load(":triple_mappings.bzl", "triple_to_system", "triple_to_constraint_set", "system_to_binary_ext", "system_to_dylib_ext", "system_to_staticlib_ext")

def _generic_build_file(target_triple):
    system = triple_to_system(target_triple)
    return """filegroup(
    name = "rustc",
    srcs = ["rustc/bin/rustc{binary_ext}"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "rustc_lib",
    srcs = glob(["rustc/lib/*.{dylib_ext}"]),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "rustdoc",
    srcs = ["rustc/bin/rustdoc{binary_ext}"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "rust_lib",
    srcs = glob([
        "rust-std-{target_triple}/lib/rustlib/{target_triple}/lib/*.rlib",
        "rust-std-{target_triple}/lib/rustlib/{target_triple}/lib/*.{dylib_ext}",
        "rust-std-{target_triple}/lib/rustlib/{target_triple}/lib/*.{staticlib_ext}",
        "rustc/lib/rustlib/{target_triple}/lib/*.rlib",
        "rustc/lib/rustlib/{target_triple}/lib/*.{dylib_ext}",
        "rustc/lib/rustlib/{target_triple}/lib/*.{staticlib_ext}",
    ]),
    visibility = ["//visibility:public"],
)
""".format(
        binary_ext = system_to_binary_ext(system),
        staticlib_ext = system_to_staticlib_ext(system),
        dylib_ext = system_to_dylib_ext(system),
        target_triple = target_triple,
    )

def _BUILD_for_toolchain(name, target_triple):
    system = triple_to_system(target_triple)
    constraint_set = triple_to_constraint_set(target_triple)

    constraint_set_strs = []
    for constraint in constraint_set_strs:
        constraint_set_strs.append("\"{}\"", constraint)

    constraint_sets_serialized = "[{}]".format(", ".join(constraint_set_strs))

    return """toolchain(
    name = "{toolchain_name}",
    exec_compatible_with = {constraint_sets_serialized},
    target_compatible_with = {constraint_sets_serialized},
    toolchain = ":{toolchain_name}_impl",
    toolchain_type = "@io_bazel_rules_rust//rust:toolchain",
)

rust_toolchain(
    name = "{toolchain_name}_impl",
    rust_doc = "@{toolchain_workspace_name}//:rustdoc",
    rust_lib = ["@{toolchain_workspace_name}//:rust_lib"],
    rustc = "@{toolchain_workspace_name}//:rustc",
    rustc_lib = ["@{toolchain_workspace_name}//:rustc_lib"],
    staticlib_ext = "{staticlib_ext}",
    dylib_ext = "{dylib_ext}",
    os = "{system}",
    visibility = ["//visibility:public"],
)
""".format(
        toolchain_name = name,
        toolchain_workspace_name = name.replace("-", "_"),
        staticlib_ext = system_to_staticlib_ext(system),
        dylib_ext = system_to_dylib_ext(system),
        system = system,
        constraint_sets_serialized = constraint_sets_serialized,
    )

def _default_toolchains():
    all_toolchains = [
        ("rust-linux-x86_64", "x86_64-unknown-linux-gnu"),
        ("rust-darwin-x86_64", "x86_64-apple-darwin"),
        ("rust-freebsd-x86_64", "x86_64-unknown-freebsd"),
    ]

    all_toolchain_BUILDs = []
    for toolchain in all_toolchains:
        all_toolchain_BUILDs.append(_BUILD_for_toolchain(toolchain[0], toolchain[1]))

    return """
load("@io_bazel_rules_rust//rust:toolchain.bzl", "rust_toolchain")

{all_toolchain_BUILDs}
""".format(all_toolchain_BUILDs = "\n".join(all_toolchain_BUILDs))

# Eventually with better toolchain hosting options we could load only one of these, not both.
def rust_repositories():
    native.new_http_archive(
        name = "rust_linux_x86_64",
        url = "https://static.rust-lang.org/dist/rust-1.26.1-x86_64-unknown-linux-gnu.tar.gz",
        strip_prefix = "rust-1.26.1-x86_64-unknown-linux-gnu",
        sha256 = FILE_KEY_TO_SHA.get("rust-1.26.1-x86_64-unknown-linux-gnu") or "",
        build_file_content = _generic_build_file("x86_64-unknown-linux-gnu"),
    )

    native.new_http_archive(
        name = "rust_darwin_x86_64",
        url = "https://static.rust-lang.org/dist/rust-1.26.1-x86_64-apple-darwin.tar.gz",
        strip_prefix = "rust-1.26.1-x86_64-apple-darwin",
        sha256 = FILE_KEY_TO_SHA.get("rust-1.26.1-x86_64-apple-darwin") or "",
        build_file_content = _generic_build_file("x86_64-apple-darwin"),
    )

    native.new_http_archive(
        name = "rust_freebsd_x86_64",
        url = "https://static.rust-lang.org/dist/rust-1.26.1-x86_64-unknown-freebsd.tar.gz",
        strip_prefix = "rust-1.26.1-x86_64-unknown-freebsd",
        sha256 = FILE_KEY_TO_SHA.get("rust-1.26.1-x86_64-unknown-freebsd") or "",
        build_file_content = _generic_build_file("x86_64-unknown-freebsd"),
    )

    native.new_local_repository(
        name = "rust_default_toolchains",
        path = ".",
        build_file_content = _default_toolchains(),
    )

    # Register toolchains
    native.register_toolchains(
        "@rust_default_toolchains//:rust-linux-x86_64",
        "@rust_default_toolchains//:rust-darwin-x86_64",
        "@rust_default_toolchains//:rust-freebsd-x86_64",
    )
