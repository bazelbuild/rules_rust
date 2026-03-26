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
//! # Architecture: Single-rustc Pipelining
//!
//! Each crate is compiled by a single rustc invocation that produces both `.rmeta`
//! (metadata, encoding type/trait information for downstream crates) and `.rlib`
//! (the full compiled artifact including object code).  Rustc emits `.rmeta` at the
//! boundary between analysis and codegen — specifically in `encode_and_write_metadata`
//! inside `passes.rs`, before `codegen_crate` is called — so downstream crates can
//! begin their own compilation as soon as the metadata is flushed.
//!
//! This module implements a two-phase split of that single rustc invocation across
//! two Bazel worker requests:
//!
//! 1. **Metadata request** (`--pipelining-metadata --pipelining-key=<key>`):
//!    Spawns rustc as a background child process.  A dedicated thread reads rustc's
//!    stdout line-by-line and blocks until it sees the sentinel that signals `.rmeta`
//!    has been written to disk.  At that point a [`WorkResponse`] is sent back to
//!    Bazel so downstream actions can start immediately, while the child continues
//!    running codegen in the background.
//!
//! 2. **Full request** (`--pipelining-full --pipelining-key=<key>`):
//!    Retrieves the still-running child from [`PipelineState`] by key and waits for
//!    it to exit.  Copies outputs from the pipeline output directory back into the
//!    Bazel sandbox before sending the final [`WorkResponse`].
//!
//! # Sandbox Contract Compliance
//!
//! Bazel's persistent-worker sandbox contract has two rules:
//!
//! **Rule 1 — all I/O goes through `sandbox_dir`.**
//! Satisfied by setting the worker process's `cwd` to `sandbox_dir` so that every
//! relative path resolves inside the sandbox.  Outputs that must persist across the
//! two requests (`.rmeta`, `.rlib`, `.d` files, etc.) are redirected to a
//! worker-owned directory outside Bazel control:
//! `_pw_state/pipeline/<key>/outputs/`.  The full handler copies them back into the
//! sandbox before returning.
//!
//! **Rule 2 — no file access after the [`WorkResponse`] is sent.**
//! The metadata response is sent before codegen begins.  After that point the
//! background rustc process continues running, but it does NOT access any sandbox
//! input files because:
//!
//! - Source files are read once into `Arc<String>` entries in rustc's `SourceMap`
//!   during parsing, before `.rmeta` is emitted.
//!   See: <https://github.com/rust-lang/rust/blob/main/compiler/rustc_span/src/source_map.rs>
//! - Dependency `.rmeta` files are memory-mapped once during the "resolve crate"
//!   phase, also before codegen.
//!   See: <https://rustc-dev-guide.rust-lang.org/backend/libs-and-metadata.html>
//! - Proc macros are fully expanded during the parsing/expansion phase, before
//!   `.rmeta` is written.
//!   See: <https://github.com/rust-lang/rust/issues/60988>
//!
//! This has been empirically verified via strace on rustc 1.94.0: zero `open`/`read`
//! syscalls to sandbox input paths are observed after `.rmeta` is written.
//! See the regression test:
//! `test/unit/pipelined_compilation/strace_rustc_post_metadata_test.sh`
//!
//! # Caveats
//!
//! - **Undocumented rustc internals.** The ordering guarantee (all sandbox reads
//!   complete before `.rmeta` emission) is an observable consequence of rustc's
//!   current pass ordering, not a documented API contract.  A future rustc refactor
//!   (e.g. parallel front-end, lazy source loading) could break this assumption.
//!   The strace test provides a regression signal.
//!
//! - **Incremental compilation.** The incremental cache directory must reside
//!   outside the Bazel sandbox (e.g. in `_pw_state/`) so it persists across both
//!   requests and across rebuilds.  Enabling incremental inside the sandbox causes
//!   cache misses and potential corruption.
//!
//! - **No precedent.** Spanning background work across two separate Bazel worker
//!   requests is not an officially supported pattern.  This implementation is
//!   experimental and may interact unexpectedly with Bazel features such as dynamic
//!   execution, worker cancellation, or future sandboxing policy changes.
//!
//! # Cancellation
//!
//! [`PipelineState`] maintains a `request_index`: a `HashMap` from active Bazel
//! request IDs to pipeline keys.  This index enables the cancel handler to locate
//! the correct in-flight pipeline entry when Bazel sends a cancel signal.
//!
//! Invariants:
//!
//! - A pipeline entry is registered in `request_index` **before** the metadata
//!   [`WorkResponse`] is sent (i.e., before the request becomes cancel-acknowledgeable).
//! - Ownership of a pipeline entry transfers atomically from the metadata handler to
//!   the full handler: the metadata handler inserts the entry; the full handler
//!   removes it.
//! - After a cancel response is sent, the background rustc child is killed (or the
//!   request has already completed and the child has exited normally).
//!
//! See the "Cancellation Direction" section of the consolidated worker-pipelining
//! plan at `thoughts/shared/plans/2026-03-25-consolidated-worker-pipelining-plan.md`
//! for the rationale behind these invariants.

