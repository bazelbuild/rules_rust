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
use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;

use tinyjson::JsonValue;

use crate::options::{
    build_child_environment, expand_args_inline, is_pipelining_flag, is_relocated_pw_flag,
    parse_pw_args as parse_shared_pw_args, NormalizedRustcMetadata, OptionError, ParsedPwArgs,
    RelocatedPwFlags, SubprocessPipeliningMode,
};
use crate::rustc::RustcStderrPolicy;
use crate::ProcessWrapperError;

use super::protocol::WorkRequestContext;
use super::sandbox::{
    copy_all_outputs_to_sandbox, copy_output_to_sandbox, make_dir_files_writable,
    make_path_writable, prepare_outputs, resolve_request_relative_path, run_request,
    run_sandboxed_request,
};
use super::types::{OutputDir, PipelineKey, RequestId};
use super::{append_worker_lifecycle_log, current_pid, lock_or_recover};

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

pub(super) enum PipelinePhase {
    PreRegistered {
        metadata_request_id: RequestId,
    },
    MetadataRunning {
        metadata_request_id: RequestId,
        bg: BackgroundRustc,
        pid: u32,
    },
    FullWaiting {
        #[allow(dead_code)]
        full_request_id: RequestId,
        pid: u32,
        child_reaped: Arc<AtomicBool>,
    },
    FallbackRunning {
        full_request_id: RequestId,
    },
}

pub(super) enum CancelledEntry {
    NotFound,
    NoChild,
    OwnedChild(BackgroundRustc),
    PidOnly(u32, Arc<AtomicBool>),
}

pub(super) enum StoreBackgroundResult {
    Stored,
    Replaced(BackgroundRustc),
    Rejected(BackgroundRustc),
}

pub(super) enum FullRequestAction {
    Background(BackgroundRustc, Arc<AtomicBool>),
    Fallback,
    Busy,
}

impl CancelledEntry {
    /// Perform blocking cleanup. Safe to call without any lock held.
    pub(super) fn kill(self) -> bool {
        match self {
            CancelledEntry::NotFound | CancelledEntry::NoChild => false,
            CancelledEntry::OwnedChild(mut bg) => {
                let _ = bg.child.kill();
                let _ = bg.child.wait();
                let _ = bg.stderr_drain.join();
                true
            }
            CancelledEntry::PidOnly(pid, child_reaped) => {
                // Only send SIGKILL if the full handler hasn't already reaped
                // the child. Without this check, we could kill a recycled PID.
                if !child_reaped.load(Ordering::SeqCst) {
                    #[cfg(unix)]
                    unsafe {
                        kill(pid as i32, 9);
                    }
                    let _ = pid; // suppress unused warning on non-unix
                }
                true
            }
        }
    }
}

/// A background rustc process started by a RustcMetadata action.
///
/// After the `.rmeta` artifact notification, the handler stores the Child
/// here and spawns a background thread to drain the remaining stderr output.
/// The full compile handler retrieves this, joins the drain thread, and waits
/// for the child to exit.
pub(super) struct BackgroundRustc {
    pub(super) child: std::process::Child,
    /// Diagnostics captured from rustc stderr before the metadata signal.
    pub(super) diagnostics_before: String,
    /// Background thread draining rustc's remaining stderr output after the
    /// metadata signal. Must be joined before waiting on `child` to avoid
    /// deadlock (child blocks on stderr write if the pipe buffer fills up).
    /// Returns the diagnostics captured after the metadata signal.
    pub(super) stderr_drain: thread::JoinHandle<String>,
    /// Worker-managed persistent root for this pipelined compile.
    pub(super) pipeline_root_dir: PathBuf,
    /// Worker-managed persistent output directory used by the background rustc.
    pub(super) pipeline_output_dir: PathBuf,
    /// Original `--out-dir` value (before rewriting to `pipeline_output_dir`).
    /// Used by the full handler to copy outputs from the persistent dir to the
    /// correct sandbox-relative location.
    pub(super) original_out_dir: OutputDir,
}

