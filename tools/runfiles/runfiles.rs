//! Runfiles lookup library for Bazel-built Rust binaries and tests.
//!
//! USAGE:
//!
//! 1.  Depend on this runfiles library from your build rule:
//!     ```python
//!       rust_binary(
//!           name = "my_binary",
//!           ...
//!           data = ["//path/to/my/data.txt"],
//!           deps = ["@rules_rust//tools/runfiles"],
//!       )
//!     ```
//!
//! 2.  Import the runfiles library.
//!     ```ignore
//!     extern crate runfiles;
//!
//!     use runfiles::Runfiles;
//!     ```
//!
//! 3.  Create a Runfiles object and use rlocation to look up runfile paths:
//!     ```ignore -- This doesn't work under rust_doc_test because argv[0] is not what we expect.
//!
//!     use runfiles::Runfiles;
//!
//!     let r = Runfiles::create().unwrap();
//!     let path = r.rlocation("my_workspace/path/to/my/data.txt");
//!
//!     let f = File::open(path).unwrap();
//!     // ...
//!     ```

use std::collections::HashMap;
use std::env;
use std::ffi::OsString;
use std::fs;
use std::io;
use std::path::Path;
use std::path::PathBuf;

const RUNFILES_DIR_ENV_VAR: &str = "RUNFILES_DIR";
const MANIFEST_FILE_ENV_VAR: &str = "RUNFILES_MANIFEST_FILE";
const MANIFEST_ONLY_ENV_VAR: &str = "RUNFILES_MANIFEST_ONLY";
const TEST_SRCDIR_ENV_VAR: &str = "TEST_SRCDIR";
const EXTERNAL_GENERATED_FILE_REGEX: &str = "^bazel-out[/][^/]+/bin/external/([^/]+)/";
const EXTERNAL_FILE_REGEX: &str = "^external/([^/]+)/";

#[derive(Debug)]
enum Mode {
    DirectoryBased(PathBuf),
    ManifestBased(HashMap<PathBuf, PathBuf>),
}

#[derive(Debug)]
pub struct Runfiles {
    mode: Mode,
    repo_mapping: HashMap<String, String>,
    source_repository: String,
}

impl Runfiles {
    /// Creates a manifest based Runfiles object when
    /// RUNFILES_MANIFEST_ONLY environment variable is present,
    /// or a directory based Runfiles object otherwise.
    pub fn create() -> io::Result<Self> {
        let bootstrap_runfiles = if is_manifest_only() {
            Self::create_manifest_based()
        } else {
            Self::create_directory_based()
        };

        bootstrap_runfiles.map(|r| {
            let repo_mapping_file = r.rlocation("_repo_mapping");
            if repo_mapping_file.exists() {
                let repo_mapping = std::fs::read_to_string(repo_mapping_file)
                    .expect("failed to read _repo_mapping file")
                    .lines()
                    .map(|line| {
                        let triplet: Vec<&str> = line.splitn(3, ',').collect();
                        (
                            format!("{},{}", triplet[0], triplet[1]),
                            triplet[2].to_string(),
                        )
                    })
                    .collect::<HashMap<_, _>>();
                Runfiles {
                    mode: r.mode,
                    source_repository: r.source_repository,
                    repo_mapping,
                }
            } else {
                Runfiles {
                    mode: r.mode,
                    source_repository: r.source_repository,
                    repo_mapping: HashMap::new(),
                }
            }
        })
    }

    fn get_source_repository() -> String {
        let caller = std::env::current_exe().expect("failed to get current executable path");
        regex::Regex::new(EXTERNAL_GENERATED_FILE_REGEX)
            .expect("failed to compile EXTERNAL_GENERATED_FILE_REGEX regex")
            .captures(caller.to_str().unwrap())
            .map(|c| c[1].to_string())
            .or_else(|| {
                regex::Regex::new(EXTERNAL_FILE_REGEX)
                    .expect("failed to compile EXTERNAL_FILE_REGEX regex")
                    .captures(caller.to_str().unwrap())
                    .map(|c| c[1].to_string())
            })
            .unwrap_or_default()
    }

    fn create_directory_based() -> io::Result<Self> {
        Ok(Runfiles {
            mode: Mode::DirectoryBased(find_runfiles_dir()?),
            repo_mapping: HashMap::new(),
            source_repository: Self::get_source_repository(),
        })
    }

