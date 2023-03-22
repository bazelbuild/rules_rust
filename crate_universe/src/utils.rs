//! Common utilities

pub mod starlark;

pub const CRATES_IO_INDEX_URL: &str = "https://github.com/rust-lang/crates.io-index";

/// Convert a string into a valid crate module name by applying transforms to invalid characters
pub fn sanitize_module_name(name: &str) -> String {
    name.replace('-', "_")
}

/// Some character which may be present in version IDs are not valid
/// in Bazel repository names. This converts invalid characters. See
/// [RepositoryName.java](https://github.com/bazelbuild/bazel/blob/4.0.0/src/main/java/com/google/devtools/build/lib/cmdline/RepositoryName.java#L42)
pub fn sanitize_repository_name(name: &str) -> String {
    name.replace('+', "-")
}
