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

use std::collections::HashMap;
use std::io::Write;
use std::path::PathBuf;

use crate::options::{
    build_child_environment, expand_args_inline, is_pipelining_flag, is_relocated_pw_flag,
    parse_pw_args as parse_shared_pw_args, NormalizedRustcMetadata, OptionError, ParsedPwArgs,
    RelocatedPwFlags, SubprocessPipeliningMode,
};
use crate::ProcessWrapperError;

use super::protocol::ParsedWorkRequest;
use super::sandbox::{
    make_dir_files_writable, make_path_writable, resolve_request_relative_path,
};
use super::types::{OutputDir, PipelineKey};

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
        let (direct_metadata, direct_full, direct_key) =
            scan_pipelining_flags(args.iter().map(String::as_str));
        let sep_pos = args.iter().position(|a| a == "--");
        let rustc_args = match sep_pos {
            Some(pos) => &args[pos + 1..],
            None => &[][..],
        };
        let parsed_pw_args =
            parse_shared_pw_args(sep_pos.map(|pos| &args[..pos]).unwrap_or(&[]), base_dir);
        let nested = expand_rustc_args_with_metadata(
            rustc_args,
            &parsed_pw_args.subst,
            parsed_pw_args.require_explicit_unstable_features,
            base_dir,
        )
        .ok()
        .map(|(_, metadata)| metadata)
        .unwrap_or_default();
        let is_metadata = direct_metadata
            || nested.relocated.pipelining_mode == Some(SubprocessPipeliningMode::Metadata);
        let is_full =
            direct_full || nested.relocated.pipelining_mode == Some(SubprocessPipeliningMode::Full);
        let key = direct_key.or(nested.pipelining_key);

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

#[derive(Clone, Debug)]
pub(crate) struct WorkerStateRoots {
    pipeline_root: PathBuf,
}

impl WorkerStateRoots {
    /// Create the `_pw_state/pipeline/` directory tree in the worker's CWD
    /// (the Bazel execroot). This directory persists across builds for the
    /// lifetime of the worker process. Individual pipeline subdirectories are
    /// cleaned up by `maybe_cleanup_pipeline_dir` after each compilation.
    /// The root `_pw_state/` directory itself is removed by `bazel clean`.
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

/// Scans an iterator of argument strings for pipelining flags.
/// Returns `(is_metadata, is_full, pipeline_key)`.
pub(super) fn scan_pipelining_flags<'a>(
    iter: impl Iterator<Item = &'a str>,
) -> (bool, bool, Option<String>) {
    let mut is_metadata = false;
    let mut is_full = false;
    let mut key: Option<String> = None;
    for arg in iter {
        if arg == "--pipelining-metadata" {
            is_metadata = true;
        } else if arg == "--pipelining-full" {
            is_full = true;
        } else if let Some(k) = arg.strip_prefix("--pipelining-key=") {
            key = Some(k.to_string());
        }
    }
    (is_metadata, is_full, key)
}

/// Strips pipelining protocol flags from a direct arg list.
///
/// Used for the full-action fallback path (where pipelining flags may appear
/// in direct args if no @paramfile was used). When flags are in a @paramfile,
/// `options.rs` `prepare_param_file` handles stripping during expansion.
pub(super) fn strip_pipelining_flags(args: &[String]) -> Vec<String> {
    args.iter()
        .filter(|a| !is_pipelining_flag(a))
        .cloned()
        .collect()
}

/// Move process_wrapper flags that appear after `--` to before it.
///
/// When worker pipelining is active, per-action flags like `--output-file`
/// are placed in the @paramfile (so all actions share the same WorkerKey).
/// After the worker concatenates startup_args + request.arguments, these
/// flags end up after the `--` separator.  Both the subprocess path
/// (`options.rs`) and the pipelining path (`parse_pw_args`) expect them
/// before `--`, so we relocate them here.
pub(super) fn relocate_pw_flags(args: &mut Vec<String>) {
    let sep_pos = match args.iter().position(|a| a == "--") {
        Some(pos) => pos,
        None => return,
    };

    // Collect indices of relocated pw flags (and their values) after --.
    let mut to_relocate: Vec<String> = Vec::new();
    let mut remove_indices: Vec<usize> = Vec::new();
    let mut i = sep_pos + 1;
    while i < args.len() {
        if is_relocated_pw_flag(&args[i]) {
            remove_indices.push(i);
            to_relocate.push(args[i].clone());
            if i + 1 < args.len() {
                remove_indices.push(i + 1);
                to_relocate.push(args[i + 1].clone());
                i += 2;
            } else {
                i += 1;
            }
        } else {
            i += 1;
        }
    }

    if to_relocate.is_empty() {
        return;
    }

    // Remove from after -- in reverse order to preserve indices.
    for &idx in remove_indices.iter().rev() {
        args.remove(idx);
    }

    // Insert before -- (which may have shifted after removals).
    let sep_pos = args.iter().position(|a| a == "--").unwrap_or(0);
    for (offset, flag) in to_relocate.into_iter().enumerate() {
        args.insert(sep_pos + offset, flag);
    }
}