    fn create_manifest_based() -> io::Result<Self> {
        let manifest_path = find_manifest_path()?;
        let manifest_content = std::fs::read_to_string(manifest_path)?;
        let path_mapping = manifest_content
            .lines()
            .map(|line| {
                let pair = line
                    .split_once(' ')
                    .expect("manifest file contained unexpected content");
                (pair.0.into(), pair.1.into())
            })
            .collect::<HashMap<_, _>>();
        Ok(Runfiles {
            mode: Mode::ManifestBased(path_mapping),
            repo_mapping: HashMap::new(),
            source_repository: Self::get_source_repository(),
        })
    }

    /// Returns the runtime path of a runfile.
    ///
    /// Runfiles are data-dependencies of Bazel-built binaries and tests.
    /// The returned path may not be valid. The caller should check the path's
    /// validity and that the path exists.
    pub fn rlocation(&self, path: impl AsRef<Path>) -> PathBuf {
        let path = path.as_ref();

        if path.is_absolute() {
            return path.to_path_buf();
        }

        let mut path_components = path.components();
        let root = PathBuf::new().join(path_components.next().unwrap());
        let remainder = path_components.as_path();

        let repo_map_key = format!("{},{}", self.source_repository, root.to_string_lossy(),);
        let repo_mapped_path = self
            .repo_mapping
            .get(&repo_map_key)
            .cloned()
            .map(|v| PathBuf::new().join(v).join(remainder));

        let final_path = if let Some(repo_map_entry) = repo_mapped_path {
            repo_map_entry
        } else {
            path.to_path_buf()
        };

        match &self.mode {
            Mode::DirectoryBased(runfiles_dir) => runfiles_dir.join(final_path),
            Mode::ManifestBased(path_mapping) => path_mapping
                .get(final_path.as_path())
                .unwrap_or_else(|| {
                    panic!("Path {} not found among runfiles.", path.to_string_lossy())
                })
                .clone(),
        }
    }

    /// Returns the canonical name of the caller's Bazel repository.
    pub fn current_repository(&self) -> &str {
        // This value must match the value of `_RULES_RUST_RUNFILES_WORKSPACE_NAME`
        // which can be found in `@rules_rust//tools/runfiles/private:workspace_name.bzl`
        env!("RULES_RUST_RUNFILES_WORKSPACE_NAME")
    }
}

/// Returns the .runfiles directory for the currently executing binary.
pub fn find_runfiles_dir() -> io::Result<PathBuf> {
    assert_ne!(
        std::env::var_os(MANIFEST_ONLY_ENV_VAR).unwrap_or_else(|| OsString::from("0")),
        "1"
    );

    // If bazel told us about the runfiles dir, use that without looking further.
    if let Some(runfiles_dir) = std::env::var_os(RUNFILES_DIR_ENV_VAR).map(PathBuf::from) {
        if runfiles_dir.is_dir() {
            return Ok(runfiles_dir);
        }
    }
    if let Some(test_srcdir) = std::env::var_os(TEST_SRCDIR_ENV_VAR).map(PathBuf::from) {
        if test_srcdir.is_dir() {
            return Ok(test_srcdir);
        }
    }

    // Consume the first argument (argv[0])
    let exec_path = std::env::args().next().expect("arg 0 was not set");

    let mut binary_path = PathBuf::from(&exec_path);
    loop {
        // Check for our neighboring $binary.runfiles directory.
        let mut runfiles_name = binary_path.file_name().unwrap().to_owned();
        runfiles_name.push(".runfiles");

        let runfiles_path = binary_path.with_file_name(&runfiles_name);
        if runfiles_path.is_dir() {
            return Ok(runfiles_path);
        }

        // Check if we're already under a *.runfiles directory.
        {
            // TODO: 1.28 adds Path::ancestors() which is a little simpler.
            let mut next = binary_path.parent();
            while let Some(ancestor) = next {
                if ancestor
                    .file_name()
                    .map_or(false, |f| f.to_string_lossy().ends_with(".runfiles"))
                {
                    return Ok(ancestor.to_path_buf());
                }
                next = ancestor.parent();
            }
        }

        if !fs::symlink_metadata(&binary_path)?.file_type().is_symlink() {
            break;
        }
        // Follow symlinks and keep looking.
        let link_target = binary_path.read_link()?;
        binary_path = if link_target.is_absolute() {
            link_target
        } else {
            let link_dir = binary_path.parent().unwrap();
            env::current_dir()?.join(link_dir).join(link_target)
        }
    }

    Err(make_io_error("failed to find .runfiles directory"))
}

