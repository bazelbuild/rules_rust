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

enum Mode {
    DirectoryBased(PathBuf),
    ManifestBased(HashMap<PathBuf, PathBuf>),
}

pub struct Runfiles {
    mode: Mode,
}

impl Runfiles {
    /// Creates a manifest based Runfiles object when
    /// RUNFILES_MANIFEST_ONLY environment variable is present,
    /// or a directory based Runfiles object otherwise.
    pub fn create() -> io::Result<Self> {
        if is_manifest_only() {
            Self::create_manifest_based()
        } else {
            Self::create_directory_based()
        }
    }

    fn create_directory_based() -> io::Result<Self> {
        Ok(Runfiles {
            mode: Mode::DirectoryBased(find_runfiles_dir()?),
        })
    }

    fn create_manifest_based() -> io::Result<Self> {
        let manifest_path = find_manifest_path()?;
        let manifest_content = std::fs::read_to_string(manifest_path)?;
        let path_mapping = manifest_content
            .lines()
            .map(|line| {
                let pair = line
                    .split_once(" ")
                    .expect("manifest file contained unexpected content");
                (pair.0.into(), pair.1.into())
            })
            .collect::<HashMap<_, _>>();
        Ok(Runfiles {
            mode: Mode::ManifestBased(path_mapping),
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
        match &self.mode {
            Mode::DirectoryBased(runfiles_dir) => runfiles_dir.join(path),
            Mode::ManifestBased(path_mapping) => path_mapping
                .get(path)
                .expect(&format!(
                    "Path {} not found among runfiles.",
                    path.to_string_lossy()
                ))
                .clone(),
        }
    }
}

/// Returns the .runfiles directory for the currently executing binary.
pub fn find_runfiles_dir() -> io::Result<PathBuf> {
    assert_ne!(
        std::env::var_os("RUNFILES_MANIFEST_ONLY").unwrap_or(OsString::from("0")),
        "1"
    );
    let exec_path = std::env::args().nth(0).expect("arg 0 was not set");

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
    match std::env::var("RUNFILES_MANIFEST_ONLY") {
        Ok(val) => val == "1",
        Err(_) => false,
    }
}

fn find_manifest_path() -> io::Result<PathBuf> {
    assert_eq!(
        std::env::var_os("RUNFILES_MANIFEST_ONLY").expect("RUNFILES_MANIFEST_ONLY was not set"),
        OsString::from("1")
    );
    match std::env::var_os("RUNFILES_MANIFEST_FILE") {
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
        let r = Runfiles::create().unwrap();

        let mut f = File::open(r.rlocation("rules_rust/tools/runfiles/data/sample.txt")).unwrap();

        let mut buffer = String::new();
        f.read_to_string(&mut buffer).unwrap();

        assert_eq!("Example Text!", buffer);
    }

    #[test]
    fn test_manifest_based_can_read_data_from_runfiles() {
        let mut path_mapping = HashMap::new();
        path_mapping.insert("a/b".into(), "c/d".into());
        let r = Runfiles {
            mode: Mode::ManifestBased(path_mapping),
        };

        assert_eq!(r.rlocation("a/b"), PathBuf::from("c/d"));
    }
}