/// Parses process_wrapper flags from the pre-`--` portion of args.
pub(super) fn parse_pw_args(pw_args: &[String], pwd: &std::path::Path) -> ParsedPwArgs {
    parse_shared_pw_args(pw_args, pwd)
}

fn read_args_file_in_dir(
    path: &str,
    base_dir: &std::path::Path,
) -> Result<Vec<String>, OptionError> {
    let resolved = resolve_request_relative_path(path, Some(base_dir));
    let resolved = resolved.display().to_string();
    crate::util::read_file_to_array(&resolved).map_err(OptionError::Generic)
}

fn expand_rustc_args_with_metadata(
    rustc_and_after: &[String],
    subst: &[(String, String)],
    require_explicit_unstable_features: bool,
    execroot_dir: &std::path::Path,
) -> Result<(Vec<String>, NormalizedRustcMetadata), OptionError> {
    let mut read_file = |path: &str| read_args_file_in_dir(path, execroot_dir);
    expand_args_inline(
        rustc_and_after,
        subst,
        require_explicit_unstable_features,
        Some(&mut read_file),
        true,
    )
}

/// Builds the environment map: inherit current process + env files + apply substitutions.
///
/// Returns `Err` if any env-file or stamp-file cannot be read, aligning with
/// the standalone path's error behavior (Finding 5 fix).
pub(super) fn build_rustc_env(
    env_files: &[String],
    stable_status_file: Option<&str>,
    volatile_status_file: Option<&str>,
    subst: &[(String, String)],
) -> Result<HashMap<String, String>, String> {
    build_child_environment(env_files, stable_status_file, volatile_status_file, subst)
}

/// Prepares rustc arguments: expand @paramfiles, apply substitutions, strip
/// pipelining flags, and append args from --arg-file files.
///
/// Returns `(rustc_args, original_out_dir, relocated_pw_flags)` on success.
pub(super) fn prepare_rustc_args(
    rustc_and_after: &[String],
    pw_args: &ParsedPwArgs,
    execroot_dir: &std::path::Path,
) -> Result<(Vec<String>, OutputDir, RelocatedPwFlags), (i32, String)> {
    let (mut rustc_args, metadata) = expand_rustc_args_with_metadata(
        rustc_and_after,
        &pw_args.subst,
        pw_args.require_explicit_unstable_features,
        execroot_dir,
    )
    .map_err(|e| (1, format!("pipelining: {e}")))?;
    if rustc_args.is_empty() {
        return Err((
            1,
            "pipelining: no rustc arguments after expansion".to_string(),
        ));
    }

    // Append args from --arg-file files (e.g. build script output: --cfg=..., -L ...).
    let mut arg_files = pw_args.arg_files.clone();
    arg_files.extend(metadata.relocated.arg_files.iter().cloned());
    for path in arg_files {
        let resolved = resolve_request_relative_path(&path, Some(execroot_dir));
        let resolved = resolved.display().to_string();
        let lines = crate::util::read_file_to_array(&resolved)
            .map_err(|e| (1, format!("failed to read arg-file '{}': {}", resolved, e)))?;
        for line in lines {
            rustc_args.push(apply_substs(&line, &pw_args.subst));
        }
    }

    let original_out_dir = OutputDir(find_out_dir_in_expanded(&rustc_args).unwrap_or_default());

    Ok((rustc_args, original_out_dir, metadata.relocated))
}

pub(super) fn resolve_pw_args_for_request(
    mut pw_args: ParsedPwArgs,
    request: &ParsedWorkRequest,
    execroot_dir: &std::path::Path,
) -> ParsedPwArgs {
    pw_args.env_files = pw_args
        .env_files
        .into_iter()
        .map(|path| {
            resolve_request_relative_path(&path, Some(execroot_dir))
                .display()
                .to_string()
        })
        .collect();
    pw_args.arg_files = pw_args
        .arg_files
        .into_iter()
        .map(|path| {
            resolve_request_relative_path(&path, Some(execroot_dir))
                .display()
                .to_string()
        })
        .collect();
    pw_args.stable_status_file = pw_args.stable_status_file.map(|path| {
        resolve_request_relative_path(&path, Some(execroot_dir))
            .display()
            .to_string()
    });
    pw_args.volatile_status_file = pw_args.volatile_status_file.map(|path| {
        resolve_request_relative_path(&path, Some(execroot_dir))
            .display()
            .to_string()
    });
    pw_args.output_file = pw_args.output_file.map(|path| {
        let base = request
            .sandbox_dir
            .as_ref()
            .map(|sd| sd.as_path())
            .unwrap_or(execroot_dir);
        resolve_request_relative_path(&path, Some(base))
            .display()
            .to_string()
    });
    pw_args
}

