//! Bazel interactions with `CARGO_MANIFEST_DIR`.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

pub type RlocationPath = String;

/// Create a symlink file on unix systems
#[cfg(target_family = "unix")]
pub fn symlink(src: &Path, dest: &Path) -> Result<(), std::io::Error> {
    std::os::unix::fs::symlink(src, dest)
}

/// Create a symlink file on windows systems
#[cfg(target_family = "windows")]
pub fn symlink(src: &Path, dest: &Path) -> Result<(), std::io::Error> {
    if src.is_dir() {
        std::os::windows::fs::symlink_dir(src, dest)
    } else {
        std::os::windows::fs::symlink_file(src, dest)
    }
}

/// Create a symlink file on unix systems
#[cfg(target_family = "unix")]
pub fn remove_symlink(path: &Path) -> Result<(), std::io::Error> {
    std::fs::remove_file(path)
}

/// Remove a symlink or junction on Windows.
///
/// Windows has three kinds of reparse points we may encounter:
///   1. File symlinks — `remove_file` works.
///   2. Directory symlinks — `remove_dir` removes the link itself (not the
///      target contents), but `remove_file` also works on some Windows versions.
///   3. Junctions — similar to directory symlinks; `remove_dir` removes the
///      junction entry.
///
/// We use `symlink_metadata` + `FileTypeExt` to classify the entry and try
/// the most appropriate removal call first, with a fallback for edge cases.
#[cfg(target_family = "windows")]
pub fn remove_symlink(path: &Path) -> Result<(), std::io::Error> {
    use std::os::windows::fs::FileTypeExt;

    let metadata = std::fs::symlink_metadata(path)?;
    let ft = metadata.file_type();

    if ft.is_symlink_file() {
        return std::fs::remove_file(path);
    }

    if ft.is_symlink_dir() {
        // remove_dir removes the symlink entry itself, not the target contents.
        // Fall back to remove_file if remove_dir fails (some Windows versions).
        return std::fs::remove_dir(path).or_else(|_| std::fs::remove_file(path));
    }

    // Junctions appear as directories but are not symlinks per FileTypeExt.
    // remove_dir removes the junction entry itself.
    if ft.is_dir() {
        return std::fs::remove_dir(path).or_else(|_| std::fs::remove_file(path));
    }

    std::fs::remove_file(path)
}

/// Check if the system supports symlinks by attempting to create one.
fn system_supports_symlinks(test_dir: &Path) -> Result<bool, String> {
    let test_file = test_dir.join("cbsr.txt");
    std::fs::write(&test_file, "").map_err(|e| {
        format!(
            "Failed to write test file for checking symlink support '{}' with {:?}",
            test_file.display(),
            e
        )
    })?;
    let test_link = test_dir.join("cbsr.link.txt");
    match symlink(&test_file, &test_link) {
        Err(_) => {
            std::fs::remove_file(test_file).map_err(|e| {
                format!("Failed to delete file {} with {:?}", test_link.display(), e)
            })?;
            Ok(false)
        }
        Ok(_) => {
            remove_symlink(&test_link).map_err(|e| {
                format!(
                    "Failed to remove symlink {} with {:?}",
                    test_link.display(),
                    e
                )
            })?;
            std::fs::remove_file(test_file).map_err(|e| {
                format!("Failed to delete file {} with {:?}", test_link.display(), e)
            })?;
            Ok(true)
        }
    }
}

fn is_dir_empty(path: &Path) -> Result<bool, String> {
    let mut entries = std::fs::read_dir(path)
        .map_err(|e| format!("Failed to read directory: {} with {:?}", path.display(), e))?;

    Ok(entries.next().is_none())
}

/// A struct for generating runfiles directories to use when running Cargo build scripts.
pub struct RunfilesMaker {
    /// The output where a runfiles-like directory should be written.
    output_dir: PathBuf,

    /// A list of file suffixes to retain when pruning runfiles.
    filename_suffixes_to_retain: BTreeSet<String>,

    /// Runfiles to include in `output_dir`.
    runfiles: BTreeMap<PathBuf, RlocationPath>,
}