use std::collections::HashMap;
use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;

use tinyjson::JsonValue;

use crate::options::{is_pipelining_flag, is_relocated_pw_flag};
use crate::util::read_stamp_status_to_array;
use crate::ProcessWrapperError;

use super::protocol::WorkRequestContext;
use super::sandbox::{
    copy_all_outputs_to_sandbox, copy_output_to_sandbox, make_dir_files_writable,
    make_path_writable, prepare_outputs, resolve_relative_to, run_request,
    run_sandboxed_request,
};
use super::{append_worker_lifecycle_log, current_pid, lock_or_recover};

/// Pipelining mode for a worker request, parsed from process_wrapper flags.
pub(super) enum PipeliningMode {
    /// No pipelining flags present — handle as a normal subprocess request.
    None,
    /// `--pipelining-metadata --pipelining-key=<key>` present.
    /// Start a full rustc, return as soon as `.rmeta` is ready, cache the Child.
    Metadata { key: String },
    /// `--pipelining-full --pipelining-key=<key>` present.
    /// Retrieve the cached Child from PipelineState and wait for it to finish.
    Full { key: String },
}

/// Lifecycle phase of a single pipelined compilation.
///
///   PreRegistered ──store()──> MetadataRunning ──take_for_full()──> FullWaiting ──cleanup()──> (removed)
///   Any phase ──cancel_by_request_id()──> (removed, child killed if applicable)
pub(super) enum PipelinePhase {
    /// Main thread registered the request; worker thread not yet spawned rustc.
    PreRegistered {
        metadata_request_id: i64,
    },

    /// Rustc spawned, .rmeta emitted, metadata response sent. Background codegen continues.
    MetadataRunning {
        metadata_request_id: i64,
        bg: BackgroundRustc,
        pid: u32,
    },

    /// Full handler took BackgroundRustc; waiting for child exit + output copy.
    /// PID retained for cancel-via-signal, guarded by `child_reaped` to prevent
    /// killing a recycled PID after the full handler has called `child.wait()`.
    FullWaiting {
        #[allow(dead_code)]
        full_request_id: i64,
        pid: u32,
        /// Set to `true` by the full handler immediately after `child.wait()`
        /// returns. The cancel handler checks this before sending a raw signal.
        child_reaped: Arc<AtomicBool>,
    },
}

/// Result of cancelling a pipeline entry. The blocking kill/wait/join must
/// happen **outside** the `PipelineState` lock to avoid holding the mutex
/// during I/O.
pub(super) enum CancelledEntry {
    /// Request ID was not found in the pipeline.
    NotFound,
    /// Entry existed but had no running child (PreRegistered or missing).
    NoChild,
    /// We own the BackgroundRustc — kill + wait + join the child.
    OwnedChild(BackgroundRustc),
    /// Child was taken by the full handler; only the PID remains for raw kill.
    /// The `child_reaped` flag prevents killing a recycled PID after the full
    /// handler has already waited on the child.
    PidOnly(u32, Arc<AtomicBool>),
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
    pub(super) original_out_dir: String,
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
pub(super) struct PipelineState {
    /// Pipeline key → current phase.
    entries: HashMap<String, PipelinePhase>,
    /// Reverse index: request_id → pipeline key (for O(1) cancel lookup).
    request_index: HashMap<i64, String>,
    /// Claim flags for ALL in-flight requests (pipelined + non-pipelined).
    /// Whoever atomically swaps the flag first sends the WorkResponse.
    claim_flags: HashMap<i64, Arc<AtomicBool>>,
}

impl PipelineState {
    pub(super) fn new() -> Self {
        Self {
            entries: HashMap::new(),
            request_index: HashMap::new(),
            claim_flags: HashMap::new(),
        }
    }

