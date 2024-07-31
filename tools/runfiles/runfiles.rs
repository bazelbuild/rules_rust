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
//! 3.  Create a Runfiles object and use `rlocation!`` to look up runfile paths:
//!     ```ignore -- This doesn't work under rust_doc_test because argv[0] is not what we expect.
//!
//!     use runfiles::{Runfiles, rlocation};
//!
//!     let r = Runfiles::create().unwrap();
//!     let path = rlocation!(r, "my_workspace/path/to/my/data.txt");
//!
//!     let f = File::open(path).unwrap();
//!     // ...
//!     ```

use std::collections::HashMap;
use std::env;
use std::fs;
use std::io;
use std::path::Path;
use std::path::PathBuf;

const RUNFILES_DIR_ENV_VAR: &str = "RUNFILES_DIR";
const MANIFEST_FILE_ENV_VAR: &str = "RUNFILES_MANIFEST_FILE";
const TEST_SRCDIR_ENV_VAR: &str = "TEST_SRCDIR";

#[macro_export]
macro_rules! rlocation {
    ($r:expr, $path:expr) => {
        $r.rlocation_from($path, env!("REPOSITORY_NAME"))
    };
}

#[derive(Debug)]
enum Mode {
    DirectoryBased(PathBuf),
    ManifestBased(HashMap<PathBuf, PathBuf>),
}

type RepoMappingKey = (String, String);
type RepoMapping = HashMap<RepoMappingKey, String>;

#[derive(Debug)]
pub struct Runfiles {
    mode: Mode,
    repo_mapping: RepoMapping,
}

impl Runfiles {
    /// Creates a manifest based Runfiles object when
    /// RUNFILES_MANIFEST_FILE environment variable is present,
    /// or a directory based Runfiles object otherwise.
    pub fn create() -> io::Result<Self> {
        let mode = if let Some(manifest_file) = std::env::var_os(MANIFEST_FILE_ENV_VAR) {
            Self::create_manifest_based(Path::new(&manifest_file))?
        } else {
            Mode::DirectoryBased(find_runfiles_dir()?)
        };

        let repo_mapping = parse_repo_mapping(raw_rlocation(&mode, "_repo_mapping"))
            .unwrap_or_else(|_| {
                println!("No repo mapping found!");
                RepoMapping::new()
            });

        Ok(Runfiles { mode, repo_mapping })
    }

    fn create_manifest_based(manifest_path: &Path) -> io::Result<Mode> {
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
        Ok(Mode::ManifestBased(path_mapping))
    }

    /// Returns the runtime path of a runfile.
    ///
    /// Runfiles are data-dependencies of Bazel-built binaries and tests.
    /// The returned path may not be valid. The caller should check the path's
    /// validity and that the path exists.
    /// @deprecated - this is not bzlmod-aware. Prefer the `rlocation!` macro or `rlocation_from`
    pub fn rlocation(&self, path: impl AsRef<Path>) -> PathBuf {
        let path = path.as_ref();
        if path.is_absolute() {
            return path.to_path_buf();
        }
        raw_rlocation(&self.mode, path)
    }

    /// Returns the runtime path of a runfile.
    ///
    /// Runfiles are data-dependencies of Bazel-built binaries and tests.
    /// The returned path may not be valid. The caller should check the path's
    /// validity and that the path exists.
    ///
    /// Typically this should be used via the `rlocation!` macro to properly set source_repo.
    pub fn rlocation_from(&self, path: impl AsRef<Path>, source_repo: &str) -> PathBuf {
        let path = path.as_ref();
        if path.is_absolute() {
            return path.to_path_buf();
        }

        let path_str = path.to_str().expect("Should be valid UTF8");
        let (repo_alias, repo_path): (&str, Option<&str>) = match path_str.split_once('/') {
            Some((name, alias)) => (name, Some(alias)),
            None => (path_str, None),
        };
        let key: (String, String) = (source_repo.into(), repo_alias.into());
        if let Some(target_repo_directory) = self.repo_mapping.get(&key) {
            match repo_path {
                Some(repo_path) => {
                    raw_rlocation(&self.mode, format!("{target_repo_directory}/{repo_path}"))
                }
                None => raw_rlocation(&self.mode, target_repo_directory),
            }
        } else {
            raw_rlocation(&self.mode, path)
        }
    }
}

fn raw_rlocation(mode: &Mode, path: impl AsRef<Path>) -> PathBuf {
    let path = path.as_ref();
    match mode {
        Mode::DirectoryBased(runfiles_dir) => runfiles_dir.join(path),
        Mode::ManifestBased(path_mapping) => path_mapping
            .get(path)
            .unwrap_or_else(|| panic!("Path {} not found among runfiles.", path.to_string_lossy()))
            .clone(),
    }
}

