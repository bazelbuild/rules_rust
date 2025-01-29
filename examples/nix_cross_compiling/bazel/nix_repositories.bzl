""" Nix Repositories """

load("@rules_nixpkgs_core//:nixpkgs.bzl", "nixpkgs_flake_package")

_CONFIG_BUILD_FILE_CONTENT = """
package(default_visibility = ["//visibility:public"])

exports_files(["config.bzl"])
"""

_RUST_BUILD_FILE_CONTENT = """
load("@rules_rust//rust:toolchain.bzl", "rust_stdlib_filegroup")

package(default_visibility = ["//visibility:public"])

# https://github.com/tweag/rules_nixpkgs/blob/master/toolchains/rust/rust.bzl#L33-L116
filegroup(
    name = "rustc",
    srcs = ["bin/rustc"],
)

filegroup(
    name = "rustdoc",
    srcs = ["bin/rustdoc"],
)

filegroup(
    name = "rustfmt",
    srcs = ["bin/rustfmt"],
)

filegroup(
    name = "cargo",
    srcs = ["bin/cargo"],
)

filegroup(
    name = "clippy_driver",
    srcs = ["bin/clippy-driver"],
)

filegroup(
    name = "proc_macro_srv",
    srcs = ["libexec/rust-analyzer-proc-macro-srv"],
)

filegroup(
    name = "rustc_lib",
    srcs = glob(
        [
            "bin/*.so",
            "lib/*.so",
            "lib/rustlib/x86_64-unknown-linux-gnu/codegen-backends/*.so",
            "lib/rustlib/x86_64-unknown-linux-gnu/codegen-backends/*.dylib",
            "lib/rustlib/x86_64-unknown-linux-gnu/bin/*",
            "lib/rustlib/x86_64-unknown-linux-gnu/lib/*.so",
            "lib/rustlib/x86_64-unknown-linux-gnu/lib/*.dylib",
        ],
        allow_empty = True,
    ),
)

filegroup(
    name = "rust-src",
    srcs = glob(["lib/rustlib/src/**/*"]),
)

rust_stdlib_filegroup(
    name = "rust_std-aarch64-apple-darwin",
    srcs = glob(
        [
            "lib/rustlib/aarch64-apple-darwin/lib/*.rlib",
            "lib/rustlib/aarch64-apple-darwin/lib/*.so",
            "lib/rustlib/aarch64-apple-darwin/lib/*.dylib",
            "lib/rustlib/aarch64-apple-darwin/lib/*.a",
            "lib/rustlib/aarch64-apple-darwin/lib/self-contained/**",
        ],
        # Some patterns (e.g. `lib/*.a`) don't match anything, see https://github.com/bazelbuild/rules_rust/pull/245
        allow_empty = True,
    ),
)

rust_stdlib_filegroup(
    name = "rust_std-aarch64-apple-ios",
    srcs = glob(
        [
            "lib/rustlib/aarch64-apple-ios/lib/*.rlib",
            "lib/rustlib/aarch64-apple-ios/lib/*.so",
            "lib/rustlib/aarch64-apple-ios/lib/*.dylib",
            "lib/rustlib/aarch64-apple-ios/lib/*.a",
            "lib/rustlib/aarch64-apple-ios/lib/self-contained/**",
        ],
        # Some patterns (e.g. `lib/*.a`) don't match anything, see https://github.com/bazelbuild/rules_rust/pull/245
        allow_empty = True,
    ),
)

rust_stdlib_filegroup(
    name = "rust_std-aarch64-linux-android",
    srcs = glob(
        [
            "lib/rustlib/aarch64-linux-android/lib/*.rlib",
            "lib/rustlib/aarch64-linux-android/lib/*.so",
            "lib/rustlib/aarch64-linux-android/lib/*.dylib",
            "lib/rustlib/aarch64-linux-android/lib/*.a",
            "lib/rustlib/aarch64-linux-android/lib/self-contained/**",
        ],
        # Some patterns (e.g. `lib/*.a`) don't match anything, see https://github.com/bazelbuild/rules_rust/pull/245
        allow_empty = True,
    ),
)

rust_stdlib_filegroup(
    name = "rust_std-aarch64-unknown-linux-gnu",
    srcs = glob(
        [
            "lib/rustlib/aarch64-unknown-linux-gnu/lib/*.rlib",
            "lib/rustlib/aarch64-unknown-linux-gnu/lib/*.so",
            "lib/rustlib/aarch64-unknown-linux-gnu/lib/*.dylib",
            "lib/rustlib/aarch64-unknown-linux-gnu/lib/*.a",
            "lib/rustlib/aarch64-unknown-linux-gnu/lib/self-contained/**",
        ],
        # Some patterns (e.g. `lib/*.a`) don't match anything, see https://github.com/bazelbuild/rules_rust/pull/245
        allow_empty = True,
    ),
)

rust_stdlib_filegroup(
    name = "rust_std-wasm32-unknown-unknown",
    srcs = glob(
        [
            "lib/rustlib/wasm32-unknown-unknown/lib/*.rlib",
            "lib/rustlib/wasm32-unknown-unknown/lib/*.so",
            "lib/rustlib/wasm32-unknown-unknown/lib/*.dylib",
            "lib/rustlib/wasm32-unknown-unknown/lib/*.a",
            "lib/rustlib/wasm32-unknown-unknown/lib/self-contained/**",
        ],
        # Some patterns (e.g. `lib/*.a`) don't match anything, see https://github.com/bazelbuild/rules_rust/pull/245
        allow_empty = True,
    ),
)

rust_stdlib_filegroup(
    name = "rust_std-wasm32-wasip1",
    srcs = glob(
        [
            "lib/rustlib/wasm32-wasip1/lib/*.rlib",
            "lib/rustlib/wasm32-wasip1/lib/*.so",
            "lib/rustlib/wasm32-wasip1/lib/*.dylib",
            "lib/rustlib/wasm32-wasip1/lib/*.a",
            "lib/rustlib/wasm32-wasip1/lib/self-contained/**",
        ],
        # Some patterns (e.g. `lib/*.a`) don't match anything, see https://github.com/bazelbuild/rules_rust/pull/245
        allow_empty = True,
    ),
)

rust_stdlib_filegroup(
    name = "rust_std-x86_64-apple-darwin",
    srcs = glob(
        [
            "lib/rustlib/x86_64-apple-darwin/lib/*.rlib",
            "lib/rustlib/x86_64-apple-darwin/lib/*.so",
            "lib/rustlib/x86_64-apple-darwin/lib/*.dylib",
            "lib/rustlib/x86_64-apple-darwin/lib/*.a",
            "lib/rustlib/x86_64-apple-darwin/lib/self-contained/**",
        ],
        # Some patterns (e.g. `lib/*.a`) don't match anything, see https://github.com/bazelbuild/rules_rust/pull/245
        allow_empty = True,
    ),
)

rust_stdlib_filegroup(
    name = "rust_std-x86_64-pc-windows-msvc",
    srcs = glob(
        [
            "lib/rustlib/x86_64-pc-windows-msvc/lib/*.rlib",
            "lib/rustlib/x86_64-pc-windows-msvc/lib/*.so",
            "lib/rustlib/x86_64-pc-windows-msvc/lib/*.dylib",
            "lib/rustlib/x86_64-pc-windows-msvc/lib/*.a",
            "lib/rustlib/x86_64-pc-windows-msvc/lib/self-contained/**",
        ],
        # Some patterns (e.g. `lib/*.a`) don't match anything, see https://github.com/bazelbuild/rules_rust/pull/245
        allow_empty = True,
    ),
)

rust_stdlib_filegroup(
    name = "rust_std-x86_64-unknown-linux-gnu",
    srcs = glob(
        [
            "lib/rustlib/x86_64-unknown-linux-gnu/lib/*.rlib",
            "lib/rustlib/x86_64-unknown-linux-gnu/lib/*.so",
            "lib/rustlib/x86_64-unknown-linux-gnu/lib/*.dylib",
            "lib/rustlib/x86_64-unknown-linux-gnu/lib/*.a",
            "lib/rustlib/x86_64-unknown-linux-gnu/lib/self-contained/**",
        ],
        # Some patterns (e.g. `lib/*.a`) don't match anything, see https://github.com/bazelbuild/rules_rust/pull/245
        allow_empty = True,
    ),
)
"""

def nix_repositories():
    nixpkgs_flake_package(
        name = "nix_config",
        nix_flake_file = "//nix:flake.nix",
        nix_flake_lock_file = "//nix:flake.lock",
        package = "bazel.config",
        build_file_content = _CONFIG_BUILD_FILE_CONTENT,
    )

    nixpkgs_flake_package(
        name = "nix_rust",
        nix_flake_file = "//nix:flake.nix",
        nix_flake_lock_file = "//nix:flake.lock",
        package = "bazel.rust",
        build_file_content = _RUST_BUILD_FILE_CONTENT,
    )

def _internal_ext_impl(module_ctx):
    nix_repositories()

    deps = [
        struct(repo = "nix_config"),
        struct(repo = "nix_rust"),
    ]

    # is_dev_dep is ignored here. It's not relevant for internal_deps, as dev
    # dependencies are only relevant for module extensions that can be used
    # by other MODULES.
    return module_ctx.extension_metadata(
        root_module_direct_deps = [repo.repo for repo in deps],
        root_module_direct_dev_deps = [],
    )

internal_ext = module_extension(
    doc = "Development dependencies for the rules_rust nix example.",
    implementation = _internal_ext_impl,
)