/// In-process store of background rustc processes for worker-managed pipelining.
///
/// Keyed by the pipeline key (crate name + output hash), set by the Bazel-side
/// `--pipelining-key=<key>` argument. Each pipeline entry follows a lifecycle
/// tracked by [`PipelinePhase`]:
///
///   PreRegistered → MetadataRunning → FullWaiting → (removed)
///
/// `claim_flags` also tracks non-pipelined in-flight requests, unifying the
/// cancel/completion race prevention into a single data structure.
pub(crate) struct PipelineState {
    /// Pipeline key → current phase.
    entries: HashMap<PipelineKey, PipelinePhase>,
    /// Reverse index: request_id → pipeline key (for O(1) cancel lookup).
    request_index: HashMap<RequestId, PipelineKey>,
    /// Claim flags for ALL in-flight requests (pipelined + non-pipelined).
    /// Whoever atomically swaps the flag first sends the WorkResponse.
    claim_flags: HashMap<RequestId, Arc<AtomicBool>>,
}

impl PipelineState {
    pub(crate) fn new() -> Self {
        Self {
            entries: HashMap::new(),
            request_index: HashMap::new(),
            claim_flags: HashMap::new(),
        }
    }

    pub(crate) fn register_non_pipelined(&mut self, request_id: RequestId) -> Arc<AtomicBool> {
        let flag = Arc::new(AtomicBool::new(false));
        self.claim_flags.insert(request_id, Arc::clone(&flag));
        flag
    }

    pub(crate) fn register_metadata(
        &mut self,
        request_id: RequestId,
        key: PipelineKey,
    ) -> Arc<AtomicBool> {
        let flag = Arc::new(AtomicBool::new(false));
        self.claim_flags.insert(request_id, Arc::clone(&flag));
        self.request_index.insert(request_id, key.clone());
        self.entries
            .entry(key)
            .or_insert(PipelinePhase::PreRegistered {
                metadata_request_id: request_id,
            });
        flag
    }

    pub(crate) fn register_full(
        &mut self,
        request_id: RequestId,
        key: PipelineKey,
    ) -> Arc<AtomicBool> {
        let flag = Arc::new(AtomicBool::new(false));
        self.claim_flags.insert(request_id, Arc::clone(&flag));
        self.request_index.insert(request_id, key);
        flag
    }

    pub(super) fn store_metadata(
        &mut self,
        key: &PipelineKey,
        request_id: RequestId,
        bg: BackgroundRustc,
    ) -> StoreBackgroundResult {
        let pid = bg.child.id();
        if let Some(entry) = self.entries.get_mut(key) {
            match entry {
                PipelinePhase::PreRegistered {
                    metadata_request_id,
                } => {
                    let old_req = *metadata_request_id;
                    *entry = PipelinePhase::MetadataRunning {
                        metadata_request_id: request_id,
                        bg,
                        pid,
                    };
                    if old_req != request_id {
                        self.request_index.remove(&old_req);
                    }
                    return StoreBackgroundResult::Stored;
                }
                PipelinePhase::MetadataRunning {
                    metadata_request_id,
                    ..
                } => {
                    let old_req = *metadata_request_id;
                    let old = std::mem::replace(
                        entry,
                        PipelinePhase::MetadataRunning {
                            metadata_request_id: request_id,
                            bg,
                            pid,
                        },
                    );
                    if old_req != request_id {
                        self.request_index.remove(&old_req);
                    }
                    if let PipelinePhase::MetadataRunning { bg: old_bg, .. } = old {
                        return StoreBackgroundResult::Replaced(old_bg);
                    }
                    unreachable!();
                }
                PipelinePhase::FullWaiting { .. } | PipelinePhase::FallbackRunning { .. } => {}
            }
        }
        StoreBackgroundResult::Rejected(bg)
    }

    pub(super) fn claim_for_full(
        &mut self,
        key: &PipelineKey,
        full_request_id: RequestId,
    ) -> FullRequestAction {
        if let Some(entry) = self.entries.get_mut(key) {
            match entry {
                PipelinePhase::MetadataRunning {
                    metadata_request_id,
                    pid,
                    ..
                } => {
                    let old_req = *metadata_request_id;
                    let pid_val = *pid;
                    let child_reaped = Arc::new(AtomicBool::new(false));
                    let old = std::mem::replace(
                        entry,
                        PipelinePhase::FullWaiting {
                            full_request_id,
                            pid: pid_val,
                            child_reaped: Arc::clone(&child_reaped),
                        },
                    );
                    self.request_index.remove(&old_req);
                    if let PipelinePhase::MetadataRunning { bg, .. } = old {
                        FullRequestAction::Background(bg, child_reaped)
                    } else {
                        unreachable!()
                    }
                }
                PipelinePhase::PreRegistered {
                    metadata_request_id,
                } => {
                    self.request_index.remove(metadata_request_id);
                    *entry = PipelinePhase::FallbackRunning { full_request_id };
                    FullRequestAction::Fallback
                }
                PipelinePhase::FullWaiting { .. } | PipelinePhase::FallbackRunning { .. } => {
                    FullRequestAction::Busy
                }
            }
        } else {
            self.entries.insert(
                key.clone(),
                PipelinePhase::FallbackRunning { full_request_id },
            );
            FullRequestAction::Fallback
        }
    }

