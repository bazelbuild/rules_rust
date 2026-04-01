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

//! Pipelining state and handlers for the persistent worker.
//!
//! See `DESIGN.md` in this directory for the protocol and sandbox rationale.

use std::fmt;
use std::io::Write;
use std::path::PathBuf;

use crate::options::{parse_pw_args, SubprocessPipeliningMode};
use crate::ProcessWrapperError;

use super::args::{expand_rustc_args_with_metadata, scan_pipelining_flags};
use super::exec::is_same_file;
use super::protocol::ParsedWorkRequest;
use super::types::PipelineKey;

pub(super) fn pipelining_err(msg: impl std::fmt::Display) -> (i32, String) {
    (1, format!("pipelining: {msg}"))
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) enum RequestKind {
    /// No pipelining flags present — handle as a normal subprocess request.
    NonPipelined,
    /// `--pipelining-metadata --pipelining-key=<key>` present.
    /// Start a full rustc, return as soon as `.rmeta` is ready, cache the Child.
    Metadata { key: PipelineKey },
    /// `--pipelining-full --pipelining-key=<key>` present.
    /// Retrieve the cached Child from PipelineState and wait for it to finish.
    Full { key: PipelineKey },
}

impl RequestKind {
    #[cfg(test)]
    pub(crate) fn parse(args: &[String]) -> Self {
        let base_dir = std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."));
        Self::parse_in_dir(args, &base_dir)
    }

    pub(crate) fn parse_in_dir(args: &[String], base_dir: &std::path::Path) -> Self {
        let direct = scan_pipelining_flags(args.iter().map(String::as_str));
        if !matches!(direct, RequestKind::NonPipelined) {
            return direct;
        }

        // Direct args had no pipelining flags — check inside @paramfiles.
        let sep_pos = args.iter().position(|a| a == "--");
        let rustc_args = match sep_pos {
            Some(pos) => &args[pos + 1..],
            None => &[][..],
        };
        let parsed_pw_args =
            parse_pw_args(sep_pos.map(|pos| &args[..pos]).unwrap_or(&[]), base_dir);
        let nested = expand_rustc_args_with_metadata(
            rustc_args,
            &parsed_pw_args.subst,
            parsed_pw_args.require_explicit_unstable_features,
            base_dir,
        )
        .ok()
        .map(|(_, metadata)| metadata)
        .unwrap_or_default();

        let is_metadata =
            nested.relocated.pipelining_mode == Some(SubprocessPipeliningMode::Metadata);
        let is_full =
            nested.relocated.pipelining_mode == Some(SubprocessPipeliningMode::Full);
        let key = nested.pipelining_key;

        match (is_metadata, is_full, key) {
            (true, _, Some(k)) => RequestKind::Metadata {
                key: PipelineKey(k),
            },
            (_, true, Some(k)) => RequestKind::Full {
                key: PipelineKey(k),
            },
            _ => RequestKind::NonPipelined,
        }
    }

    /// Returns the pipeline key if this is a pipelined request.
    pub(crate) fn key(&self) -> Option<&PipelineKey> {
        match self {
            RequestKind::Metadata { key } | RequestKind::Full { key } => Some(key),
            RequestKind::NonPipelined => None,
        }
    }
}

/// Pipeline context for worker-managed pipelining.
///
/// Two modes:
/// - **Unsandboxed**: uses the real execroot as rustc's CWD.
/// - **Sandboxed**: uses the Bazel-provided `sandbox_dir` as CWD, keeping all
///   reads rooted in the sandbox per the multiplex sandbox contract.
pub(super) struct PipelineContext {
    pub(super) root_dir: PathBuf,
    /// Directory used as rustc's CWD and for resolving relative paths.
    /// Sandboxed: absolute `sandbox_dir`. Unsandboxed: canonicalized real execroot.
    pub(super) execroot_dir: PathBuf,
    pub(super) outputs_dir: PathBuf,
}

#[derive(Default)]
pub(super) struct OutputMaterializationStats {
    pub(super) files: usize,
    pub(super) hardlinked_files: usize,
    pub(super) copied_files: usize,
}

/// Error type for failures when copying artifacts from the pipeline
/// directory to the declared Bazel output location.
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
    /// Create the `_pw_state/pipeline/` directory tree in the worker's CWD
    /// (the Bazel execroot). This directory persists across builds for the
    /// lifetime of the worker process. Individual pipeline subdirectories are
    /// cleaned up by `maybe_cleanup_pipeline_dir` after each compilation.
    /// The root `_pw_state/` directory itself is left to Bazel-managed
    /// execroot cleanup (for example `bazel clean --expunge` or output-base
    /// deletion).
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

#[cfg(test)]
pub(crate) fn detect_pipelining_mode(args: &[String]) -> RequestKind {
    RequestKind::parse(args)
}

/// Creates a pipeline context for worker-managed pipelining.
///
/// When sandboxed, uses sandbox_dir as rustc's CWD so all reads go through the
/// sandbox (Bazel multiplex sandbox contract compliance). When unsandboxed, uses
/// the real execroot. In both cases, outputs are redirected to a persistent
/// worker-owned directory to prevent inter-request interference.
pub(super) fn create_pipeline_context(
    state_roots: &WorkerStateRoots,
    key: &PipelineKey,
    request: &ParsedWorkRequest,
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
    let outputs_dir = std::fs::canonicalize(outputs_dir).map_err(|e| {
        pipelining_err(format_args!("failed to resolve pipeline outputs dir: {e}"))
    })?;

    let execroot_dir = request
        .base_dir_canonicalized()
        .map_err(|e| pipelining_err(format_args!("{e}")))?;

    Ok(PipelineContext {
        root_dir,
        execroot_dir,
        outputs_dir,
    })
}

/// Copies a single .rmeta file to the `_pipeline/` subdirectory of out_dir (unsandboxed).
///
/// Skips same-file copies (when src and dest resolve to the same inode).
/// Returns `Some(error_message)` on failure, `None` on success.
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

/// Copies all regular files from `src_dir` to `dest_dir` (unsandboxed path).
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

pub(super) fn append_pipeline_log(pipeline_root: &std::path::Path, message: &str) {
    let path = pipeline_root.join("pipeline.log");
    let mut file = match std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(path)
    {
        Ok(file) => file,
        Err(_) => return,
    };
    let _ = writeln!(file, "{message}");
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