fn make_io_error(msg: &str) -> io::Error {
    io::Error::new(io::ErrorKind::Other, msg)
}

fn is_manifest_only() -> bool {
    match std::env::var(MANIFEST_ONLY_ENV_VAR) {
        Ok(val) => val == "1",
        Err(_) => false,
    }
}

fn find_manifest_path() -> io::Result<PathBuf> {
    assert_eq!(
        std::env::var_os(MANIFEST_ONLY_ENV_VAR).expect("RUNFILES_MANIFEST_ONLY was not set"),
        OsString::from("1")
    );
    match std::env::var_os(MANIFEST_FILE_ENV_VAR) {
        Some(path) => Ok(path.into()),
        None => Err(
            make_io_error(
                "RUNFILES_MANIFEST_ONLY was set to '1', but RUNFILES_MANIFEST_FILE was not set. Did Bazel change?"))
    }
}

#[cfg(test)]
mod test {
    use super::*;

    use std::fs::File;
    use std::io::prelude::*;

    #[test]
    fn test_can_read_data_from_runfiles() {
        // We want to run multiple test cases with different environment variables set. Since
        // environment variables are global state, we need to ensure the two test cases do not run
        // concurrently. Rust runs tests in parallel and does not provide an easy way to synchronise
        // them, so we run all test cases in the same #[test] function.

        let test_srcdir =
            env::var_os(TEST_SRCDIR_ENV_VAR).expect("bazel did not provide TEST_SRCDIR");
        let runfiles_dir =
            env::var_os(RUNFILES_DIR_ENV_VAR).expect("bazel did not provide RUNFILES_DIR");

        // Test case 1: Only $RUNFILES_DIR is set.
        {
            env::remove_var(TEST_SRCDIR_ENV_VAR);
            let r = Runfiles::create().unwrap();

            let mut f =
                File::open(r.rlocation("rules_rust/tools/runfiles/data/sample.txt")).unwrap();

            let mut buffer = String::new();
            f.read_to_string(&mut buffer).unwrap();

            assert_eq!("Example Text!", buffer);
            env::set_var(TEST_SRCDIR_ENV_VAR, &test_srcdir)
        }
        // Test case 2: Only $TEST_SRCDIR is set.
        {
            env::remove_var(RUNFILES_DIR_ENV_VAR);
            let r = Runfiles::create().unwrap();

            let mut f =
                File::open(r.rlocation("rules_rust/tools/runfiles/data/sample.txt")).unwrap();

            let mut buffer = String::new();
            f.read_to_string(&mut buffer).unwrap();

            assert_eq!("Example Text!", buffer);
            env::set_var(RUNFILES_DIR_ENV_VAR, &runfiles_dir)
        }

        // Test case 3: Neither are set
        {
            env::remove_var(RUNFILES_DIR_ENV_VAR);
            env::remove_var(TEST_SRCDIR_ENV_VAR);

            let r = Runfiles::create().unwrap();

            let mut f =
                File::open(r.rlocation("rules_rust/tools/runfiles/data/sample.txt")).unwrap();

            let mut buffer = String::new();
            f.read_to_string(&mut buffer).unwrap();

            assert_eq!("Example Text!", buffer);

            env::set_var(TEST_SRCDIR_ENV_VAR, &test_srcdir);
            env::set_var(RUNFILES_DIR_ENV_VAR, &runfiles_dir);
        }
    }

    #[test]
    fn test_manifest_based_can_read_data_from_runfiles() {
        let mut path_mapping = HashMap::new();
        path_mapping.insert("a/b".into(), "c/d".into());
        let r = Runfiles {
            mode: Mode::ManifestBased(path_mapping),
            repo_mapping: HashMap::new(),
            source_repository: "".to_string(),
        };

        assert_eq!(r.rlocation("a/b"), PathBuf::from("c/d"));
    }

    #[test]
    fn test_current_repository() {
        let r = Runfiles::create().unwrap();

        // This check is unique to the rules_rust repository. The name
        // here is expected to be different in consumers of this library
        if r.current_repository() == "_main" {
            // In the case where bzlmod is enabled the repository name will always be _main
        } else {
            assert_eq!(r.current_repository(), "rules_rust")
        }
    }
}