    pub(super) fn cleanup(&mut self, key: &PipelineKey, request_id: RequestId) {
        self.entries.remove(key);
        self.request_index.remove(&request_id);
        self.claim_flags.remove(&request_id);
    }

    pub(super) fn cleanup_key_fully(&mut self, key: &PipelineKey) -> Option<BackgroundRustc> {
        let bg = match self.entries.remove(key) {
            Some(PipelinePhase::MetadataRunning { bg, .. }) => Some(bg),
            _ => None,
        };
        self.remove_key_mappings(key, None);
        bg
    }

    pub(super) fn discard_request(&mut self, request_id: RequestId) {
        self.request_index.remove(&request_id);
        self.claim_flags.remove(&request_id);
    }

    pub(super) fn remove_claim(&mut self, request_id: RequestId) {
        self.claim_flags.remove(&request_id);
    }

    pub(super) fn get_claim_flag(&self, request_id: RequestId) -> Option<Arc<AtomicBool>> {
        self.claim_flags.get(&request_id).cloned()
    }

    pub(super) fn cancel_by_request_id(&mut self, request_id: RequestId) -> CancelledEntry {
        let key = match self.request_index.get(&request_id).cloned() {
            Some(k) => k,
            None => return CancelledEntry::NotFound,
        };

        enum CancelAction {
            NoChild,
            RemovePreregistered,
            RemoveMetadataRunning { remove_all_mappings: bool },
            RemoveFullWaiting,
            RemoveFallback,
        }

        let action = match self.entries.get(&key) {
            None => CancelAction::NoChild,
            Some(PipelinePhase::PreRegistered {
                metadata_request_id,
            }) => {
                if *metadata_request_id == request_id {
                    CancelAction::RemovePreregistered
                } else {
                    CancelAction::NoChild
                }
            }
            Some(PipelinePhase::MetadataRunning {
                metadata_request_id,
                ..
            }) => CancelAction::RemoveMetadataRunning {
                remove_all_mappings: *metadata_request_id != request_id,
            },
            Some(PipelinePhase::FullWaiting {
                full_request_id, ..
            }) => {
                if *full_request_id == request_id {
                    CancelAction::RemoveFullWaiting
                } else {
                    CancelAction::NoChild
                }
            }
            Some(PipelinePhase::FallbackRunning { full_request_id }) => {
                if *full_request_id == request_id {
                    CancelAction::RemoveFallback
                } else {
                    CancelAction::NoChild
                }
            }
        };

        let cancelled = match action {
            CancelAction::NoChild => CancelledEntry::NoChild,
            CancelAction::RemovePreregistered => {
                self.entries.remove(&key);
                CancelledEntry::NoChild
            }
            CancelAction::RemoveMetadataRunning {
                remove_all_mappings,
            } => {
                let remove_entry = self.entries.remove(&key);
                if remove_all_mappings {
                    self.remove_key_mappings(&key, None);
                }
                match remove_entry {
                    Some(PipelinePhase::MetadataRunning { bg, .. }) => {
                        CancelledEntry::OwnedChild(bg)
                    }
                    _ => CancelledEntry::NoChild,
                }
            }
            CancelAction::RemoveFullWaiting => {
                self.remove_key_mappings(&key, None);
                match self.entries.remove(&key) {
                    Some(PipelinePhase::FullWaiting {
                        pid, child_reaped, ..
                    }) => CancelledEntry::PidOnly(pid, child_reaped),
                    _ => CancelledEntry::NoChild,
                }
            }
            CancelAction::RemoveFallback => {
                self.entries.remove(&key);
                self.remove_key_mappings(&key, None);
                CancelledEntry::NoChild
            }
        };
        self.discard_request(request_id);
        cancelled
    }

