RUST_DARWIN_BUILD_FILE = """
filegroup(
    name = "rustc",
    srcs = ["rustc/bin/rustc"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "rustc_lib",
    srcs = glob(["rustc/lib/*.dylib"]),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "rustdoc",
    srcs = ["rustc/bin/rustdoc"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "rust_lib",
    srcs = glob([
        "rust-std-x86_64-apple-darwin/lib/rustlib/x86_64-apple-darwin/lib/*.rlib",
        "rust-std-x86_64-apple-darwin/lib/rustlib/x86_64-apple-darwin/lib/*.dylib",
        "rust-std-x86_64-apple-darwin/lib/rustlib/x86_64-apple-darwin/lib/*.a",
        "rustc/lib/rustlib/x86_64-apple-darwin/lib/*.rlib",
        "rustc/lib/rustlib/x86_64-apple-darwin/lib/*.dylib",
        "rustc/lib/rustlib/x86_64-apple-darwin/lib/*.a",
    ]),
    visibility = ["//visibility:public"],
)
"""

RUST_LINUX_BUILD_FILE = """
filegroup(
    name = "rustc",
    srcs = ["rustc/bin/rustc"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "rustc_lib",
    srcs = glob(["rustc/lib/*.so"]),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "rustdoc",
    srcs = ["rustc/bin/rustdoc"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "rust_lib",
    srcs = glob([
        "rust-std-x86_64-unknown-linux-gnu/lib/rustlib/x86_64-unknown-linux-gnu/lib/*.rlib",
        "rust-std-x86_64-unknown-linux-gnu/lib/rustlib/x86_64-unknown-linux-gnu/lib/*.so",
        "rust-std-x86_64-unknown-linux-gnu/lib/rustlib/x86_64-unknown-linux-gnu/lib/*.a",
        "rustc/lib/rustlib/x86_64-unknown-linux-gnu/lib/*.rlib",
        "rustc/lib/rustlib/x86_64-unknown-linux-gnu/lib/*.so",
        "rustc/lib/rustlib/x86_64-unknown-linux-gnu/lib/*.a",
    ]),
    visibility = ["//visibility:public"],
)
"""

# This defines the default toolchain separately from the actual repositories, so that the remote
# repositories will only be downloaded if they are actually used.
DEFAULT_TOOLCHAINS = """
load("@io_bazel_rules_rust//rust:toolchain.bzl", "rust_toolchain")

toolchain(
    name = "rust-linux-x86_64",
    exec_compatible_with = [
        "@bazel_tools//platforms:linux",
        "@bazel_tools//platforms:x86_64",
    ],
    target_compatible_with = [
        "@bazel_tools//platforms:linux",
        "@bazel_tools//platforms:x86_64",
    ],
    toolchain = ":rust-linux-x86_64_impl",
    toolchain_type = "@io_bazel_rules_rust//rust:toolchain",
)

rust_toolchain(
    name = "rust-linux-x86_64_impl",
    rust_doc = "@rust_linux_x86_64//:rustdoc",
    rust_lib = ["@rust_linux_x86_64//:rust_lib"],
    rustc = "@rust_linux_x86_64//:rustc",
    rustc_lib = ["@rust_linux_x86_64//:rustc_lib"],
    staticlib_ext = ".a",
    dylib_ext = ".so",
    os = "linux",
    visibility = ["//visibility:public"],
)

toolchain(
    name = "rust-darwin-x86_64",
    exec_compatible_with = [
        "@bazel_tools//platforms:osx",
        "@bazel_tools//platforms:x86_64",
    ],
    target_compatible_with = [
        "@bazel_tools//platforms:osx",
        "@bazel_tools//platforms:x86_64",
    ],
    toolchain = ":rust-darwin-x86_64_impl",
    toolchain_type = "@io_bazel_rules_rust//rust:toolchain",
)

rust_toolchain(
    name = "rust-darwin-x86_64_impl",
    rust_doc = "@rust_darwin_x86_64//:rustdoc",
    rust_lib = ["@rust_darwin_x86_64//:rust_lib"],
    rustc = "@rust_darwin_x86_64//:rustc",
    rustc_lib = ["@rust_darwin_x86_64//:rustc_lib"],
    staticlib_ext = ".a",
    dylib_ext = ".dylib",
    os = "mac os x",
    visibility = ["//visibility:public"],
)
"""

# Eventually with better toolchain hosting options we could load only one of these, not both.
def rust_repositories():
  native.new_http_archive(
      name = "rust_linux_x86_64",
      url = "https://static.rust-lang.org/dist/rust-1.24.1-x86_64-unknown-linux-gnu.tar.gz",
      strip_prefix = "rust-1.24.1-x86_64-unknown-linux-gnu",
      sha256 = "4567e7f6e5e0be96e9a5a7f5149b5452828ab6a386099caca7931544f45d5327",
      build_file_content = RUST_LINUX_BUILD_FILE,
  )

  native.new_http_archive(
      name = "rust_darwin_x86_64",
      url = "https://static.rust-lang.org/dist/rust-1.24.1-x86_64-apple-darwin.tar.gz",
      strip_prefix = "rust-1.24.1-x86_64-apple-darwin",
      sha256 = "9d4aacdb5849977ea619d399903c9378163bd9c76ea11dac5ef6eca27849f501",
      build_file_content = RUST_DARWIN_BUILD_FILE,
  )

  native.new_local_repository(
      name = "rust_default_toolchains",
      path = ".",
      build_file_content = DEFAULT_TOOLCHAINS)

  # Register toolchains
  native.register_toolchains(
      "@rust_default_toolchains//:rust-linux-x86_64",
      "@rust_default_toolchains//:rust-darwin-x86_64")