impl RunfilesMaker {
    pub fn from_param_file(arg: &str) -> RunfilesMaker {
        assert!(
            arg.starts_with('@'),
            "Expected arg to be a params file. Got {}",
            arg
        );

        let content = std::fs::read_to_string(
            arg.strip_prefix('@')
                .expect("Param files should start with @"),
        )
        .unwrap();
        let mut args = content.lines();

        let output_dir = PathBuf::from(
            args.next()
                .unwrap_or_else(|| panic!("Not enough arguments provided.")),
        );
        let filename_suffixes_to_retain = args
            .next()
            .unwrap_or_else(|| panic!("Not enough arguments provided."))
            .split(',')
            .map(|s| s.to_owned())
            .collect::<BTreeSet<String>>();
        let runfiles = args
            .map(|s| {
                let s = if s.starts_with('\'') && s.ends_with('\'') {
                    s.trim_matches('\'')
                } else {
                    s
                };
                let (src, dest) = s
                    .split_once('=')
                    .unwrap_or_else(|| panic!("Unexpected runfiles argument: {}", s));
                (PathBuf::from(src), RlocationPath::from(dest))
            })
            .collect::<BTreeMap<_, _>>();

        assert!(!runfiles.is_empty(), "No runfiles found");

        RunfilesMaker {
            output_dir,
            filename_suffixes_to_retain,
            runfiles,
        }
    }

    /// Create a runfiles directory.
    #[cfg(target_family = "unix")]
    pub fn create_runfiles_dir(&self) -> Result<(), String> {
        for (src, dest) in &self.runfiles {
            let abs_dest = self.output_dir.join(dest);

            if let Some(parent) = abs_dest.parent() {
                if !parent.exists() {
                    std::fs::create_dir_all(parent).map_err(|e| {
                        format!(
                            "Failed to create parent directory '{}' for '{}' with {:?}",
                            parent.display(),
                            abs_dest.display(),
                            e
                        )
                    })?;
                }
            }

            let abs_src = std::env::current_dir().unwrap().join(src);

            symlink(&abs_src, &abs_dest).map_err(|e| {
                format!(
                    "Failed to link `{} -> {}` with {:?}",
                    abs_src.display(),
                    abs_dest.display(),
                    e
                )
            })?;
        }

        Ok(())
    }

    /// Create a runfiles directory.
    #[cfg(target_family = "windows")]
    pub fn create_runfiles_dir(&self) -> Result<(), String> {
        if !self.output_dir.exists() {
            std::fs::create_dir_all(&self.output_dir).map_err(|e| {
                format!(
                    "Failed to create output directory '{}' with {:?}",
                    self.output_dir.display(),
                    e
                )
            })?;
        }

        let supports_symlinks = system_supports_symlinks(&self.output_dir)?;

        for (src, dest) in &self.runfiles {
            let abs_dest = self.output_dir.join(dest);
            if let Some(parent) = abs_dest.parent() {
                if !parent.exists() {
                    std::fs::create_dir_all(parent).map_err(|e| {
                        format!(
                            "Failed to create parent directory '{}' for '{}' with {:?}",
                            parent.display(),
                            abs_dest.display(),
                            e
                        )
                    })?;
                }
            }

            if supports_symlinks {
                let abs_src = std::env::current_dir().unwrap().join(src);

                symlink(&abs_src, &abs_dest).map_err(|e| {
                    format!(
                        "Failed to link `{} -> {}` with {:?}",
                        abs_src.display(),
                        abs_dest.display(),
                        e
                    )
                })?;
            } else {
                std::fs::copy(src, &abs_dest).map_err(|e| {
                    format!(
                        "Failed to copy `{} -> {}` with {:?}",
                        src.display(),
                        abs_dest.display(),
                        e
                    )
                })?;
            }
        }
        Ok(())
    }