    pub(super) fn drain_all(&mut self) -> Vec<CancelledEntry> {
        let mut result = Vec::new();
        for (_key, entry) in self.entries.drain() {
            match entry {
                PipelinePhase::PreRegistered { .. } => {}
                PipelinePhase::MetadataRunning { bg, .. } => {
                    result.push(CancelledEntry::OwnedChild(bg));
                }
                PipelinePhase::FullWaiting {
                    pid, child_reaped, ..
                } => {
                    result.push(CancelledEntry::PidOnly(pid, child_reaped));
                }
                PipelinePhase::FallbackRunning { .. } => {}
            }
        }
        self.request_index.clear();
        result
    }

    fn remove_key_mappings(&mut self, key: &PipelineKey, keep: Option<RequestId>) {
        let request_ids: Vec<_> = self
            .request_index
            .iter()
            .filter_map(|(request_id, indexed_key)| {
                if indexed_key == key && Some(*request_id) != keep {
                    Some(*request_id)
                } else {
                    None
                }
            })
            .collect();
        for request_id in request_ids {
            self.request_index.remove(&request_id);
            self.claim_flags.remove(&request_id);
        }
    }

    // --- Test accessors ---

    #[cfg(test)]
    pub(super) fn has_entry(&self, key: &str) -> bool {
        self.entries.contains_key(&PipelineKey(key.to_string()))
    }

    #[cfg(test)]
    pub(super) fn is_empty(&self) -> bool {
        self.entries.is_empty() && self.request_index.is_empty()
    }

    #[cfg(test)]
    pub(super) fn has_request(&self, id: i64) -> bool {
        self.request_index.contains_key(&RequestId(id))
    }

    #[cfg(test)]
    pub(super) fn has_claim(&self, id: i64) -> bool {
        self.claim_flags.contains_key(&RequestId(id))
    }
}

