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

//! Sandbox-specific worker helpers.

use super::exec::{materialize_output_file, run_request_with_current_dir};
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

/// Copies `src` into the request sandbox under `original_out_dir/dest_subdir`.
pub(super) fn copy_output_to_sandbox(
    src: &std::path::Path,
    sandbox_dir: &std::path::Path,
    original_out_dir: &str,
    dest_subdir: &str,
) -> Result<OutputMaterializationStats, MaterializeError> {
    let mut stats = OutputMaterializationStats::default();
    let filename = match src.file_name() {
        Some(n) => n,
        None => {
            return Err(MaterializeError {
                path: src.to_path_buf(),
                cause: std::io::Error::new(
                    std::io::ErrorKind::InvalidInput,
                    "source path has no filename",
                ),
            });
        }
    };
    let dest_dir = sandbox_dir.join(original_out_dir).join(dest_subdir);
    let dest = dest_dir.join(filename);
    let hardlinked = materialize_output_file(src, &dest)
        .map_err(|cause| MaterializeError { path: dest, cause })?;
    stats.files = 1;
    if hardlinked {
        stats.hardlinked_files = 1;
    } else {
        stats.copied_files = 1;
    }
    Ok(stats)
}

/// Copies all regular files from `pipeline_dir` into the request sandbox.
pub(super) fn copy_all_outputs_to_sandbox(
    pipeline_dir: &std::path::Path,
    sandbox_dir: &std::path::Path,
    original_out_dir: &str,
) -> Result<OutputMaterializationStats, MaterializeError> {
    let dest_dir = sandbox_dir.join(original_out_dir);
    let mut stats = OutputMaterializationStats::default();
    let entries = std::fs::read_dir(pipeline_dir).map_err(|cause| MaterializeError {
        path: pipeline_dir.to_path_buf(),
        cause,
    })?;
    for entry in entries {
        let entry = entry.map_err(|cause| MaterializeError {
            path: pipeline_dir.to_path_buf(),
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

/// Runs a subprocess with `sandbox_dir` as its current directory.
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

