"""Public Cargo features for Bazel."""

# `symlink-exec-root` feature will symlink the execroot to the build script execution directory.
#
# This is useful for building with hermetic C++ toolchains.
SYMLINK_EXEC_ROOT_FEATURE = "symlink-exec-root"