    /// Register a non-pipelined request's claim flag.
    pub(super) fn register_claim(&mut self, request_id: i64) -> Arc<AtomicBool> {
        let flag = Arc::new(AtomicBool::new(false));
        self.claim_flags.insert(request_id, Arc::clone(&flag));
        flag
    }

    /// (none) → PreRegistered. Returns claim flag.
    ///
    /// For metadata requests, creates a new PreRegistered entry.
    /// For full requests (entry already exists as MetadataRunning), just
    /// registers the claim flag and request_index mapping.
    pub(super) fn pre_register(&mut self, request_id: i64, key: String) -> Arc<AtomicBool> {
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

    /// Stores a background rustc in the pipeline entry.
    ///
    /// Handles two cases:
    /// - PreRegistered → MetadataRunning (normal first-time store)
    /// - MetadataRunning → MetadataRunning (Bazel retried the metadata action;
    ///   the old child is returned for the caller to kill outside the lock)
    ///
    /// Returns `Some(bg)` if the new child could not be stored (entry was
    /// removed by cancel) or if an old child was replaced (retry). The caller
    /// must kill the returned BackgroundRustc **after releasing the lock**.
    pub(super) fn store(&mut self, key: &str, bg: BackgroundRustc) -> Option<BackgroundRustc> {
        let pid = bg.child.id();
        if let Some(entry) = self.entries.get_mut(key) {
            match entry {
                PipelinePhase::PreRegistered {
                    metadata_request_id,
                } => {
                    let req_id = *metadata_request_id;
                    *entry = PipelinePhase::MetadataRunning {
                        metadata_request_id: req_id,
                        bg,
                        pid,
                    };
                    return None;
                }
                PipelinePhase::MetadataRunning {
                    metadata_request_id,
                    ..
                } => {
                    // Bazel retried the metadata action (same key). Replace the
                    // old child with the new one; return the old for cleanup.
                    let req_id = *metadata_request_id;
                    let old = std::mem::replace(
                        entry,
                        PipelinePhase::MetadataRunning {
                            metadata_request_id: req_id,
                            bg,
                            pid,
                        },
                    );
                    if let PipelinePhase::MetadataRunning { bg: old_bg, .. } = old {
                        return Some(old_bg);
                    }
                    unreachable!();
                }
                _ => {}
            }
        }
        // Entry was removed (cancelled) or in unexpected phase.
        Some(bg)
    }

    /// MetadataRunning → FullWaiting. Returns BackgroundRustc and a
    /// `child_reaped` flag for the full handler to set after `child.wait()`.
    pub(super) fn take_for_full(
        &mut self,
        key: &str,
        full_request_id: i64,
    ) -> Option<(BackgroundRustc, Arc<AtomicBool>)> {
        let entry = self.entries.get_mut(key)?;
        if let PipelinePhase::MetadataRunning {
            metadata_request_id,
            pid,
            ..
        } = entry
        {
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
            // full_request_id is already in request_index from pre_register
            if let PipelinePhase::MetadataRunning { bg, .. } = old {
                Some((bg, child_reaped))
            } else {
                unreachable!()
            }
        } else {
            None
        }
    }

    /// Terminal: remove entry entirely.
    pub(super) fn cleanup(&mut self, key: &str, request_id: i64) {
        self.entries.remove(key);
        self.request_index.remove(&request_id);
        self.claim_flags.remove(&request_id);
    }

    /// Remove a claim flag (called when a worker thread finishes).
    pub(super) fn remove_claim(&mut self, request_id: i64) {
        self.claim_flags.remove(&request_id);
    }

    /// Get a clone of the claim flag for a request.
    pub(super) fn get_claim_flag(&self, request_id: i64) -> Option<Arc<AtomicBool>> {
        self.claim_flags.get(&request_id).cloned()
    }

    /// Cancel a pipelined request. Removes the entry and returns a
    /// [`CancelledEntry`] describing what cleanup is needed. The caller
    /// must perform the blocking kill/wait/join **after releasing the lock**
    /// to avoid holding the mutex during I/O.
    pub(super) fn cancel_by_request_id(&mut self, request_id: i64) -> CancelledEntry {
        let key = match self.request_index.remove(&request_id) {
            Some(k) => k,
            None => return CancelledEntry::NotFound,
        };
        match self.entries.remove(&key) {
            Some(PipelinePhase::PreRegistered { .. }) => CancelledEntry::NoChild,
            Some(PipelinePhase::MetadataRunning { bg, .. }) => {
                CancelledEntry::OwnedChild(bg)
            }
            Some(PipelinePhase::FullWaiting {
                pid, child_reaped, ..
            }) => CancelledEntry::PidOnly(pid, child_reaped),
            None => CancelledEntry::NoChild,
        }
    }

    /// Drain all pipeline entries for shutdown. Returns all entries that
    /// have running children so the caller can kill them outside the lock.
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
            }
        }
        self.request_index.clear();
        result
    }

    // --- Test accessors ---

    #[cfg(test)]
    pub(super) fn entry_count(&self) -> usize {
        self.entries.len()
    }

    #[cfg(test)]
    pub(super) fn has_entry(&self, key: &str) -> bool {
        self.entries.contains_key(key)
    }

    #[cfg(test)]
    pub(super) fn is_empty(&self) -> bool {
        self.entries.is_empty() && self.request_index.is_empty()
    }

    #[cfg(test)]
    pub(super) fn has_request(&self, id: i64) -> bool {
        self.request_index.contains_key(&id)
    }

    #[cfg(test)]
    pub(super) fn has_claim(&self, id: i64) -> bool {
        self.claim_flags.contains_key(&id)
    }
}

