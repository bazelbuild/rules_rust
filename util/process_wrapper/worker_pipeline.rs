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

//! Pipelining helpers for the persistent worker.

use std::fmt;
use std::path::PathBuf;

use crate::ProcessWrapperError;

use super::exec::is_same_file;
use super::logging::append_pipeline_log;
use super::request::WorkRequest;
use super::types::PipelineKey;

pub(super) fn pipelining_err(msg: impl std::fmt::Display) -> (i32, String) {
    (1, format!("pipelining: {msg}"))
}

/// Directories used for one worker-managed pipelined request.
pub(super) struct PipelineContext {
    pub(super) root_dir: PathBuf,
    /// rustc working directory and base for resolving relative paths.
    pub(super) execroot_dir: PathBuf,
    pub(super) outputs_dir: PathBuf,
}

#[derive(Default)]
pub(super) struct OutputMaterializationStats {
    pub(super) files: usize,
    pub(super) hardlinked_files: usize,
    pub(super) copied_files: usize,
}

/// Error returned when pipeline outputs cannot be materialized.
#[derive(Debug)]
pub(super) struct MaterializeError {
    pub(super) path: PathBuf,
    pub(super) cause: std::io::Error,
}

impl fmt::Display for MaterializeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "failed to materialize '{}': {}",
            self.path.display(),
            self.cause
        )
    }
}

impl std::error::Error for MaterializeError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        Some(&self.cause)
    }
}

#[derive(Clone, Debug)]
pub(crate) struct WorkerStateRoots {
    pipeline_root: PathBuf,
}

impl WorkerStateRoots {
    /// Ensures `_pw_state/pipeline` exists in the worker execroot.
    pub(crate) fn ensure() -> Result<Self, ProcessWrapperError> {
        let pipeline_root = PathBuf::from("_pw_state/pipeline");
        std::fs::create_dir_all(&pipeline_root).map_err(|e| {
            ProcessWrapperError(format!("failed to create worker pipeline root: {e}"))
        })?;
        Ok(Self { pipeline_root })
    }

    pub(crate) fn pipeline_dir(&self, key: &PipelineKey) -> PathBuf {
        self.pipeline_root.join(key.as_str())
    }
}

/// Creates the directories and working paths for one pipelined request.
pub(super) fn create_pipeline_context(
    state_roots: &WorkerStateRoots,
    key: &PipelineKey,
    request: &WorkRequest,
) -> Result<PipelineContext, (i32, String)> {
    let root_dir = state_roots.pipeline_dir(key);

    let outputs_dir = root_dir.join(format!("outputs-{}", request.request_id));
    if let Err(e) = std::fs::remove_dir_all(&outputs_dir) {
        if e.kind() != std::io::ErrorKind::NotFound {
            return Err(pipelining_err(format_args!(
                "failed to clear pipeline outputs dir: {e}"
            )));
        }
    }
    std::fs::create_dir_all(&outputs_dir)
        .map_err(|e| pipelining_err(format_args!("failed to create pipeline outputs dir: {e}")))?;
    let root_dir = std::fs::canonicalize(root_dir)
        .map_err(|e| pipelining_err(format_args!("failed to resolve pipeline dir: {e}")))?;
    let outputs_dir = std::fs::canonicalize(outputs_dir)
        .map_err(|e| pipelining_err(format_args!("failed to resolve pipeline outputs dir: {e}")))?;

    let execroot_dir = request
        .base_dir_canonicalized()
        .map_err(|e| pipelining_err(format_args!("{e}")))?;

    Ok(PipelineContext {
        root_dir,
        execroot_dir,
        outputs_dir,
    })
}

/// Copies `.rmeta` into `<out_dir>/_pipeline` for unsandboxed requests.
pub(super) fn copy_rmeta_unsandboxed(
    rmeta_src: &std::path::Path,
    original_out_dir: &str,
    root_dir: &std::path::Path,
) -> Option<String> {
    let filename = rmeta_src.file_name()?;
    let dest_pipeline = std::path::Path::new(original_out_dir).join("_pipeline");
    if let Err(e) = std::fs::create_dir_all(&dest_pipeline) {
        append_pipeline_log(root_dir, &format!("failed to create _pipeline dir: {e}"));
        return Some(format!("pipelining: failed to create _pipeline dir: {e}"));
    }
    let dest = dest_pipeline.join(filename);
    if !is_same_file(rmeta_src, &dest) {
        if let Err(e) = std::fs::copy(rmeta_src, &dest) {
            return Some(format!("pipelining: failed to copy rmeta: {e}"));
        }
    }
    None
}

/// Copies all regular files from `src_dir` to `dest_dir`.
pub(super) fn copy_outputs_unsandboxed(
    src_dir: &std::path::Path,
    dest_dir: &std::path::Path,
) -> Result<(), String> {
    std::fs::create_dir_all(dest_dir)
        .map_err(|e| format!("pipelining: failed to create output dir: {e}"))?;
    let entries = std::fs::read_dir(src_dir)
        .map_err(|e| format!("pipelining: failed to read pipeline dir: {e}"))?;
    for entry in entries {
        let entry = entry.map_err(|e| format!("pipelining: dir entry error: {e}"))?;
        let meta = entry.metadata().map_err(|e| {
            format!(
                "pipelining: metadata error for {}: {e}",
                entry.path().display()
            )
        })?;
        if meta.is_file() {
            let dest = dest_dir.join(entry.file_name());
            if !is_same_file(&entry.path(), &dest) {
                std::fs::copy(entry.path(), &dest).map_err(|e| {
                    format!(
                        "pipelining: failed to copy {} to {}: {e}",
                        entry.path().display(),
                        dest.display(),
                    )
                })?;
            }
        }
    }
    Ok(())
}

pub(super) fn maybe_cleanup_pipeline_dir(
    pipeline_root: &std::path::Path,
    keep: bool,
    reason: &str,
) {
    if keep {
        append_pipeline_log(
            pipeline_root,
            &format!("preserving pipeline dir for inspection: {reason}"),
        );
        return;
    }

    if let Err(err) = std::fs::remove_dir_all(pipeline_root) {
        append_pipeline_log(
            pipeline_root,
            &format!("failed to remove pipeline dir during cleanup: {err}"),
        );
    }
}