/// Applies `${key}` → `value` substitution mappings to a single argument string.
///
/// Delegates to [`crate::util::apply_substitutions`], which couples substitution
/// with Windows verbatim path normalization so callers cannot forget it.
pub(super) fn apply_substs(arg: &str, subst: &[(String, String)]) -> String {
    let mut a = arg.to_owned();
    crate::util::apply_substitutions(&mut a, subst);
    a
}

/// Builds the rustc argument list from the post-`--` section of process_wrapper
/// args, expanding any @paramfile references inline and stripping pipelining flags.
///
/// Rustc natively supports @paramfile expansion, but the paramfile may contain
/// pipelining protocol flags (`--pipelining-metadata`, `--pipelining-key=*`) that
/// rustc doesn't understand. By expanding and filtering here we avoid passing
/// unknown flags to rustc.
#[cfg(test)]
pub(super) fn expand_rustc_args(
    rustc_and_after: &[String],
    subst: &[(String, String)],
    execroot_dir: &std::path::Path,
) -> Vec<String> {
    expand_rustc_args_with_metadata(rustc_and_after, subst, false, execroot_dir)
        .map(|(args, _)| args)
        .unwrap_or_else(|_| {
            rustc_and_after
                .iter()
                .map(|arg| apply_substs(arg, subst))
                .collect()
        })
}

/// Searches already-expanded rustc args for `--out-dir=<path>`.
pub(super) fn find_out_dir_in_expanded(args: &[String]) -> Option<String> {
    args.iter()
        .find_map(|arg| arg.strip_prefix("--out-dir=").map(|d| d.to_string()))
}

/// Returns a copy of `args` where `--out-dir=<old>` is replaced by
/// `--out-dir=<new_out_dir>`. Other args are unchanged.
pub(super) fn rewrite_out_dir_in_expanded(
    args: Vec<String>,
    new_out_dir: &std::path::Path,
) -> Vec<String> {
    args.into_iter()
        .map(|arg| {
            if arg.starts_with("--out-dir=") {
                format!("--out-dir={}", new_out_dir.display())
            } else {
                arg
            }
        })
        .collect()
}

/// Rewrites `--emit=metadata=<path>` to write the .rmeta into the pipeline outputs dir.
/// The original relative path's filename is preserved; only the directory changes.
pub(super) fn rewrite_emit_metadata_path(
    args: Vec<String>,
    outputs_dir: &std::path::Path,
) -> Vec<String> {
    args.into_iter()
        .map(|arg| {
            if let Some(path_str) = arg.strip_prefix("--emit=metadata=") {
                let filename = std::path::Path::new(path_str)
                    .file_name()
                    .unwrap_or_default()
                    .to_string_lossy();
                format!(
                    "--emit=metadata={}",
                    outputs_dir.join(filename.as_ref()).display()
                )
            } else {
                arg
            }
        })
        .collect()
}

pub(super) fn prepare_expanded_rustc_outputs(args: &[String]) {
    for arg in args {
        if let Some(dir) = arg.strip_prefix("--out-dir=") {
            make_dir_files_writable(dir);
            let pipeline_dir = format!("{dir}/_pipeline");
            make_dir_files_writable(&pipeline_dir);
            continue;
        }

        let Some(emit) = arg.strip_prefix("--emit=") else {
            continue;
        };
        for part in emit.split(',') {
            let Some((_, path)) = part.split_once('=') else {
                continue;
            };
            make_path_writable(std::path::Path::new(path));
        }
    }
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
            return Err((
                1,
                format!("pipelining: failed to clear pipeline outputs dir: {e}"),
            ));
        }
    }
    std::fs::create_dir_all(&outputs_dir).map_err(|e| {
        (
            1,
            format!("pipelining: failed to create pipeline outputs dir: {e}"),
        )
    })?;
    let root_dir = std::fs::canonicalize(root_dir).map_err(|e| {
        (
            1,
            format!("pipelining: failed to resolve pipeline dir: {e}"),
        )
    })?;
    let outputs_dir = std::fs::canonicalize(outputs_dir).map_err(|e| {
        (
            1,
            format!("pipelining: failed to resolve pipeline outputs dir: {e}"),
        )
    })?;

    let execroot_dir = if let Some(ref sandbox_dir) = request.sandbox_dir {
        let sandbox_path = sandbox_dir.as_path();
        if sandbox_path.is_absolute() {
            sandbox_path.to_path_buf()
        } else {
            let cwd = std::env::current_dir()
                .map_err(|e| (1, format!("pipelining: failed to get worker CWD: {e}")))?;
            cwd.join(sandbox_path)
        }
    } else {
        let cwd = std::env::current_dir()
            .map_err(|e| (1, format!("pipelining: failed to get worker CWD: {e}")))?;
        std::fs::canonicalize(cwd).map_err(|e| {
            (
                1,
                format!("pipelining: failed to canonicalize worker CWD: {e}"),
            )
        })?
    };

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
    if !super::sandbox::is_same_file(rmeta_src, &dest) {
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
            if !super::sandbox::is_same_file(&entry.path(), &dest) {
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