#[cfg(unix)]
extern "C" {
    fn kill(pid: i32, sig: i32) -> i32;
}

/// Parsed process_wrapper arguments from before the `--` separator.
pub(super) struct ParsedPwArgs {
    pub(super) subst: Vec<(String, String)>,
    pub(super) env_files: Vec<String>,
    pub(super) arg_files: Vec<String>,
    pub(super) stable_status_file: Option<String>,
    pub(super) volatile_status_file: Option<String>,
    pub(super) output_file: Option<String>,
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
pub(super) struct WorkerStateRoots {
    pipeline_root: PathBuf,
}

impl WorkerStateRoots {
    pub(super) fn ensure() -> Result<Self, ProcessWrapperError> {
        let pipeline_root = PathBuf::from("_pw_state/pipeline");
        std::fs::create_dir_all(&pipeline_root).map_err(|e| {
            ProcessWrapperError(format!("failed to create worker pipeline root: {e}"))
        })?;
        Ok(Self { pipeline_root })
    }

    pub(super) fn pipeline_dir(&self, key: &str) -> PathBuf {
        self.pipeline_root.join(key)
    }
}

/// Parses pipelining mode from worker request arguments.
///
/// Pipelining flags live in `rustc_flags` (the @paramfile) so both
/// RustcMetadata and Rustc actions have identical startup args (same worker
/// key). This function checks both direct args and any @paramfile content
/// found after the `--` separator.
pub(super) fn detect_pipelining_mode(args: &[String]) -> PipeliningMode {
    // First pass: check direct args (handles the no-paramfile case and is fast).
    let (mut is_metadata, mut is_full, mut key) =
        scan_pipelining_flags(args.iter().map(String::as_str));

    // Second pass: if not found yet, read @paramfiles from the rustc args
    // (everything after "--"). With always_use_param_file, pipelining flags
    // are inside the @paramfile rather than in direct args.
    if !is_metadata && !is_full {
        let sep_pos = args.iter().position(|a| a == "--");
        let rustc_args = match sep_pos {
            Some(pos) => &args[pos + 1..],
            None => &[][..],
        };
        for arg in rustc_args {
            if let Some(path) = arg.strip_prefix('@') {
                if let Ok(content) = std::fs::read_to_string(path) {
                    let (m, f, k) = scan_pipelining_flags(content.lines());
                    is_metadata |= m;
                    is_full |= f;
                    if k.is_some() {
                        key = k;
                    }
                    if is_metadata || is_full {
                        break;
                    }
                }
            }
        }
    }

    match (is_metadata, is_full, key) {
        (true, _, Some(k)) => PipeliningMode::Metadata { key: k },
        (_, true, Some(k)) => PipeliningMode::Full { key: k },
        _ => PipeliningMode::None,
    }
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
    let current_dir = pwd.to_string_lossy().into_owned();
    let mut parsed = ParsedPwArgs {
        subst: Vec::new(),
        env_files: Vec::new(),
        arg_files: Vec::new(),
        stable_status_file: None,
        volatile_status_file: None,
        output_file: None,
    };
    let mut i = 0;
    while i < pw_args.len() {
        match pw_args[i].as_str() {
            "--subst" => {
                if let Some(kv) = pw_args.get(i + 1) {
                    if let Some((k, v)) = kv.split_once('=') {
                        let resolved = if v == "${pwd}" { &current_dir } else { v };
                        parsed.subst.push((k.to_owned(), resolved.to_owned()));
                    }
                    i += 1;
                }
            }
            "--env-file" => {
                if let Some(path) = pw_args.get(i + 1) {
                    parsed.env_files.push(path.clone());
                    i += 1;
                }
            }
            "--arg-file" => {
                if let Some(path) = pw_args.get(i + 1) {
                    parsed.arg_files.push(path.clone());
                    i += 1;
                }
            }
            "--output-file" => {
                if let Some(path) = pw_args.get(i + 1) {
                    parsed.output_file = Some(path.clone());
                    i += 1;
                }
            }
            "--stable-status-file" => {
                if let Some(path) = pw_args.get(i + 1) {
                    parsed.stable_status_file = Some(path.clone());
                    i += 1;
                }
            }
            "--volatile-status-file" => {
                if let Some(path) = pw_args.get(i + 1) {
                    parsed.volatile_status_file = Some(path.clone());
                    i += 1;
                }
            }
            _ => {}
        }
        i += 1;
    }
    parsed
}

/// Builds the environment map: inherit current process + env files + apply substitutions.
pub(super) fn build_rustc_env(
    env_files: &[String],
    stable_status_file: Option<&str>,
    volatile_status_file: Option<&str>,
    subst: &[(String, String)],
) -> HashMap<String, String> {
    let mut env: HashMap<String, String> = std::env::vars().collect();
    for path in env_files {
        if let Ok(content) = std::fs::read_to_string(path) {
            for line in content.lines() {
                if line.is_empty() {
                    continue;
                }
                if let Some((k, v)) = line.split_once('=') {
                    env.insert(k.to_owned(), v.to_owned());
                }
            }
        }
    }
    let stable_stamp_mappings: Vec<(String, String)> = stable_status_file
        .map(|path| read_stamp_status_to_array(path.to_owned()))
        .transpose()
        .unwrap_or_default()
        .unwrap_or_default();
    let volatile_stamp_mappings: Vec<(String, String)> = volatile_status_file
        .map(|path| read_stamp_status_to_array(path.to_owned()))
        .transpose()
        .unwrap_or_default()
        .unwrap_or_default();
    for (k, v) in stable_stamp_mappings
        .iter()
        .chain(volatile_stamp_mappings.iter())
    {
        for val in env.values_mut() {
            *val = val.replace(&format!("{{{k}}}"), v);
        }
    }
    for val in env.values_mut() {
        crate::util::apply_substitutions(val, subst);
    }
    env
}

/// Prepares rustc arguments: expand @paramfiles, apply substitutions, strip
/// pipelining flags, and append args from --arg-file files.
///
/// Returns `(rustc_args, original_out_dir)` on success.
pub(super) fn prepare_rustc_args(
    rustc_and_after: &[String],
    pw_args: &ParsedPwArgs,
    execroot_dir: &std::path::Path,
) -> Result<(Vec<String>, String), (i32, String)> {
    let mut rustc_args = expand_rustc_args(rustc_and_after, &pw_args.subst, execroot_dir);
    if rustc_args.is_empty() {
        return Err((
            1,
            "pipelining: no rustc arguments after expansion".to_string(),
        ));
    }

    // Append args from --arg-file files (e.g. build script output: --cfg=..., -L ...).
    for path in &pw_args.arg_files {
        if let Ok(content) = std::fs::read_to_string(path) {
            for line in content.lines() {
                if !line.is_empty() {
                    rustc_args.push(apply_substs(line, &pw_args.subst));
                }
            }
        }
    }

    let original_out_dir = find_out_dir_in_expanded(&rustc_args).unwrap_or_default();

    Ok((rustc_args, original_out_dir))
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
pub(super) fn expand_rustc_args(
    rustc_and_after: &[String],
    subst: &[(String, String)],
    execroot_dir: &std::path::Path,
) -> Vec<String> {
    let mut result = Vec::new();
    for raw in rustc_and_after {
        let arg = apply_substs(raw, subst);
        if let Some(path) = arg.strip_prefix('@') {
            let resolved_path = resolve_relative_to(path, execroot_dir);
            match std::fs::read_to_string(&resolved_path) {
                Ok(content) => {
                    for line in content.lines() {
                        if line.is_empty() {
                            continue;
                        }
                        let line = apply_substs(line, subst);
                        if !is_pipelining_flag(&line) {
                            let resolved = crate::options::resolve_external_path(&line);
                            result.push(resolved.into_owned());
                        }
                    }
                }
                Err(_) => {
                    // Can't read the paramfile — pass it through and let rustc error.
                    if !is_pipelining_flag(&arg) {
                        result.push(arg);
                    }
                }
            }
        } else if !is_pipelining_flag(&arg) {
            let resolved = crate::options::resolve_external_path(&arg);
            result.push(match resolved {
                std::borrow::Cow::Borrowed(_) => arg,
                std::borrow::Cow::Owned(s) => s,
            });
        }
    }
    result
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
    key: &str,
    request: &WorkRequestContext,
) -> Result<PipelineContext, (i32, String)> {
    let root_dir = state_roots.pipeline_dir(key);

    // Create the pipeline root and outputs dir.
    // Clear any leftover outputs from a previous failed run for this key.
    let outputs_dir = root_dir.join("outputs");
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

    // Two modes for determining rustc's CWD:
    //
    // SANDBOXED: Use sandbox_dir directly as CWD. All relative paths in rustc
    // args (--extern, -Ldependency, source files) resolve against sandbox_dir
    // where Bazel placed the inputs. This satisfies Rule 1 of the multiplex
    // sandbox contract ("use sandbox_dir as prefix for all reads and writes").
    // After .rmeta emission, background rustc only writes to --out-dir
    // (redirected to persistent pipeline dir), so sandbox cleanup after the
    // metadata response doesn't affect it (verified via strace — Gate 0).
    //
    // UNSANDBOXED: Use the worker's real execroot as CWD.
    let execroot_dir = if let Some(sandbox_dir) = request.sandbox_dir.as_deref() {
        // Make absolute WITHOUT canonicalizing — canonicalize() follows symlinks
        // inside the sandbox back to the real execroot, which defeats the purpose.
        // We need the sandbox path itself so rustc reads through sandbox_dir.
        let sandbox_path = std::path::Path::new(sandbox_dir);
        if sandbox_path.is_absolute() {
            sandbox_path.to_path_buf()
        } else {
            let cwd = std::env::current_dir().map_err(|e| {
                (1, format!("pipelining: failed to get worker CWD: {e}"))
            })?;
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

/// Handles a `--pipelining-metadata` request (sandboxed or unsandboxed).
///
/// Starts a full rustc with `--emit=dep-info,metadata,link --json=artifacts`,
/// reads stderr until the `{"artifact":"...rmeta","emit":"metadata"}` JSON
/// notification appears, stores the running Child in PipelineState, and returns
/// success immediately so Bazel can unblock downstream rlib compiles.
///
/// Two modes:
/// - **Sandboxed**: rustc runs from `sandbox_dir` directly. All relative paths
///   in args resolve against the sandbox where Bazel placed inputs. Compliant
///   with the Bazel multiplex sandbox contract (Rule 1: all reads via sandbox_dir).
/// - **Unsandboxed**: rustc runs from the real execroot.
pub(super) fn handle_pipelining_metadata(
    request: &WorkRequestContext,
    args: Vec<String>,
    key: String,
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

    // Note: we intentionally do NOT drain completed entries here. Background rustc
    // entries must remain in PipelineState until handle_pipelining_full() takes them,
    // even if the child has already exited (fast-compiling crates often finish codegen
    // before the full action arrives). Entries are cleaned up by take() in the full
    // handler, or persist harmlessly until worker exit for orphaned entries.

    let ctx = match create_pipeline_context(state_roots, &key, request) {
        Ok(v) => v,
        Err(e) => return e,
    };

    // execroot_dir is already canonicalized (absolute) in both sandboxed and
    // unsandboxed modes, so ${pwd} substitution produces correct absolute paths
    // for env vars like OUT_DIR=${pwd}/bazel-out/...
    let raw_pw_args = parse_pw_args(pw_raw, &ctx.execroot_dir);
    let pw_args = ParsedPwArgs {
        subst: raw_pw_args.subst,
        env_files: raw_pw_args
            .env_files
            .into_iter()
            .map(|path| {
                resolve_relative_to(&path, &ctx.execroot_dir)
                    .display()
                    .to_string()
            })
            .collect(),
        arg_files: raw_pw_args
            .arg_files
            .into_iter()
            .map(|path| {
                resolve_relative_to(&path, &ctx.execroot_dir)
                    .display()
                    .to_string()
            })
            .collect(),
        stable_status_file: raw_pw_args.stable_status_file.map(|path| {
            resolve_relative_to(&path, &ctx.execroot_dir)
                .display()
                .to_string()
        }),
        volatile_status_file: raw_pw_args.volatile_status_file.map(|path| {
            resolve_relative_to(&path, &ctx.execroot_dir)
                .display()
                .to_string()
        }),
        output_file: raw_pw_args.output_file.map(|path| {
            let base = request
                .sandbox_dir
                .as_deref()
                .map(std::path::Path::new)
                .unwrap_or(ctx.execroot_dir.as_path());
            resolve_relative_to(&path, base).display().to_string()
        }),
    };
    let env = build_rustc_env(
        &pw_args.env_files,
        pw_args.stable_status_file.as_deref(),
        pw_args.volatile_status_file.as_deref(),
        &pw_args.subst,
    );

    let (rustc_args, original_out_dir) =
        match prepare_rustc_args(rustc_and_after, &pw_args, &ctx.execroot_dir) {
            Ok(v) => v,
            Err(e) => return e,
        };

    // Redirect --out-dir to our persistent directory so rustc writes all outputs
    // (.rlib, .d) there instead of the Bazel-managed out-dir.
    let rustc_args = rewrite_out_dir_in_expanded(rustc_args, &ctx.outputs_dir);
    // Also redirect --emit=metadata=<path> to the outputs dir so the .rmeta is
    // written alongside other outputs in the persistent pipeline dir, not in the
    // real execroot where it could conflict with concurrent builds.
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
            return (
                1,
                format!("pipelining: failed to create deps dir: {e}"),
            );
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

    // Spawn rustc with the prepared env and args.
    // On Windows, write args to a response file to avoid CreateProcessW length limits.
    let mut cmd = Command::new(&rustc_args[0]);
    #[cfg(windows)]
    {
        let response_file_path = ctx.root_dir.join("metadata_rustc.args");
        let content = rustc_args[1..].join("\n");
        if let Err(e) = std::fs::write(&response_file_path, &content) {
            return (
                1,
                format!("pipelining: failed to write response file: {e}"),
            );
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

    loop {
        let mut line = String::new();
        match reader.read_line(&mut line) {
            Ok(0) => break,
            Err(_) => break,
            Ok(_) => {}
        }
        let trimmed = line.trim_end_matches('\n').trim_end_matches('\r');

        if let Some(rmeta_path_str) = extract_rmeta_path(trimmed) {
            // Resolve the rmeta path relative to rustc's CWD (ctx.execroot_dir)
            // to get an absolute path, since the worker process has a different CWD.
            let rmeta_resolved = resolve_relative_to(&rmeta_path_str, &ctx.execroot_dir);
            let rmeta_resolved_str = rmeta_resolved.display().to_string();
            append_pipeline_log(
                &ctx.root_dir,
                &format!("metadata rmeta ready: {}", rmeta_resolved_str),
            );
            // Copy .rmeta to the declared output location (_pipeline/ subdirectory).
            match request.sandbox_dir.as_ref() {
                Some(dir) => {
                    copy_output_to_sandbox(
                        &rmeta_resolved_str,
                        dir,
                        &original_out_dir,
                        "_pipeline",
                    );
                }
                None => {
                    let rmeta_src = &rmeta_resolved;
                    if let Some(filename) = rmeta_src.file_name() {
                        let dest_pipeline =
                            std::path::Path::new(&original_out_dir).join("_pipeline");
                        let _ = std::fs::create_dir_all(&dest_pipeline);
                        let dest = dest_pipeline.join(filename);
                        // Skip copy if source and dest resolve to the same file.
                        let same_file = rmeta_src
                            .canonicalize()
                            .ok()
                            .zip(dest.canonicalize().ok())
                            .is_some_and(|(a, b)| a == b);
                        if !same_file {
                            let _ = std::fs::copy(rmeta_src, &dest);
                        }
                    }
                }
            }
            // .rmeta is ready! Spawn a drain thread to prevent pipe buffer deadlock.
            let drain = thread::spawn(move || {
                let mut remaining = String::new();
                let mut buf = String::new();
                while reader.read_line(&mut buf).unwrap_or(0) > 0 {
                    let l = buf.trim_end_matches('\n').trim_end_matches('\r');
                    if let Ok(json) = l.parse::<JsonValue>() {
                        if let Some(rendered) = extract_rendered_diagnostic(&json) {
                            remaining.push_str(&rendered);
                            remaining.push('\n');
                        }
                    }
                    buf.clear();
                }
                remaining
            });

            let diagnostics_before = diagnostics.clone();
            let orphan = lock_or_recover(pipeline_state).store(
                &key,
                BackgroundRustc {
                    child,
                    diagnostics_before,
                    stderr_drain: drain,
                    pipeline_root_dir: ctx.root_dir.clone(),
                    pipeline_output_dir: ctx.outputs_dir.clone(),
                    original_out_dir,
                },
            );
            // Kill orphaned background rustc outside the lock.
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

        if let Ok(json) = trimmed.parse::<JsonValue>() {
            if let Some(rendered) = extract_rendered_diagnostic(&json) {
                diagnostics.push_str(&rendered);
                diagnostics.push('\n');
            }
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

/// Handles a `--pipelining-full` request (sandboxed or unsandboxed).
///
/// Looks up the background rustc by pipeline key. If found, waits for it to
/// finish and copies outputs to the correct location. If not found (worker was
/// restarted), falls back to running rustc normally as a one-shot compilation.
pub(super) fn handle_pipelining_full(
    request: &WorkRequestContext,
    args: Vec<String>,
    key: String,
    pipeline_state: &Arc<Mutex<PipelineState>>,
    self_path: &std::path::Path,
) -> (i32, String) {
    let taken = lock_or_recover(pipeline_state).take_for_full(&key, request.request_id);

    match taken {
        Some((mut bg, child_reaped)) => {
            append_pipeline_log(&bg.pipeline_root_dir, &format!("full start key={}", key));
            // Join the drain thread first (avoids deadlock: child blocks on stderr
            // write if the pipe buffer fills up before we drain it).
            let remaining = bg.stderr_drain.join().unwrap_or_default();
            let all_diagnostics = bg.diagnostics_before + &remaining;

            let wait_result = bg.child.wait();
            // Mark the child as reaped immediately so the cancel handler
            // won't send SIGKILL to a potentially-recycled PID.
            child_reaped.store(true, Ordering::SeqCst);

            match wait_result {
                Ok(status) => {
                    let exit_code = status.code().unwrap_or(1);
                    if exit_code == 0 {
                        // Copy all outputs from the persistent pipeline dir.
                        match request.sandbox_dir.as_ref() {
                            Some(dir) => {
                                copy_all_outputs_to_sandbox(
                                    &bg.pipeline_output_dir,
                                    dir,
                                    &bg.original_out_dir,
                                );
                            }
                            None => {
                                let dest_dir = std::path::Path::new(&bg.original_out_dir);
                                let _ = std::fs::create_dir_all(dest_dir);
                                if let Ok(entries) = std::fs::read_dir(&bg.pipeline_output_dir) {
                                    for entry in entries.flatten() {
                                        if let Ok(meta) = entry.metadata() {
                                            if meta.is_file() {
                                                let dest = dest_dir.join(entry.file_name());
                                                let same_file = entry
                                                    .path()
                                                    .canonicalize()
                                                    .ok()
                                                    .zip(dest.canonicalize().ok())
                                                    .is_some_and(|(a, b)| a == b);
                                                if !same_file {
                                                    let _ = std::fs::copy(entry.path(), &dest);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
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
        None => {
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
            // No cached process found (worker was restarted between the metadata
            // and full actions, or metadata was a cache hit). Fall back to a normal
            // one-shot compilation.
            let filtered_args = strip_pipelining_flags(&args);
            let result = match request.sandbox_dir.as_ref() {
                Some(dir) => run_sandboxed_request(self_path, filtered_args, dir)
                    .unwrap_or_else(|e| (1, format!("pipelining fallback error: {e}"))),
                None => {
                    prepare_outputs(&filtered_args);
                    run_request(self_path, filtered_args)
                        .unwrap_or_else(|e| (1, format!("pipelining fallback error: {e}")))
                }
            };
            lock_or_recover(pipeline_state).cleanup(&key, request.request_id);
            result
        }
    }
}

/// Kills the background rustc process associated with a cancelled request.
///
/// Uses `PipelineState::cancel_by_request_id` to remove the entry under the
/// lock, then performs blocking kill/wait/join **after** releasing the lock
/// to avoid holding the mutex during I/O.
pub(super) fn kill_pipelined_request(pipeline_state: &Arc<Mutex<PipelineState>>, request_id: i64) {
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

/// Extracts the `"rendered"` field from a rustc JSON diagnostic message.
pub(super) fn extract_rendered_diagnostic(json: &JsonValue) -> Option<String> {
    if let JsonValue::Object(ref map) = json {
        if let Some(JsonValue::String(rendered)) = map.get("rendered") {
            return Some(rendered.clone());
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
