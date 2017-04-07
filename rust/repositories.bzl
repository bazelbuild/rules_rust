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

# Eventually with better toolchain hosting options we could load only one of these, not both.
def rust_repositories():
  native.new_http_archive(
      name = "rust_linux_x86_64",
      url = "http://bazel-mirror.storage.googleapis.com/static.rust-lang.org/dist/rust-1.15.1-x86_64-unknown-linux-gnu.tar.gz",
      strip_prefix = "rust-1.15.1-x86_64-unknown-linux-gnu",
      sha256 = "b1e7c818a3cc8b010932f0efc1cf0ede7471958310f808d543b6e32d2ec748e7",
      build_file_content = RUST_LINUX_BUILD_FILE,
  )

  native.new_http_archive(
      name = "rust_darwin_x86_64",
      url = "http://bazel-mirror.storage.googleapis.com/static.rust-lang.org/dist/rust-1.15.1-x86_64-apple-darwin.tar.gz",
      strip_prefix = "rust-1.15.1-x86_64-apple-darwin",
      sha256 = "38606e464b31a778ffa7d25d490a9ac53b472102bad8445b52e125f63726ac64",
      build_file_content = RUST_DARWIN_BUILD_FILE,
  )
