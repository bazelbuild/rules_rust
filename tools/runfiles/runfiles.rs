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
//!     ```
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

use std::env;
use std::fs;
use std::io;
use std::path::Path;
use std::path::PathBuf;

pub struct Runfiles {
    runfiles_dir: PathBuf,
}

impl Runfiles {
    /// Creates a directory based Runfiles object.
    ///
    /// Manifest based creation is not currently supported.
    pub fn create() -> io::Result<Self> {
        Ok(Runfiles {
            runfiles_dir: find_runfiles_dir()?,
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
        self.runfiles_dir.join(path)
    }
}

/// Returns the .runfiles directory for the currently executing binary.
fn find_runfiles_dir() -> io::Result<PathBuf> {
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

    Err(io::Error::new(
        io::ErrorKind::Other,
        "Failed to find .runfiles directory.",
    ))
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
}