    /// Strip runfiles that do not match a retained suffix.
    ///
    /// When `symlinks_used` is true the runfiles directory was populated with
    /// symlinks: every entry is removed and only retained entries are copied
    /// back as real files. When false, real file copies were used (Windows
    /// without symlink support) and only retained entries are deleted so that
    /// downstream steps can recreate them.
    ///
    /// Missing entries are tolerated in either mode — on Windows the runfiles
    /// directory may be incomplete (e.g. a Cargo.lock that was never created).
    fn drain_runfiles_dir_impl(&self, symlinks_used: bool) -> Result<(), String> {
        for (src, dest) in &self.runfiles {
            let abs_dest = self.output_dir.join(dest);
            let should_retain = self
                .filename_suffixes_to_retain
                .iter()
                .any(|suffix| dest.ends_with(suffix));

            if symlinks_used {
                match remove_symlink(&abs_dest) {
                    Ok(()) => {}
                    Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
                        if !should_retain {
                            continue;
                        }
                    }
                    Err(e) => {
                        return Err(format!(
                            "Failed to delete symlink '{}' with {:?}",
                            abs_dest.display(),
                            e
                        ));
                    }
                }

                if !should_retain {
                    if let Some(parent) = abs_dest.parent() {
                        if is_dir_empty(parent).map_err(|e| {
                            format!("Failed to determine if directory was empty with: {:?}", e)
                        })? {
                            std::fs::remove_dir(parent).map_err(|e| {
                                format!(
                                    "Failed to delete directory {} with {:?}",
                                    parent.display(),
                                    e
                                )
                            })?;
                        }
                    }
                    continue;
                }

                std::fs::copy(src, &abs_dest).map_err(|e| {
                    format!(
                        "Failed to copy `{} -> {}` with {:?}",
                        src.display(),
                        abs_dest.display(),
                        e
                    )
                })?;
            } else if !should_retain {
                // Non-symlink mode: non-retained files are left as-is (no
                // empty-directory cleanup needed since the files were never
                // removed in the first place).
                continue;
            } else {
                match std::fs::remove_file(&abs_dest) {
                    Ok(()) => {}
                    Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
                    Err(e) => {
                        return Err(format!(
                            "Failed to remove file {} with {:?}",
                            abs_dest.display(),
                            e
                        ));
                    }
                }
            }
        }
        Ok(())
    }

    /// Delete runfiles from the runfiles directory that do not match user defined suffixes
    pub fn drain_runfiles_dir(&self, out_dir: &Path) -> Result<(), String> {
        if cfg!(target_family = "windows") {
            let supports_symlinks = system_supports_symlinks(&self.output_dir)?;
            self.drain_runfiles_dir_impl(supports_symlinks)?;
        } else {
            self.drain_runfiles_dir_impl(true)?;
        }

        // Due to the symlinks in `CARGO_MANIFEST_DIR`, some build scripts
        // may have placed symlinks over real files in `OUT_DIR`. To counter
        // this, all non-relative symlinks are resolved.
        replace_symlinks_in_out_dir(out_dir)
    }
}