fn parse_repo_mapping(path: PathBuf) -> io::Result<RepoMapping> {
    let mut repo_mapping = RepoMapping::new();

    for line in std::fs::read_to_string(path)?.lines() {
        let parts: Vec<&str> = line.splitn(3, ',').collect();
        if parts.len() < 3 {
            return Err(make_io_error("Malformed repo_mapping file"));
        }
        repo_mapping.insert((parts[0].into(), parts[1].into()), parts[2].into());
    }

    Ok(repo_mapping)
}

/// Returns the .runfiles directory for the currently executing binary.
pub fn find_runfiles_dir() -> io::Result<PathBuf> {
    assert!(std::env::var_os(MANIFEST_FILE_ENV_VAR).is_none());

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

#[cfg(test)]
mod test {
    use super::*;

    use std::fs::File;
    use std::io::prelude::*;

    #[test]
    fn test_can_read_data_from_runfiles() {
        // We want to run multiple test cases with different environment variables set. Since
        // environment variables are global state, we need to ensure the test cases do not run
        // concurrently. Rust runs tests in parallel and does not provide an easy way to synchronise
        // them, so we run all test cases in the same #[test] function.

        let test_srcdir =
            env::var_os(TEST_SRCDIR_ENV_VAR).expect("bazel did not provide TEST_SRCDIR");
        let runfiles_dir =
            env::var_os(RUNFILES_DIR_ENV_VAR).expect("bazel did not provide RUNFILES_DIR");
        let runfiles_manifest_file = env::var_os(MANIFEST_FILE_ENV_VAR).unwrap_or("".into());

        // Test case 1: Only $RUNFILES_DIR is set.
        {
            env::remove_var(TEST_SRCDIR_ENV_VAR);
            env::remove_var(MANIFEST_FILE_ENV_VAR);
            let r = Runfiles::create().unwrap();

            let d = rlocation!(r, "rules_rust");
            let f = rlocation!(r, "rules_rust/tools/runfiles/data/sample.txt");
            assert_eq!(d.join("tools/runfiles/data/sample.txt"), f);

            let mut f = File::open(f).unwrap();

            let mut buffer = String::new();
            f.read_to_string(&mut buffer).unwrap();

            assert_eq!("Example Text!", buffer);
            env::set_var(TEST_SRCDIR_ENV_VAR, &test_srcdir);
            env::set_var(MANIFEST_FILE_ENV_VAR, &runfiles_manifest_file);
        }
        // Test case 2: Only $TEST_SRCDIR is set.
        {
            env::remove_var(RUNFILES_DIR_ENV_VAR);
            env::remove_var(MANIFEST_FILE_ENV_VAR);
            let r = Runfiles::create().unwrap();

            let mut f =
                File::open(rlocation!(r, "rules_rust/tools/runfiles/data/sample.txt")).unwrap();

            let mut buffer = String::new();
            f.read_to_string(&mut buffer).unwrap();

            assert_eq!("Example Text!", buffer);
            env::set_var(RUNFILES_DIR_ENV_VAR, &runfiles_dir);
            env::set_var(MANIFEST_FILE_ENV_VAR, &runfiles_manifest_file);
        }

        // Test case 3: Neither are set
        {
            env::remove_var(RUNFILES_DIR_ENV_VAR);
            env::remove_var(TEST_SRCDIR_ENV_VAR);
            env::remove_var(MANIFEST_FILE_ENV_VAR);

            let r = Runfiles::create().unwrap();

            let mut f =
                File::open(rlocation!(r, "rules_rust/tools/runfiles/data/sample.txt")).unwrap();

            let mut buffer = String::new();
            f.read_to_string(&mut buffer).unwrap();

            assert_eq!("Example Text!", buffer);

            env::set_var(TEST_SRCDIR_ENV_VAR, &test_srcdir);
            env::set_var(RUNFILES_DIR_ENV_VAR, &runfiles_dir);
            env::set_var(MANIFEST_FILE_ENV_VAR, &runfiles_manifest_file);
        }
    }

    #[test]
    fn test_manifest_based_can_read_data_from_runfiles() {
        let mut path_mapping = HashMap::new();
        path_mapping.insert("a/b".into(), "c/d".into());
        let r = Runfiles {
            mode: Mode::ManifestBased(path_mapping),
            repo_mapping: RepoMapping::new(),
        };

        assert_eq!(r.rlocation("a/b"), PathBuf::from("c/d"));
    }
}
