// Copyright 2024 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//! Sandbox helpers for the persistent worker.

use std::path::PathBuf;

use super::exec::{materialize_output_file, prepare_outputs_impl, run_request_with_current_dir};
use super::pipeline::{MaterializeError, OutputMaterializationStats};
use crate::ProcessWrapperError;

#[cfg(unix)]
pub(super) fn symlink_path(
    src: &std::path::Path,
    dest: &std::path::Path,
    _is_dir: bool,
) -> Result<(), std::io::Error> {
    std::os::unix::fs::symlink(src, dest)
}

#[cfg(windows)]
pub(super) fn symlink_path(
    src: &std::path::Path,
    dest: &std::path::Path,
    is_dir: bool,
) -> Result<(), std::io::Error> {
    if is_dir {
        std::os::windows::fs::symlink_dir(src, dest)
    } else {
        std::os::windows::fs::symlink_file(src, dest)
    }
}

pub(super) fn seed_sandbox_cache_root(
    sandbox_dir: &std::path::Path,
) -> Result<(), ProcessWrapperError> {
    let dest = sandbox_dir.join("cache");
    if dest.exists() {
        return Ok(());
    }

    let entries = std::fs::read_dir(sandbox_dir).map_err(|e| {
        ProcessWrapperError(format!(
            "failed to read request sandbox for cache seeding: {e}"
        ))
    })?;

    for entry in entries {
        let entry = entry.map_err(|e| {
            ProcessWrapperError(format!("failed to enumerate request sandbox entry: {e}"))
        })?;
        let source = entry.path();
        let Ok(resolved) = source.canonicalize() else {
            continue;
        };

        let mut cache_root = None;
        for ancestor in resolved.ancestors() {
            if ancestor.file_name().is_some_and(|name| name == "cache") {
                cache_root = Some(ancestor.to_path_buf());
                break;
            }
        }

        let Some(cache_root) = cache_root else {
            continue;
        };
        return symlink_path(&cache_root, &dest, true).map_err(|e| {
            ProcessWrapperError(format!(
                "failed to seed request sandbox cache root {} -> {}: {e}",
                cache_root.display(),
                dest.display(),
            ))
        });
    }

    Ok(())
}

/// Copies the file at `src` into `<sandbox_dir>/<original_out_dir>/<dest_subdir>/`.
///
/// Used after the metadata action to make the `.rmeta` file visible to Bazel
/// inside the sandbox before the sandbox is cleaned up.
pub(super) fn copy_output_to_sandbox(
    src: &str,
    sandbox_dir: &str,
    original_out_dir: &str,
    dest_subdir: &str,
) -> Result<OutputMaterializationStats, MaterializeError> {
    let mut stats = OutputMaterializationStats::default();
    let src_path = std::path::Path::new(src);
    let filename = match src_path.file_name() {
        Some(n) => n,
        None => {
            return Err(MaterializeError {
                path: src_path.to_path_buf(),
                cause: std::io::Error::new(
                    std::io::ErrorKind::InvalidInput,
                    "source path has no filename",
                ),
            });
        }
    };
    let dest_dir = std::path::Path::new(sandbox_dir)
        .join(original_out_dir)
        .join(dest_subdir);
    let dest = dest_dir.join(filename);
    let hardlinked = materialize_output_file(src_path, &dest)
        .map_err(|cause| MaterializeError { path: dest, cause })?;
    stats.files = 1;
    if hardlinked {
        stats.hardlinked_files = 1;
    } else {
        stats.copied_files = 1;
    }
    Ok(stats)
}

/// Copies all regular files from `pipeline_dir` into `<sandbox_dir>/<original_out_dir>/`.
///
/// Used by the full action to move the `.rlib` (and `.d`, etc.) from the
/// persistent directory into the sandbox before responding to Bazel.
pub(super) fn copy_all_outputs_to_sandbox(
    pipeline_dir: &PathBuf,
    sandbox_dir: &str,
    original_out_dir: &str,
) -> Result<OutputMaterializationStats, MaterializeError> {
    let dest_dir = std::path::Path::new(sandbox_dir).join(original_out_dir);
    let mut stats = OutputMaterializationStats::default();
    let entries = std::fs::read_dir(pipeline_dir).map_err(|cause| MaterializeError {
        path: pipeline_dir.clone(),
        cause,
    })?;
    for entry in entries {
        let entry = entry.map_err(|cause| MaterializeError {
            path: pipeline_dir.clone(),
            cause,
        })?;
        let meta = entry.metadata().map_err(|cause| MaterializeError {
            path: entry.path(),
            cause,
        })?;
        if meta.is_file() {
            let dest = dest_dir.join(entry.file_name());
            let hardlinked = materialize_output_file(&entry.path(), &dest)
                .map_err(|cause| MaterializeError { path: dest, cause })?;
            stats.files += 1;
            if hardlinked {
                stats.hardlinked_files += 1;
            } else {
                stats.copied_files += 1;
            }
        }
    }
    Ok(stats)
}

/// Like `run_request` but sets `current_dir(sandbox_dir)` on the subprocess.
///
/// When Bazel provides a `sandboxDir`, setting the subprocess CWD to it makes
/// all relative paths in arguments resolve correctly within the sandbox.
pub(super) fn run_sandboxed_request(
    self_path: &std::path::Path,
    arguments: Vec<String>,
    sandbox_dir: &str,
) -> Result<(i32, String), ProcessWrapperError> {
    let _ = seed_sandbox_cache_root(std::path::Path::new(sandbox_dir));
    run_request_with_current_dir(
        self_path,
        arguments,
        Some(sandbox_dir),
        "sandboxed subprocess",
    )
}

pub(super) fn prepare_outputs_in_dir(args: &[String], request_base_dir: &std::path::Path) {
    prepare_outputs_impl(args, Some(request_base_dir));
}
