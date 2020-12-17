# Patches to be added to the bazel configuration of external crate repositories
# by cargo raze, if using genmode=Remote, and by our local scripts otherwise.

package(default_visibility = ["//visibility:private"])

filegroup(
    name = "patches",
    srcs = [
        "prost-build-0.6.1.patch",
    ],
    visibility = ["//proto/prostgen/raze:__subpackages__"],
)

filegroup(
    name = "docs",
    srcs = [
        "prost-build-0.6.1.md",
    ],
)