/// Iterates over the given directory recursively and resolves any symlinks
///
/// Symlinks shouldn't present in `out_dir` as those amy contain paths to sandboxes which doesn't exists anymore.
/// Therefore, bazel will fail because of dangling symlinks.
fn replace_symlinks_in_out_dir(out_dir: &Path) -> Result<(), String> {
    if out_dir.is_dir() {
        let out_dir_paths = std::fs::read_dir(out_dir).map_err(|e| {
            format!(
                "Failed to read directory `{}` with {:?}",
                out_dir.display(),
                e
            )
        })?;
        for entry in out_dir_paths {
            let entry =
                entry.map_err(|e| format!("Failed to read directory entry with  {:?}", e,))?;
            let path = entry.path();

            if path.is_symlink() {
                let target_path = std::fs::read_link(&path).map_err(|e| {
                    format!("Failed to read symlink `{}` with {:?}", path.display(), e,)
                })?;
                // we don't want to replace relative symlinks
                if target_path.is_relative() {
                    continue;
                }
                std::fs::remove_file(&path)
                    .map_err(|e| format!("Failed remove file `{}` with {:?}", path.display(), e))?;
                std::fs::copy(&target_path, &path).map_err(|e| {
                    format!(
                        "Failed to copy `{} -> {}` with {:?}",
                        target_path.display(),
                        path.display(),
                        e
                    )
                })?;
            } else if path.is_dir() {
                replace_symlinks_in_out_dir(&path).map_err(|e| {
                    format!(
                        "Failed to normalize nested directory `{}` with {}",
                        path.display(),
                        e,
                    )
                })?;
            }
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {

    use std::fs;
    use std::io::Write;

    use super::*;

    fn prepare_output_dir_with_symlinks() -> PathBuf {
        let test_tmp = PathBuf::from(std::env::var("TEST_TMPDIR").unwrap());
        let out_dir = test_tmp.join("out_dir");
        fs::create_dir(&out_dir).unwrap();
        let nested_dir = out_dir.join("nested");
        fs::create_dir(nested_dir).unwrap();

        let temp_dir_file = test_tmp.join("outside.txt");
        let mut file = fs::File::create(&temp_dir_file).unwrap();
        file.write_all(b"outside world").unwrap();
        // symlink abs path outside of the out_dir
        symlink(&temp_dir_file, &out_dir.join("outside.txt")).unwrap();

        let inside_dir_file = out_dir.join("inside.txt");
        let mut file = fs::File::create(inside_dir_file).unwrap();
        file.write_all(b"inside world").unwrap();
        // symlink relative next to the file in the out_dir
        symlink(
            &PathBuf::from("inside.txt"),
            &out_dir.join("inside_link.txt"),
        )
        .unwrap();
        // symlink relative within a subdir in the out_dir
        symlink(
            &PathBuf::from("..").join("inside.txt"),
            &out_dir.join("nested").join("inside_link.txt"),
        )
        .unwrap();

        out_dir
    }

    /// Create a `RunfilesMaker` for testing without needing a param file.
    fn make_runfiles_maker(
        output_dir: PathBuf,
        suffixes: &[&str],
        runfiles: Vec<(PathBuf, RlocationPath)>,
    ) -> RunfilesMaker {
        RunfilesMaker {
            output_dir,
            filename_suffixes_to_retain: suffixes.iter().map(|s| s.to_string()).collect(),
            runfiles: runfiles.into_iter().collect(),
        }
    }

    /// Helper to create a unique test directory under TEST_TMPDIR.
    fn test_dir(name: &str) -> PathBuf {
        let test_tmp = PathBuf::from(std::env::var("TEST_TMPDIR").unwrap());
        let dir = test_tmp.join(name);
        if dir.exists() {
            fs::remove_dir_all(&dir).unwrap();
        }
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[cfg(any(target_family = "windows", target_family = "unix"))]
    #[test]
    fn drain_symlinks_tolerates_missing_symlinks() {
        let base = test_dir("drain_sym_missing");
        let output_dir = base.join("runfiles");
        fs::create_dir_all(&output_dir).unwrap();

        // Two distinct source files so BTreeMap keeps both entries.
        let src_real = base.join("real.txt");
        fs::write(&src_real, "content").unwrap();
        let src_lock = base.join("Cargo.lock");
        fs::write(&src_lock, "lock data").unwrap();

        // Two runfile entries: one exists as a symlink, one does not.
        let existing_dest = "pkg/real.txt";
        let missing_dest = "pkg/Cargo.lock";
        let abs_existing = output_dir.join(existing_dest);
        fs::create_dir_all(abs_existing.parent().unwrap()).unwrap();
        symlink(&src_real, &abs_existing).unwrap();
        // Intentionally do NOT create a symlink for missing_dest.

        let maker = make_runfiles_maker(
            output_dir.clone(),
            &[], // retain nothing
            vec![
                (src_real.clone(), existing_dest.to_string()),
                (src_lock.clone(), missing_dest.to_string()),
            ],
        );

        // Should succeed despite the missing symlink.
        maker.drain_runfiles_dir_impl(true).unwrap();

        // The existing symlink should have been removed.
        assert!(!abs_existing.exists());
    }

    #[cfg(any(target_family = "windows", target_family = "unix"))]
    #[test]
    fn drain_symlinks_retains_matching_suffixes() {
        let base = test_dir("drain_sym_retain");
        let output_dir = base.join("runfiles");
        fs::create_dir_all(&output_dir).unwrap();

        let src_file = base.join("lib.rs");
        fs::write(&src_file, "fn main() {}").unwrap();

        let src_lock = base.join("Cargo.lock");
        fs::write(&src_lock, "lock contents").unwrap();

        let rs_dest = "pkg/lib.rs";
        let lock_dest = "pkg/Cargo.lock";

        // Create symlinks for both entries.
        let abs_rs = output_dir.join(rs_dest);
        let abs_lock = output_dir.join(lock_dest);
        fs::create_dir_all(abs_rs.parent().unwrap()).unwrap();
        symlink(&src_file, &abs_rs).unwrap();
        symlink(&src_lock, &abs_lock).unwrap();

        let maker = make_runfiles_maker(
            output_dir.clone(),
            &[".rs"], // only retain .rs files
            vec![
                (src_file.clone(), rs_dest.to_string()),
                (src_lock.clone(), lock_dest.to_string()),
            ],
        );

        maker.drain_runfiles_dir_impl(true).unwrap();

        // .rs file should be retained (copied back as a real file, not a symlink).
        assert!(abs_rs.exists());
        assert!(!abs_rs.is_symlink());
        assert_eq!(fs::read_to_string(&abs_rs).unwrap(), "fn main() {}");

        // .lock file should have been removed.
        assert!(!abs_lock.exists());
    }

    #[cfg(any(target_family = "windows", target_family = "unix"))]
    #[test]
    fn drain_symlinks_missing_with_retained_suffix_still_copies() {
        let base = test_dir("drain_sym_missing_retain");
        let output_dir = base.join("runfiles");
        fs::create_dir_all(&output_dir).unwrap();

        let src_file = base.join("lib.rs");
        fs::write(&src_file, "fn main() {}").unwrap();

        let dest = "pkg/lib.rs";
        // Create the parent dir but NOT the symlink.
        fs::create_dir_all(output_dir.join("pkg")).unwrap();

        let maker = make_runfiles_maker(
            output_dir.clone(),
            &[".rs"], // retain .rs files
            vec![(src_file.clone(), dest.to_string())],
        );

        // Should succeed — missing symlink is tolerated, file is still copied.
        maker.drain_runfiles_dir_impl(true).unwrap();

        let abs_dest = output_dir.join(dest);
        assert!(abs_dest.exists());
        assert!(!abs_dest.is_symlink());
        assert_eq!(fs::read_to_string(&abs_dest).unwrap(), "fn main() {}");
    }

    #[cfg(any(target_family = "windows", target_family = "unix"))]
    #[test]
    fn drain_no_symlinks_tolerates_missing_files() {
        let base = test_dir("drain_nosym_missing");
        let output_dir = base.join("runfiles");
        fs::create_dir_all(&output_dir).unwrap();

        let src_file = base.join("real.txt");
        fs::write(&src_file, "content").unwrap();

        // Retain .txt but the file doesn't exist in the runfiles dir.
        let maker = make_runfiles_maker(
            output_dir.clone(),
            &[".txt"],
            vec![(src_file.clone(), "pkg/real.txt".to_string())],
        );

        // Should succeed despite the missing file.
        maker.drain_runfiles_dir_impl(false).unwrap();
    }

    #[cfg(any(target_family = "windows", target_family = "unix"))]
    #[test]
    fn replace_symlinks_in_out_dir() {
        let out_dir = prepare_output_dir_with_symlinks();
        super::replace_symlinks_in_out_dir(&out_dir).unwrap();

        // this should be replaced because it is an absolute symlink
        let file_path = out_dir.join("outside.txt");
        assert!(!file_path.is_symlink());
        let contents = fs::read_to_string(file_path).unwrap();
        assert_eq!(contents, "outside world");

        // this is the file created inside the out_dir
        let file_path = out_dir.join("inside.txt");
        assert!(!file_path.is_symlink());
        let contents = fs::read_to_string(file_path).unwrap();
        assert_eq!(contents, "inside world");

        // this is the symlink in the out_dir
        let file_path = out_dir.join("inside_link.txt");
        assert!(file_path.is_symlink());
        let contents = fs::read_to_string(file_path).unwrap();
        assert_eq!(contents, "inside world");

        // this is the symlink in the out_dir under another directory which refers to ../inside.txt
        let file_path = out_dir.join("nested").join("inside_link.txt");
        assert!(file_path.is_symlink());
        let contents = fs::read_to_string(file_path).unwrap();
        assert_eq!(contents, "inside world");
    }
}