#[cfg(unix)]
extern "C" {
    fn kill(pid: i32, sig: i32) -> i32;
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

fn resolve_pw_args_for_request(
    mut pw_args: ParsedPwArgs,
    request: &WorkRequestContext,
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
#[cfg_attr(not(test), allow(dead_code))]
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
    for arg in args {
        if let Some(dir) = arg.strip_prefix("--out-dir=") {
            return Some(dir.to_string());
        }
    }
    None
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
    request: &WorkRequestContext,
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

// ---------------------------------------------------------------------------
// Pipelining handlers
// ---------------------------------------------------------------------------

pub(crate) fn handle_pipelining_metadata(
    request: &WorkRequestContext,
    args: Vec<String>,
    key: PipelineKey,
    state_roots: &WorkerStateRoots,
    pipeline_state: &Arc<Mutex<PipelineState>>,
) -> (i32, String) {
    let filtered = strip_pipelining_flags(&args);

    let sep = filtered.iter().position(|a| a == "--");
    let (pw_raw, rustc_and_after) = match sep {
        Some(pos) => (&filtered[..pos], &filtered[pos + 1..]),
        None => return (1, "pipelining: no '--' separator in args".to_string()),
    };
    if rustc_and_after.is_empty() {
        return (1, "pipelining: no rustc executable after '--'".to_string());
    }

    let ctx = match create_pipeline_context(state_roots, &key, request) {
        Ok(v) => v,
        Err(e) => return e,
    };

    let mut pw_args = parse_pw_args(pw_raw, &ctx.execroot_dir);
    let (rustc_args, original_out_dir, relocated) =
        match prepare_rustc_args(rustc_and_after, &pw_args, &ctx.execroot_dir) {
            Ok(v) => v,
            Err(e) => return e,
        };
    pw_args.merge_relocated(relocated);
    let pw_args = resolve_pw_args_for_request(pw_args, request, &ctx.execroot_dir);
    let env = match build_rustc_env(
        &pw_args.env_files,
        pw_args.stable_status_file.as_deref(),
        pw_args.volatile_status_file.as_deref(),
        &pw_args.subst,
    ) {
        Ok(env) => env,
        Err(e) => return (1, format!("pipelining: {e}")),
    };

    let rustc_args = rewrite_out_dir_in_expanded(rustc_args, &ctx.outputs_dir);
    let rustc_args = rewrite_emit_metadata_path(rustc_args, &ctx.outputs_dir);
    prepare_expanded_rustc_outputs(&rustc_args);
    append_pipeline_log(
        &ctx.root_dir,
        &format!(
            "metadata start request_id={} key={} sandbox_dir={:?} inputs={} original_out_dir={} execroot={} outputs={}",
            request.request_id,
            key,
            request.sandbox_dir,
            request.inputs.len(),
            original_out_dir,
            ctx.execroot_dir.display(),
            ctx.outputs_dir.display(),
        ),
    );
    // On Windows, rustc's internal search-path buffer is limited to ~32K characters.
    // Consolidate all -Ldependency dirs into one directory with hardlinks, then
    // write all args to a response file to also avoid CreateProcessW limits.
    #[cfg(windows)]
    let _consolidated_dir_guard: Option<PathBuf>;
    #[cfg(windows)]
    let mut rustc_args = rustc_args;
    #[cfg(windows)]
    {
        let unified_dir = ctx.root_dir.join("deps");
        let _ = std::fs::remove_dir_all(&unified_dir);
        if let Err(e) = std::fs::create_dir_all(&unified_dir) {
            return (1, format!("pipelining: failed to create deps dir: {e}"));
        }

        let dep_dirs: Vec<PathBuf> = rustc_args
            .iter()
            .filter_map(|a| a.strip_prefix("-Ldependency=").map(PathBuf::from))
            .collect();
        crate::util::consolidate_deps_into(&dep_dirs, &unified_dir);
        rustc_args.retain(|a| !a.starts_with("-Ldependency="));
        rustc_args.push(format!("-Ldependency={}", unified_dir.display()));
        _consolidated_dir_guard = Some(unified_dir);
    }

    let mut cmd = Command::new(&rustc_args[0]);
    #[cfg(windows)]
    {
        let response_file_path = ctx.root_dir.join("metadata_rustc.args");
        let content = rustc_args[1..].join("\n");
        if let Err(e) = std::fs::write(&response_file_path, &content) {
            return (1, format!("pipelining: failed to write response file: {e}"));
        }
        cmd.arg(format!("@{}", response_file_path.display()));
    }
    #[cfg(not(windows))]
    {
        cmd.args(&rustc_args[1..]);
    }
    cmd.env_clear()
        .envs(&env)
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .current_dir(&ctx.execroot_dir);
    let mut child = match cmd.spawn() {
        Ok(c) => c,
        Err(e) => return (1, format!("pipelining: failed to spawn rustc: {e}")),
    };

    let stderr = child.stderr.take().expect("stderr was piped");
    let mut reader = BufReader::new(stderr);
    let mut diagnostics = String::new();
    let mut diagnostics_policy =
        RustcStderrPolicy::from_option_str(pw_args.rustc_output_format.as_deref());

    loop {
        let mut line = String::new();
        match reader.read_line(&mut line) {
            Ok(0) => break,
            Err(_) => break,
            Ok(_) => {}
        }

        if let Some(output) = diagnostics_policy.process_line(&line) {
            diagnostics.push_str(&output);
        }

        let trimmed = line.trim_end_matches('\n').trim_end_matches('\r');

        if let Some(rmeta_path_str) = extract_rmeta_path(trimmed) {
            let rmeta_resolved =
                resolve_request_relative_path(&rmeta_path_str, Some(&ctx.execroot_dir));
            let rmeta_resolved_str = rmeta_resolved.display().to_string();
            append_pipeline_log(
                &ctx.root_dir,
                &format!("metadata rmeta ready: {}", rmeta_resolved_str),
            );
            let copy_err = match request.sandbox_dir.as_ref() {
                Some(dir) => copy_output_to_sandbox(
                    &rmeta_resolved_str,
                    dir.as_str(),
                    original_out_dir.as_str(),
                    "_pipeline",
                )
                .err()
                .map(|e| format!("pipelining: rmeta materialization failed: {e}")),
                None => copy_rmeta_unsandboxed(
                    &rmeta_resolved,
                    original_out_dir.as_str(),
                    &ctx.root_dir,
                ),
            };
            if let Some(err_msg) = copy_err {
                let _ = child.kill();
                let _ = child.wait();
                return (1, err_msg);
            }
            let mut drain_policy = diagnostics_policy;
            let drain = thread::spawn(move || {
                let mut remaining = String::new();
                let mut buf = String::new();
                while reader.read_line(&mut buf).unwrap_or(0) > 0 {
                    if let Some(output) = drain_policy.process_line(&buf) {
                        remaining.push_str(&output);
                    }
                    buf.clear();
                }
                remaining
            });

            let diagnostics_before = diagnostics.clone();
            let store_result = lock_or_recover(pipeline_state).store_metadata(
                &key,
                request.request_id,
                BackgroundRustc {
                    child,
                    diagnostics_before,
                    stderr_drain: drain,
                    pipeline_root_dir: ctx.root_dir.clone(),
                    pipeline_output_dir: ctx.outputs_dir.clone(),
                    original_out_dir,
                },
            );
            let orphan = match store_result {
                StoreBackgroundResult::Stored => None,
                StoreBackgroundResult::Replaced(bg) => Some(bg),
                StoreBackgroundResult::Rejected(bg) => {
                    lock_or_recover(pipeline_state).discard_request(request.request_id);
                    Some(bg)
                }
            };
            if let Some(mut orphan) = orphan {
                let _ = orphan.child.kill();
                let _ = orphan.child.wait();
                let _ = orphan.stderr_drain.join();
            }
            append_pipeline_log(&ctx.root_dir, &format!("metadata stored key={}", key));
            if let Some(ref path) = pw_args.output_file {
                let _ = std::fs::write(path, &diagnostics);
            }
            return (0, diagnostics);
        }
    }

    // EOF: rustc exited before emitting the metadata artifact (compilation error).
    let exit_code = child.wait().ok().and_then(|s| s.code()).unwrap_or(1);
    maybe_cleanup_pipeline_dir(
        &ctx.root_dir,
        true,
        "metadata rustc exited before emitting rmeta",
    );
    if let Some(ref path) = pw_args.output_file {
        let _ = std::fs::write(path, &diagnostics);
    }
    (exit_code, diagnostics)
}

pub(crate) fn handle_pipelining_full(
    request: &WorkRequestContext,
    args: Vec<String>,
    key: PipelineKey,
    pipeline_state: &Arc<Mutex<PipelineState>>,
    self_path: &std::path::Path,
) -> (i32, String) {
    let action = lock_or_recover(pipeline_state).claim_for_full(&key, request.request_id);

    match action {
        FullRequestAction::Background(mut bg, child_reaped) => {
            append_pipeline_log(&bg.pipeline_root_dir, &format!("full start key={}", key));
            let remaining = bg.stderr_drain.join().unwrap_or_default();
            let all_diagnostics = bg.diagnostics_before + &remaining;

            let wait_result = bg.child.wait();
            child_reaped.store(true, Ordering::SeqCst);

            match wait_result {
                Ok(status) => {
                    let exit_code = status.code().unwrap_or(1);
                    if exit_code == 0 {
                        let copy_result = match request.sandbox_dir.as_ref() {
                            Some(dir) => copy_all_outputs_to_sandbox(
                                &bg.pipeline_output_dir,
                                dir.as_str(),
                                bg.original_out_dir.as_str(),
                            )
                            .map(|_| ())
                            .map_err(|e| format!("pipelining: output materialization failed: {e}")),
                            None => copy_outputs_unsandboxed(
                                &bg.pipeline_output_dir,
                                bg.original_out_dir.as_path(),
                            ),
                        };
                        if let Err(e) = copy_result {
                            append_pipeline_log(
                                &bg.pipeline_root_dir,
                                &format!("full output copy error: {e}"),
                            );
                            lock_or_recover(pipeline_state).cleanup(&key, request.request_id);
                            return (1, format!("{all_diagnostics}\n{e}"));
                        }
                    }
                    append_pipeline_log(
                        &bg.pipeline_root_dir,
                        &format!("full done key={} exit_code={}", key, exit_code),
                    );
                    maybe_cleanup_pipeline_dir(
                        &bg.pipeline_root_dir,
                        exit_code != 0,
                        "full action failed",
                    );
                    lock_or_recover(pipeline_state).cleanup(&key, request.request_id);
                    (exit_code, all_diagnostics)
                }
                Err(e) => {
                    lock_or_recover(pipeline_state).cleanup(&key, request.request_id);
                    (1, format!("failed to wait for background rustc: {e}"))
                }
            }
        }
        FullRequestAction::Fallback => {
            let worker_state_root = std::env::current_dir()
                .ok()
                .map(|cwd| cwd.join("_pw_state").join("fallback.log"));
            if let Some(path) = worker_state_root {
                if let Ok(mut file) = std::fs::OpenOptions::new()
                    .create(true)
                    .append(true)
                    .open(path)
                {
                    let _ = writeln!(
                        file,
                        "full missing bg request_id={} key={} sandbox_dir={:?}",
                        request.request_id, key, request.sandbox_dir
                    );
                }
            }
            let filtered_args = strip_pipelining_flags(&args);
            let result = match request.sandbox_dir.as_ref() {
                Some(dir) => run_sandboxed_request(self_path, filtered_args, dir.as_str())
                    .unwrap_or_else(|e| (1, format!("pipelining fallback error: {e}"))),
                None => {
                    prepare_outputs(&filtered_args);
                    run_request(self_path, filtered_args)
                        .unwrap_or_else(|e| (1, format!("pipelining fallback error: {e}")))
                }
            };
            let orphaned_bg = lock_or_recover(pipeline_state).cleanup_key_fully(&key);
            if let Some(mut bg) = orphaned_bg {
                let _ = bg.child.kill();
                let _ = bg.child.wait();
                let _ = bg.stderr_drain.join();
            }
            result
        }
        FullRequestAction::Busy => (
            1,
            format!("pipelining: full request already active for key {key}"),
        ),
    }
}

/// Kills the background rustc process associated with a cancelled request.
///
/// Uses `PipelineState::cancel_by_request_id` to remove the entry under the
/// lock, then performs blocking kill/wait/join **after** releasing the lock
/// to avoid holding the mutex during I/O.
pub(super) fn kill_pipelined_request(
    pipeline_state: &Arc<Mutex<PipelineState>>,
    request_id: RequestId,
) {
    // Remove the entry under the lock (fast, O(1) HashMap ops).
    let cancelled = lock_or_recover(pipeline_state).cancel_by_request_id(request_id);
    // Blocking kill/wait/join happens here, outside the lock.
    let killed = cancelled.kill();
    if killed {
        append_worker_lifecycle_log(&format!(
            "pid={} event=cancel_kill request_id={}",
            current_pid(),
            request_id,
        ));
    }
}

/// Copies all regular files from `src_dir` to `dest_dir` (unsandboxed path).
///
/// Skips same-file copies (when src and dest resolve to the same inode).
/// Returns an error if any file operation fails.
/// Copies a single .rmeta file to the `_pipeline/` subdirectory of out_dir (unsandboxed).
/// Returns `Some(error_message)` on failure, `None` on success.
fn copy_rmeta_unsandboxed(
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
    let same_file = rmeta_src
        .canonicalize()
        .ok()
        .zip(dest.canonicalize().ok())
        .is_some_and(|(a, b)| a == b);
    if !same_file {
        if let Err(e) = std::fs::copy(rmeta_src, &dest) {
            return Some(format!("pipelining: failed to copy rmeta: {e}"));
        }
    }
    None
}

/// Copies all regular files from `src_dir` to `dest_dir` (unsandboxed path).
fn copy_outputs_unsandboxed(
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
            let same_file = entry
                .path()
                .canonicalize()
                .ok()
                .zip(dest.canonicalize().ok())
                .is_some_and(|(a, b)| a == b);
            if !same_file {
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

/// Extracts the artifact path from an rmeta artifact notification JSON line.
/// Returns `Some(path)` for `{"artifact":"path/to/lib.rmeta","emit":"metadata"}`,
/// `None` for all other lines.
pub(super) fn extract_rmeta_path(line: &str) -> Option<String> {
    if let Ok(JsonValue::Object(ref map)) = line.parse::<JsonValue>() {
        if let (Some(JsonValue::String(artifact)), Some(JsonValue::String(emit))) =
            (map.get("artifact"), map.get("emit"))
        {
            if artifact.ends_with(".rmeta") && emit == "metadata" {
                return Some(artifact.clone());
            }
        }
    }
    None
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
