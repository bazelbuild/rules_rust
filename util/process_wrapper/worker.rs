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

//! Bazel JSON persistent worker protocol implementation.
//!
//! When Bazel invokes process_wrapper with `--persistent_worker`, this module
//! takes over. It reads newline-delimited JSON WorkRequest messages from stdin,
//! executes each request by spawning process_wrapper itself with the request's
//! arguments, and writes a JSON WorkResponse to stdout.
//!
//! The worker supports both singleplex (requestId == 0) and multiplex
//! (requestId > 0) modes. Multiplex requests are dispatched to separate threads,
//! allowing concurrent processing. This enables worker-managed pipelined
//! compilation where a metadata action and a full compile action for the same
//! crate can share state through the `PipelineState` map.
//!
//! The worker runs in Bazel's execroot (without sandboxing), so incremental
//! compilation caches see stable source file paths between requests—avoiding
//! the ICE that occurs when sandbox paths change between builds.
//!
//! Protocol reference: https://bazel.build/remote/persistent

use std::collections::{HashMap, HashSet};
use std::io::{self, BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Instant;

use tinyjson::JsonValue;

use crate::options::{is_pipelining_flag, is_relocated_pw_flag};
use crate::util::read_stamp_status_to_array;
use crate::ProcessWrapperError;

/// Locks a mutex, recovering from poisoning instead of panicking.
///
/// If a worker thread panics while holding a mutex, the mutex becomes
/// "poisoned". Rather than cascading the panic to all other threads,
/// we recover the inner value — the data is still valid because
/// `catch_unwind` prevents partial updates from escaping.
fn lock_or_recover<T>(mutex: &Mutex<T>) -> std::sync::MutexGuard<'_, T> {
    mutex
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
}

fn current_pid() -> u32 {
    std::process::id()
}

fn current_thread_label() -> String {
    format!("{:?}", thread::current().id())
}

static RESPONSE_SEQUENCE: AtomicUsize = AtomicUsize::new(0);
static WORKER_SHUTTING_DOWN: AtomicBool = AtomicBool::new(false);

fn extract_request_id_from_raw_line(line: &str) -> Option<i64> {
    let key_pos = line.find("\"requestId\"")?;
    let after_key = &line[key_pos + "\"requestId\"".len()..];
    let colon = after_key.find(':')?;
    let after_colon = after_key[colon + 1..].trim_start();
    let digits: String = after_colon
        .chars()
        .take_while(|ch| ch.is_ascii_digit())
        .collect();
    if digits.is_empty() {
        None
    } else {
        digits.parse().ok()
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct WorkRequestInput {
    path: String,
    digest: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct WorkRequestContext {
    request_id: i64,
    arguments: Vec<String>,
    sandbox_dir: Option<String>,
    inputs: Vec<WorkRequestInput>,
    cancel: bool,
}

impl WorkRequestContext {
    fn from_json(request: &JsonValue) -> Self {
        Self {
            request_id: extract_request_id(request),
            arguments: extract_arguments(request),
            sandbox_dir: extract_sandbox_dir(request),
            inputs: extract_inputs(request),
            cancel: extract_cancel(request),
        }
    }
}

#[derive(Clone, Debug)]
struct WorkerStateRoots {
    request_root: PathBuf,
    pipeline_root: PathBuf,
}

impl WorkerStateRoots {
    fn ensure() -> Result<Self, ProcessWrapperError> {
        let request_root = PathBuf::from("_pw_state/requests");
        let pipeline_root = PathBuf::from("_pw_state/pipeline");
        std::fs::create_dir_all(&request_root).map_err(|e| {
            ProcessWrapperError(format!("failed to create worker request root: {e}"))
        })?;
        std::fs::create_dir_all(&pipeline_root).map_err(|e| {
            ProcessWrapperError(format!("failed to create worker pipeline root: {e}"))
        })?;
        Ok(Self {
            request_root,
            pipeline_root,
        })
    }

    fn request_dir(&self, request_id: i64) -> PathBuf {
        self.request_root.join(request_id.to_string())
    }

    fn pipeline_dir(&self, key: &str) -> PathBuf {
        self.pipeline_root.join(key)
    }
}

/// Entry point for persistent worker mode.
///
/// Loops reading JSON WorkRequest messages from stdin until EOF.
/// - Singleplex requests (requestId == 0): processed inline on the main thread
///   (backward-compatible with Bazel's singleplex worker protocol).
/// - Multiplex requests (requestId > 0): dispatched to a new thread, allowing
///   concurrent processing and in-process state sharing for pipelined builds.
///
/// Bazel starts the worker with:
///   `process_wrapper [startup_args] --persistent_worker`
/// where `startup_args` are the fixed parts of the action command line
/// (e.g. `--subst pwd=${pwd} -- /path/to/rustc`).
///
/// Each WorkRequest.arguments contains the per-request part (the `@flagfile`).
/// The worker must combine startup_args + per-request args when spawning the
/// subprocess, so process_wrapper receives the full argument list it expects.
pub(crate) fn worker_main() -> Result<(), ProcessWrapperError> {
    let request_counter = Arc::new(AtomicUsize::new(0));
    install_worker_panic_hook();
    let _lifecycle =
        WorkerLifecycleGuard::new(&std::env::args().collect::<Vec<_>>(), &request_counter);
    install_worker_signal_handlers();

    let self_path = std::env::current_exe()
        .map_err(|e| ProcessWrapperError(format!("failed to get worker executable path: {e}")))?;

    // Collect the startup args that Bazel passed when spawning this worker
    // process. These are the fixed action args (e.g. `--subst pwd=${pwd} --
    // /path/to/rustc`). We skip argv[0] (the binary path) and strip
    // `--persistent_worker` since that flag is what triggered worker mode.
    let startup_args: Vec<String> = std::env::args()
        .skip(1)
        .filter(|a| a != "--persistent_worker")
        .collect();

    let stdin = io::stdin();
    // Serialize writes to fd 1 so multiplexed responses remain newline-delimited
    // JSON records with no byte interleaving.
    let stdout = Arc::new(Mutex::new(()));

    // Shared state for worker-managed pipelined compilation.
    // The metadata action stores a running rustc Child here; the full compile
    // action retrieves it and waits for completion.
    let pipeline_state: Arc<Mutex<PipelineState>> = Arc::new(Mutex::new(PipelineState::new()));
    let state_roots = Arc::new(WorkerStateRoots::ensure()?);

    // Tracks in-flight requests for cancel/completion race prevention.
    // Key: requestId, Value: claim flag (false = response not yet sent).
    // Whoever atomically sets the flag true first (cancel or worker thread) sends
    // the response; the other side skips. Entries are removed by the worker thread
    // when it finishes, so request IDs can be safely reused across builds when
    // Bazel keeps the worker process alive.
    let in_flight: Arc<Mutex<HashMap<i64, Arc<AtomicBool>>>> = Arc::new(Mutex::new(HashMap::new()));

    for line in stdin.lock().lines() {
        let line = match line {
            Ok(line) => line,
            Err(e) => {
                begin_worker_shutdown("stdin_read_error");
                append_worker_lifecycle_log(&format!(
                    "pid={} event=stdin_read_error thread={} error={}",
                    current_pid(),
                    current_thread_label(),
                    e
                ));
                return Err(ProcessWrapperError(format!(
                    "failed to read WorkRequest: {e}"
                )));
            }
        };
        if line.is_empty() {
            continue;
        }
        if worker_is_shutting_down() {
            append_worker_lifecycle_log(&format!(
                "pid={} event=request_ignored_for_shutdown thread={} bytes={}",
                current_pid(),
                current_thread_label(),
                line.len(),
            ));
            break;
        }
        request_counter.fetch_add(1, Ordering::SeqCst);

        let request: JsonValue = match line.parse::<JsonValue>() {
            Ok(request) => request,
            Err(e) => {
                // Try to extract requestId so we can send an error response
                // rather than leaving Bazel hanging on the missing response.
                if let Some(request_id) = extract_request_id_from_raw_line(&line) {
                    append_worker_lifecycle_log(&format!(
                        "pid={} thread={} request_parse_error request_id={} bytes={} error={}",
                        current_pid(),
                        current_thread_label(),
                        request_id,
                        line.len(),
                        e
                    ));
                    let response =
                        build_response(1, &format!("worker protocol parse error: {e}"), request_id);
                    let _ = write_worker_response(
                        &stdout,
                        &response,
                        request_id,
                        "request_parse_error",
                    );
                }
                continue;
            }
        };
        let request = WorkRequestContext::from_json(&request);
        append_worker_lifecycle_log(&format!(
            "pid={} thread={} request_received request_id={} cancel={} crate={} emit={} pipeline_key={}",
            current_pid(),
            current_thread_label(),
            request.request_id,
            request.cancel,
            crate_name_from_args(&request.arguments).unwrap_or("-"),
            emit_arg_from_args(&request.arguments).unwrap_or("-"),
            pipeline_key_from_args(&request.arguments).unwrap_or("-"),
        ));

        if worker_is_shutting_down() {
            let response = build_shutdown_response(request.request_id);
            let _ = write_worker_response(&stdout, &response, request.request_id, "shutdown");
            continue;
        }

        if request.request_id == 0 {
            // Singleplex: process inline on the main thread (backward-compatible).
            let mut full_args = startup_args.clone();
            full_args.extend(request.arguments.clone());
            relocate_pw_flags(&mut full_args);

            // Workers run in execroot without sandboxing. Bazel marks action outputs
            // read-only after each successful action. Make them writable first.
            prepare_outputs(&full_args);

            let (exit_code, output) = run_request(&self_path, full_args)?;

            let response = build_response(exit_code, &output, request.request_id);
            write_worker_response(&stdout, &response, request.request_id, "singleplex")?;
            append_worker_lifecycle_log(&format!(
                "pid={} thread={} request_complete request_id={} exit_code={} output_bytes={} mode=singleplex",
                current_pid(),
                current_thread_label(),
                request.request_id,
                exit_code,
                output.len(),
            ));
        } else {
            let stdout = Arc::clone(&stdout);
            let in_flight = Arc::clone(&in_flight);

            // Cancel request: Bazel no longer needs the result for this requestId.
            // Respond with wasCancelled=true immediately if we haven't already responded.
            if request.cancel {
                // Look up the flag for this in-flight request.
                let flag = lock_or_recover(&in_flight)
                    .get(&request.request_id)
                    .map(Arc::clone);
                if let Some(flag) = flag {
                    // Try to claim the response slot atomically.
                    if !flag.swap(true, Ordering::SeqCst) {
                        // We claimed it — kill any associated background rustc
                        // to avoid wasting CPU when the remote leg wins.
                        kill_pipelined_request(&pipeline_state, request.request_id);
                        let response = build_cancel_response(request.request_id);
                        let _ =
                            write_worker_response(&stdout, &response, request.request_id, "cancel");
                    }
                    // If swap returned true, the worker thread already sent the normal
                    // response before we could cancel — nothing more to do.
                }
                // If the flag is not found, the request already completed and cleaned up.
                continue;
            }

            // Register this request in the in-flight map with an unclaimed flag.
            // The worker thread removes the entry when it finishes, so the same
            // request ID can be safely reused across builds.
            let claim_flag = Arc::new(AtomicBool::new(false));
            lock_or_recover(&in_flight).insert(request.request_id, Arc::clone(&claim_flag));

            // Multiplex: dispatch to a new thread. Bazel bounds concurrency via
            // --worker_max_multiplex_instances (default: 8), so no in-process
            // thread pool is needed.
            let self_path = self_path.clone();
            let startup_args = startup_args.clone();
            let pipeline_state = Arc::clone(&pipeline_state);
            let state_roots = Arc::clone(&state_roots);
            let request = request.clone();

            std::thread::spawn(move || {
                append_worker_lifecycle_log(&format!(
                    "pid={} thread={} request_thread_start request_id={} crate={} emit={} pipeline_key={}",
                    current_pid(),
                    current_thread_label(),
                    request.request_id,
                    crate_name_from_args(&request.arguments).unwrap_or("-"),
                    emit_arg_from_args(&request.arguments).unwrap_or("-"),
                    pipeline_key_from_args(&request.arguments).unwrap_or("-"),
                ));
                if worker_is_shutting_down() {
                    if !claim_flag.swap(true, Ordering::SeqCst) {
                        let response = build_shutdown_response(request.request_id);
                        let _ = write_worker_response(
                            &stdout,
                            &response,
                            request.request_id,
                            "shutdown_thread_start",
                        );
                    }
                    lock_or_recover(&in_flight).remove(&request.request_id);
                    append_worker_lifecycle_log(&format!(
                        "pid={} thread={} request_thread_skipped_for_shutdown request_id={} claimed={}",
                        current_pid(),
                        current_thread_label(),
                        request.request_id,
                        claim_flag.load(Ordering::SeqCst),
                    ));
                    return;
                }
                let (exit_code, output) =
                    match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                        let mut full_args = startup_args;
                        full_args.extend(request.arguments.clone());
                        relocate_pw_flags(&mut full_args);

                        let sandbox_opt = request.sandbox_dir.clone();

                        if let Err(e) = snapshot_request_context(&state_roots, &request) {
                            return (1, format!("worker request snapshot error: {e}"));
                        }

                        // Make output files writable (Bazel marks previous outputs read-only).
                        match sandbox_opt {
                            Some(ref dir) => {
                                prepare_outputs_sandboxed(&full_args, dir);
                            }
                            None => prepare_outputs(&full_args),
                        }

                        // Check for pipelining mode flags (--pipelining-metadata,
                        // --pipelining-full, --pipelining-key=<key>). When present these
                        // are handled specially; otherwise fall through to a normal subprocess.
                        let pipelining = detect_pipelining_mode(&full_args);

                        match pipelining {
                            PipeliningMode::Metadata { key } => handle_pipelining_metadata(
                                &request,
                                full_args,
                                key,
                                &state_roots,
                                &pipeline_state,
                            ),
                            PipeliningMode::Full { key } => handle_pipelining_full(
                                &request,
                                full_args,
                                key,
                                &pipeline_state,
                                &self_path,
                            ),
                            PipeliningMode::None => match sandbox_opt {
                                Some(ref dir) => run_sandboxed_request(&self_path, full_args, dir)
                                    .unwrap_or_else(|e| {
                                        (1, format!("sandboxed worker error: {e}"))
                                    }),
                                None => run_request(&self_path, full_args)
                                    .unwrap_or_else(|e| (1, format!("worker thread error: {e}"))),
                            },
                        }
                    })) {
                        Ok(result) => result,
                        Err(_) => (1, "internal error: worker thread panicked".to_string()),
                    };

                // Remove our entry from in_flight regardless of who sends the response.
                // This keeps the map from growing indefinitely and allows request_id
                // to be reused in the next build.
                lock_or_recover(&in_flight).remove(&request.request_id);

                // Only send a response if a cancel acknowledgment hasn't already been sent.
                if !claim_flag.swap(true, Ordering::SeqCst) {
                    let response = build_response(exit_code, &output, request.request_id);
                    let _ =
                        write_worker_response(&stdout, &response, request.request_id, "multiplex");
                }
                append_worker_lifecycle_log(&format!(
                    "pid={} thread={} request_thread_complete request_id={} exit_code={} output_bytes={} claimed={}",
                    current_pid(),
                    current_thread_label(),
                    request.request_id,
                    exit_code,
                    output.len(),
                    claim_flag.load(Ordering::SeqCst),
                ));
            });
        }
    }

    begin_worker_shutdown("stdin_eof");
    append_worker_lifecycle_log(&format!(
        "pid={} event=stdin_eof thread={} requests_seen={}",
        current_pid(),
        current_thread_label(),
        request_counter.load(Ordering::SeqCst),
    ));

    Ok(())
}

// ---------------------------------------------------------------------------
// Pipelining mode detection
// ---------------------------------------------------------------------------

/// Pipelining mode for a worker request, parsed from process_wrapper flags.
enum PipeliningMode {
    /// No pipelining flags present — handle as a normal subprocess request.
    None,
    /// `--pipelining-metadata --pipelining-key=<key>` present.
    /// Start a full rustc, return as soon as `.rmeta` is ready, cache the Child.
    Metadata { key: String },
    /// `--pipelining-full --pipelining-key=<key>` present.
    /// Retrieve the cached Child from PipelineState and wait for it to finish.
    Full { key: String },
}

/// Parses pipelining mode from worker request arguments.
///
/// Pipelining flags live in `rustc_flags` (the @paramfile) so both
/// RustcMetadata and Rustc actions have identical startup args (same worker
/// key). This function checks both direct args and any @paramfile content
/// found after the `--` separator.
fn detect_pipelining_mode(args: &[String]) -> PipeliningMode {
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
fn scan_pipelining_flags<'a>(iter: impl Iterator<Item = &'a str>) -> (bool, bool, Option<String>) {
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

// ---------------------------------------------------------------------------
// Pipeline state: in-process cache of background rustc processes
// ---------------------------------------------------------------------------

/// A background rustc process started by a RustcMetadata action.
///
/// After the `.rmeta` artifact notification, the handler stores the Child
/// here and spawns a background thread to drain the remaining stderr output.
/// The full compile handler retrieves this, joins the drain thread, and waits
/// for the child to exit.
struct BackgroundRustc {
    child: std::process::Child,
    /// Request ID of the metadata action that spawned this background rustc.
    /// Used by the cancel handler to find which pipeline key to kill.
    metadata_request_id: i64,
    /// Diagnostics captured from rustc stderr before the metadata signal.
    diagnostics_before: String,
    /// Background thread draining rustc's remaining stderr output after the
    /// metadata signal. Must be joined before waiting on `child` to avoid
    /// deadlock (child blocks on stderr write if the pipe buffer fills up).
    /// Returns the diagnostics captured after the metadata signal.
    stderr_drain: thread::JoinHandle<String>,
    /// Worker-managed persistent root for this pipelined compile.
    pipeline_root_dir: PathBuf,
    /// Worker-managed persistent output directory used by the background rustc.
    pipeline_output_dir: PathBuf,
    /// Original `--out-dir` value (before rewriting to `pipeline_output_dir`).
    /// Used by the full handler to copy outputs from the persistent dir to the
    /// correct sandbox-relative location.
    original_out_dir: String,
}

/// In-process store of background rustc processes for worker-managed pipelining.
///
/// Keyed by the pipeline key (crate name + output hash), set by the Bazel-side
/// `--pipelining-key=<key>` argument.
struct PipelineState {
    active: HashMap<String, BackgroundRustc>,
}

impl PipelineState {
    fn new() -> Self {
        Self {
            active: HashMap::new(),
        }
    }

    fn store(&mut self, key: String, bg: BackgroundRustc) {
        self.active.insert(key, bg);
    }

    fn take(&mut self, key: &str) -> Option<BackgroundRustc> {
        self.active.remove(key)
    }

    /// Remove entries whose background rustc child has already exited.
    ///
    /// This handles the case where a build fails between the metadata and full
    /// actions: the metadata handler stores a `BackgroundRustc` but the full
    /// handler never arrives. Without cleanup, resources leak until the worker dies.
    fn drain_completed(&mut self) -> usize {
        let stale_keys: Vec<String> = self
            .active
            .iter_mut()
            .filter_map(|(key, bg)| {
                // try_wait returns Ok(Some(status)) if the child has exited,
                // Ok(None) if still running, Err if something went wrong.
                match bg.child.try_wait() {
                    Ok(Some(_)) => Some(key.clone()),
                    Ok(None) => None,
                    Err(_) => Some(key.clone()), // treat errors as stale
                }
            })
            .collect();
        let count = stale_keys.len();
        for key in &stale_keys {
            if let Some(bg) = self.active.remove(key) {
                // Join the stderr drain thread to avoid resource leaks.
                let _ = bg.stderr_drain.join();
                append_worker_metric_log(&format!(
                    "pipeline_drain_stale key={key} pid={}",
                    current_pid()
                ));
            }
        }
        count
    }
}

// ---------------------------------------------------------------------------
// Pipelining helpers (shared by metadata and full handlers)
// ---------------------------------------------------------------------------

/// Parsed process_wrapper arguments from before the `--` separator.
struct ParsedPwArgs {
    subst: Vec<(String, String)>,
    env_files: Vec<String>,
    arg_files: Vec<String>,
    stable_status_file: Option<String>,
    volatile_status_file: Option<String>,
    output_file: Option<String>,
}

/// Lightweight pipeline context for the "resolve-through" approach.
///
/// Instead of staging inputs into a worker-owned execroot, we use the worker's
/// real execroot (CWD) directly. Only outputs are redirected to a persistent
/// pipeline directory to prevent inter-request interference.
struct PipelineContext {
    root_dir: PathBuf,
    execroot_dir: PathBuf,
    outputs_dir: PathBuf,
}

#[derive(Default)]
struct OutputMaterializationStats {
    files: usize,
    hardlinked_files: usize,
    copied_files: usize,
}


#[cfg(unix)]
const SIG_TERM: i32 = 15;

#[cfg(unix)]
unsafe extern "C" {
    fn signal(signum: i32, handler: usize) -> usize;
    fn close(fd: i32) -> i32;
    fn write(fd: i32, buf: *const std::ffi::c_void, count: usize) -> isize;
}


/// Parses process_wrapper flags from the pre-`--` portion of args.
fn parse_pw_args(pw_args: &[String], pwd: &std::path::Path) -> ParsedPwArgs {
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
fn build_rustc_env(
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
        for (k, v) in subst {
            *val = val.replace(&format!("${{{k}}}"), v);
        }
    }
    env
}

/// Prepares rustc arguments: expand @paramfiles, apply substitutions, strip
/// pipelining flags, and append args from --arg-file files.
///
/// Returns `(rustc_args, original_out_dir)` on success.
fn prepare_rustc_args(
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

/// Resolves the real Bazel execroot from sandbox symlinks.
///
/// In multiplex sandboxing, the sandbox dir (`__sandbox/N/_main/`) contains
/// symlinks to the real execroot (`<output_base>/execroot/_main/`).
/// For example: `__sandbox/3/_main/external/foo/src/lib.rs` →
///              `/home/.../<hash>/execroot/_main/external/foo/src/lib.rs`
///
/// We resolve any input's symlink target and strip the relative path suffix
/// to recover the real execroot root.
fn resolve_real_execroot(sandbox_dir: &str, request: &WorkRequestContext) -> Option<PathBuf> {
    let sandbox_path = std::path::Path::new(sandbox_dir);
    for input in &request.inputs {
        let full_path = sandbox_path.join(&input.path);
        if let Ok(target) = std::fs::read_link(&full_path) {
            // target = <real_execroot>/<relative_path>
            // input.path = <relative_path>
            // Strip the relative path suffix to get the real execroot.
            let target_str = target.to_string_lossy();
            if target_str.ends_with(&input.path) {
                let prefix = &target_str[..target_str.len() - input.path.len()];
                let execroot = PathBuf::from(prefix);
                if execroot.is_dir() {
                    return Some(execroot);
                }
            }
        }
        // Also try following through to the canonical path
        if let Ok(canonical) = full_path.canonicalize() {
            let canonical_str = canonical.to_string_lossy().to_string();
            if canonical_str.ends_with(&input.path) {
                let prefix = &canonical_str[..canonical_str.len() - input.path.len()];
                let execroot = PathBuf::from(prefix);
                if execroot.is_dir() {
                    return Some(execroot);
                }
            }
        }
    }
    None
}

fn resolve_relative_to(path: &str, base_dir: &std::path::Path) -> PathBuf {
    let path = std::path::Path::new(path);
    if path.is_absolute() {
        path.to_path_buf()
    } else {
        base_dir.join(path)
    }
}

fn materialize_output_file(
    src: &std::path::Path,
    dest: &std::path::Path,
) -> Result<bool, std::io::Error> {
    if let Some(parent) = dest.parent() {
        std::fs::create_dir_all(parent)?;
    }

    // Skip if src and dest resolve to the same file (e.g., when rustc writes
    // directly into the sandbox via --emit=metadata=<relative-path> and the
    // copy destination is the same location). Removing dest would delete src.
    if let (Ok(a), Ok(b)) = (src.canonicalize(), dest.canonicalize()) {
        if a == b {
            return Ok(false);
        }
    }

    if dest.exists() {
        std::fs::remove_file(dest)?;
    }

    match std::fs::hard_link(src, dest) {
        Ok(()) => Ok(true),
        Err(link_err) => match std::fs::copy(src, dest) {
            Ok(_) => Ok(false),
            Err(copy_err) => Err(std::io::Error::new(
                copy_err.kind(),
                format!(
                    "failed to materialize {} at {} via hardlink ({link_err}) or copy ({copy_err})",
                    src.display(),
                    dest.display(),
                ),
            )),
        },
    }
}

#[cfg(unix)]
fn symlink_path(
    src: &std::path::Path,
    dest: &std::path::Path,
    _is_dir: bool,
) -> Result<(), std::io::Error> {
    std::os::unix::fs::symlink(src, dest)
}

#[cfg(windows)]
fn symlink_path(
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

fn seed_sandbox_cache_root(sandbox_dir: &std::path::Path) -> Result<(), ProcessWrapperError> {
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

fn snapshot_named_request(
    pipeline_root: &std::path::Path,
    file_name: &str,
    request: &WorkRequestContext,
) -> Result<(), ProcessWrapperError> {
    std::fs::create_dir_all(pipeline_root)
        .map_err(|e| ProcessWrapperError(format!("failed to create pipeline snapshot dir: {e}")))?;
    std::fs::write(
        pipeline_root.join(file_name),
        build_request_snapshot(request),
    )
    .map_err(|e| ProcessWrapperError(format!("failed to write pipeline request snapshot: {e}")))
}

fn append_pipeline_log(pipeline_root: &std::path::Path, message: &str) {
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

fn is_tracked_artifact_input(path: &str) -> bool {
    path.contains("/_pipeline/") || path.ends_with(".rmeta") || path.ends_with(".rlib")
}

fn describe_path_state(path: &std::path::Path) -> String {
    let meta = match std::fs::symlink_metadata(path) {
        Ok(meta) => meta,
        Err(err) => {
            return format!("state=missing err={err}");
        }
    };

    let file_type = meta.file_type();
    if file_type.is_symlink() {
        let target = std::fs::read_link(path)
            .map(|target| target.display().to_string())
            .unwrap_or_else(|err| format!("<unreadable:{err}>"));
        return format!(
            "state=symlink readonly={} target={target}",
            meta.permissions().readonly()
        );
    }
    if file_type.is_dir() {
        return format!("state=dir readonly={}", meta.permissions().readonly());
    }

    format!(
        "state=file size={} readonly={}",
        meta.len(),
        meta.permissions().readonly()
    )
}

fn append_request_input_state_log(
    pipeline_root: &std::path::Path,
    label: &str,
    request: &WorkRequestContext,
    resolve_path: impl Fn(&str) -> PathBuf,
) {
    let interesting_inputs: Vec<_> = request
        .inputs
        .iter()
        .filter(|input| is_tracked_artifact_input(&input.path))
        .collect();

    append_pipeline_log(
        pipeline_root,
        &format!("{label} tracked_inputs={}", interesting_inputs.len()),
    );

    for input in interesting_inputs {
        let resolved = resolve_path(&input.path);
        append_pipeline_log(
            pipeline_root,
            &format!(
                "{label} path={} digest={:?} resolved={} {}",
                input.path,
                input.digest,
                resolved.display(),
                describe_path_state(&resolved),
            ),
        );
    }
}

fn append_metadata_request_probes(
    pipeline_root: &std::path::Path,
    request: &WorkRequestContext,
    execroot_dir: &std::path::Path,
) {
    append_request_input_state_log(pipeline_root, "metadata request input", request, |path| {
        resolve_relative_to(path, execroot_dir)
    });

    let interesting_inputs: Vec<_> = request
        .inputs
        .iter()
        .filter(|input| is_tracked_artifact_input(&input.path))
        .collect();
    for input in interesting_inputs {
        let source = resolve_relative_to(&input.path, execroot_dir);
        let staged = resolve_relative_to(&input.path, execroot_dir);
        append_pipeline_log(
            pipeline_root,
            &format!(
                "metadata request source path={} source={} {} staged={} {}",
                input.path,
                source.display(),
                describe_path_state(&source),
                staged.display(),
                describe_path_state(&staged),
            ),
        );
    }
}

fn collect_rustc_extern_specs(rustc_args: &[String]) -> Vec<(String, String)> {
    let mut externs = Vec::new();
    let mut i = 0;
    while i < rustc_args.len() {
        let arg = &rustc_args[i];
        let spec = if let Some(spec) = arg.strip_prefix("--extern=") {
            Some(spec)
        } else if arg == "--extern" {
            rustc_args.get(i + 1).map(|s| s.as_str())
        } else {
            None
        };

        if let Some(spec) = spec {
            if let Some((name, path)) = spec.split_once('=') {
                externs.push((name.to_string(), path.to_string()));
            }
            if arg == "--extern" {
                i += 1;
            }
        }
        i += 1;
    }
    externs
}

fn append_rustc_extern_state_log(
    pipeline_root: &std::path::Path,
    label: &str,
    rustc_args: &[String],
    execroot_dir: &std::path::Path,
) {
    let mut seen = HashSet::new();
    let externs = collect_rustc_extern_specs(rustc_args);
    append_pipeline_log(pipeline_root, &format!("{label} externs={}", externs.len()));

    for (name, path) in externs {
        let key = format!("{name}={path}");
        if !seen.insert(key) {
            continue;
        }
        let resolved = resolve_relative_to(&path, execroot_dir);
        append_pipeline_log(
            pipeline_root,
            &format!(
                "{label} name={} path={} resolved={} {}",
                name,
                path,
                resolved.display(),
                describe_path_state(&resolved),
            ),
        );
    }
}

fn append_worker_metric_log(message: &str) {
    let path = std::path::Path::new("_pw_state").join("metrics.log");
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

fn append_worker_response_log(message: &str) {
    let path = std::path::Path::new("_pw_state").join("responses.log");
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

fn append_worker_lifecycle_log(message: &str) {
    let root = std::path::Path::new("_pw_state");
    let _ = std::fs::create_dir_all(root);
    let path = root.join("worker_lifecycle.log");
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

fn worker_is_shutting_down() -> bool {
    WORKER_SHUTTING_DOWN.load(Ordering::SeqCst)
}

fn begin_worker_shutdown(reason: &str) {
    if WORKER_SHUTTING_DOWN
        .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
        .is_ok()
    {
        append_worker_lifecycle_log(&format!(
            "pid={} event=shutdown_begin thread={} reason={}",
            current_pid(),
            current_thread_label(),
            reason,
        ));
    }
}

#[cfg(unix)]
extern "C" fn worker_signal_handler(_signum: i32) {
    WORKER_SHUTTING_DOWN.store(true, Ordering::SeqCst);
    unsafe {
        close(0);
    } // close stdin to unblock main loop
}

#[cfg(unix)]
fn install_worker_signal_handlers() {
    static ONCE: std::sync::Once = std::sync::Once::new();
    ONCE.call_once(|| unsafe {
        signal(SIG_TERM, worker_signal_handler as *const () as usize);
    });
}

#[cfg(not(unix))]
fn install_worker_signal_handlers() {}

struct WorkerLifecycleGuard {
    pid: u32,
    start: Instant,
    request_counter: Arc<AtomicUsize>,
}

impl WorkerLifecycleGuard {
    fn new(argv: &[String], request_counter: &Arc<AtomicUsize>) -> Self {
        let pid = current_pid();
        let cwd = std::env::current_dir()
            .map(|cwd| cwd.display().to_string())
            .unwrap_or_else(|_| "<cwd-error>".to_string());
        append_worker_lifecycle_log(&format!(
            "pid={} event=start thread={} cwd={} argv_len={}",
            pid,
            current_thread_label(),
            cwd,
            argv.len(),
        ));
        Self {
            pid,
            start: Instant::now(),
            request_counter: Arc::clone(request_counter),
        }
    }
}

impl Drop for WorkerLifecycleGuard {
    fn drop(&mut self) {
        let uptime = self.start.elapsed();
        let requests = self.request_counter.load(Ordering::SeqCst);
        append_worker_lifecycle_log(&format!(
            "pid={} event=exit uptime_ms={} requests_seen={}",
            self.pid,
            uptime.as_millis(),
            requests,
        ));
        // Structured summary line for easy extraction by benchmark tooling.
        append_worker_lifecycle_log(&format!(
            "worker_exit pid={} requests_handled={} uptime_s={:.1}",
            self.pid,
            requests,
            uptime.as_secs_f64(),
        ));
    }
}

fn install_worker_panic_hook() {
    static ONCE: std::sync::Once = std::sync::Once::new();
    ONCE.call_once(|| {
        std::panic::set_hook(Box::new(|info| {
            append_worker_lifecycle_log(&format!(
                "pid={} event=panic thread={} info={}",
                current_pid(),
                current_thread_label(),
                info
            ));
        }));
    });
}

fn crate_name_from_args(args: &[String]) -> Option<&str> {
    args.iter()
        .find_map(|arg| arg.strip_prefix("--crate-name="))
}

fn emit_arg_from_args(args: &[String]) -> Option<&str> {
    args.iter().find_map(|arg| arg.strip_prefix("--emit="))
}

fn pipeline_key_from_args(args: &[String]) -> Option<&str> {
    args.iter()
        .find_map(|arg| arg.strip_prefix("--pipelining-key="))
}

fn worker_forced_exit_mode() -> Option<String> {
    std::env::var("PROCESS_WRAPPER_TEST_WORKER_MODE")
        .ok()
        .filter(|value| !value.is_empty())
}

fn write_worker_response(
    stdout: &Arc<Mutex<()>>,
    response: &str,
    request_id: i64,
    reason: &str,
) -> Result<(), ProcessWrapperError> {
    let sequence = RESPONSE_SEQUENCE.fetch_add(1, Ordering::SeqCst) + 1;
    let newline_count = response.bytes().filter(|b| *b == b'\n').count();
    let json_ok = response.parse::<JsonValue>().is_ok();
    let checksum = response.bytes().fold(0u64, |acc, byte| {
        acc.wrapping_mul(131).wrapping_add(byte as u64)
    });
    let prefix_hex = response
        .as_bytes()
        .iter()
        .take(32)
        .map(|byte| format!("{byte:02x}"))
        .collect::<Vec<_>>()
        .join("");
    let suffix_hex = response
        .as_bytes()
        .iter()
        .rev()
        .take(32)
        .copied()
        .collect::<Vec<_>>()
        .into_iter()
        .rev()
        .map(|byte| format!("{byte:02x}"))
        .collect::<Vec<_>>()
        .join("");
    append_worker_response_log(&format!(
        "seq={sequence} request_id={request_id} reason={reason} bytes={} newlines={} json_ok={json_ok} checksum={checksum:016x} prefix_hex={} suffix_hex={} preview={:?}",
        response.len(),
        newline_count,
        prefix_hex,
        suffix_hex,
        response.chars().take(200).collect::<String>(),
    ));

    let _guard = lock_or_recover(stdout);
    write_all_stdout_fd(response.as_bytes())
        .and_then(|_| write_all_stdout_fd(b"\n"))
        .map_err(|e| ProcessWrapperError(format!("failed to write WorkResponse: {e}")))?;

    if worker_forced_exit_mode().as_deref() == Some("exit_after_response") {
        append_worker_lifecycle_log(&format!(
            "pid={} event=forced_exit thread={} request_id={} reason={}",
            current_pid(),
            current_thread_label(),
            request_id,
            reason,
        ));
        std::process::exit(0);
    }
    Ok(())
}

#[cfg(unix)]
fn write_all_stdout_fd(mut bytes: &[u8]) -> io::Result<()> {
    while !bytes.is_empty() {
        let written = unsafe { write(1, bytes.as_ptr().cast(), bytes.len()) };
        if written < 0 {
            let err = io::Error::last_os_error();
            if err.kind() == io::ErrorKind::Interrupted {
                continue;
            }
            return Err(err);
        }
        let written = written as usize;
        if written == 0 {
            return Err(io::Error::new(
                io::ErrorKind::WriteZero,
                "short write to worker stdout",
            ));
        }
        bytes = &bytes[written..];
    }
    Ok(())
}

#[cfg(not(unix))]
fn write_all_stdout_fd(bytes: &[u8]) -> io::Result<()> {
    let mut out = io::stdout().lock();
    out.write_all(bytes)?;
    out.flush()
}

fn maybe_cleanup_pipeline_dir(pipeline_root: &std::path::Path, keep: bool, reason: &str) {
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

fn should_fault_inject_metadata_artifact(key: &str) -> bool {
    std::env::var("RULES_RUST_PIPELINE_FAULT_INJECT_KEY")
        .ok()
        .is_some_and(|value| value == key)
}

fn maybe_fault_inject_metadata_artifact(
    pipeline_root: &std::path::Path,
    key: &str,
    rmeta_path: &std::path::Path,
) {
    if !should_fault_inject_metadata_artifact(key) {
        return;
    }

    append_pipeline_log(
        pipeline_root,
        &format!(
            "fault injecting metadata artifact for key={} path={} before={}",
            key,
            rmeta_path.display(),
            describe_path_state(rmeta_path),
        ),
    );

    let result = std::fs::OpenOptions::new()
        .write(true)
        .truncate(true)
        .open(rmeta_path)
        .and_then(|mut file| file.write_all(b"fault injected invalid rmeta"));

    match result {
        Ok(()) => append_pipeline_log(
            pipeline_root,
            &format!(
                "fault injected metadata artifact for key={} after={}",
                key,
                describe_path_state(rmeta_path),
            ),
        ),
        Err(err) => append_pipeline_log(
            pipeline_root,
            &format!(
                "failed to fault inject metadata artifact for key={} path={}: {}",
                key,
                rmeta_path.display(),
                err
            ),
        ),
    }
}

fn should_always_preserve_pipeline_key(key: &str) -> bool {
    matches!(
        key,
        "lib_zerobuf_codegen_libzerobuf_codegen-229785134_rlib"
            | "lib_cli_config_getter_libcli_config_getter-1472696652_rlib"
            | "lib_platform_version_libplatform_version-1023817015_rlib"
            | "lib_zerobuf_cli_libzerobuf_cli-630641045_rlib"
    )
}

fn should_preserve_pipeline_dir(key: &str, exit_code: i32, staged_outputs: &[String]) -> bool {
    should_always_preserve_pipeline_key(key)
        || exit_code != 0
        || !staged_outputs.iter().any(|name| name.ends_with(".rlib"))
}

/// Creates a lightweight pipeline context using the "resolve-through" approach.
///
/// Instead of staging inputs into a worker-owned execroot, uses the worker's real
/// execroot (CWD) directly. Only creates a persistent output directory to prevent
/// inter-request output interference.
fn create_pipeline_context(
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
    std::fs::create_dir_all(&root_dir)
        .map_err(|e| (1, format!("pipelining: failed to create pipeline dir: {e}")))?;
    let root_dir = root_dir.canonicalize().map_err(|e| {
        (
            1,
            format!("pipelining: failed to resolve pipeline dir: {e}"),
        )
    })?;
    let outputs_dir = outputs_dir.canonicalize().map_err(|e| {
        (
            1,
            format!("pipelining: failed to resolve pipeline outputs dir: {e}"),
        )
    })?;

    // CRITICAL: Use the REAL execroot, not the sandbox or worker CWD.
    //
    // The sandbox dir is per-request and may be torn down after the metadata response.
    // The background rustc outlives the metadata request, so it needs a stable CWD.
    // The worker CWD (bazel-workers/.../workdir/_main/) has bazel-out/ but NOT source
    // files (external/, etc.). Only the real execroot has everything.
    //
    // When sandboxed: resolve a symlink from the sandbox back to the real execroot.
    // When unsandboxed: the worker CWD IS the real execroot (or close enough).
    let execroot_dir = if let Some(sandbox_dir) = request.sandbox_dir.as_deref() {
        resolve_real_execroot(sandbox_dir, request)
            .ok_or_else(|| (1, "pipelining: failed to resolve real execroot from sandbox symlinks".to_string()))?
    } else {
        std::env::current_dir()
            .map_err(|e| (1, format!("pipelining: failed to get worker CWD: {e}")))?
            .canonicalize()
            .map_err(|e| (1, format!("pipelining: failed to canonicalize worker CWD: {e}")))?
    };

    snapshot_named_request(&root_dir, "metadata_request.json", request).map_err(|e| {
        (
            1,
            format!("pipelining: failed to snapshot metadata request: {e}"),
        )
    })?;

    Ok(PipelineContext {
        root_dir,
        execroot_dir,
        outputs_dir,
    })
}

fn list_regular_files(dir: &std::path::Path) -> Vec<String> {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return Vec::new();
    };

    let mut files = entries
        .flatten()
        .filter_map(|entry| match entry.metadata() {
            Ok(metadata) if metadata.is_file() => {
                Some(entry.file_name().to_string_lossy().into_owned())
            }
            _ => None,
        })
        .collect::<Vec<_>>();
    files.sort();
    files
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
/// Uses the "resolve-through" approach: rustc runs from the worker's real
/// execroot (CWD). When `sandbox_dir` is `Some`, only the returned metadata
/// artifact is materialized back into the request sandbox before Bazel cleans it up.
fn handle_pipelining_metadata(
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

    // Note: we intentionally do NOT call drain_completed() here. Background rustc
    // entries must remain in PipelineState until handle_pipelining_full() takes them,
    // even if the child has already exited (fast-compiling crates often finish codegen
    // before the full action arrives). Entries are cleaned up by take() in the full
    // handler, or persist harmlessly until worker exit for orphaned entries.

    let ctx = match create_pipeline_context(state_roots, &key, request) {
        Ok(v) => v,
        Err(e) => return e,
    };

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
            "metadata start request_id={} key={} sandbox_dir={:?} original_out_dir={} execroot={} outputs={}",
            request.request_id,
            key,
            request.sandbox_dir,
            original_out_dir,
            ctx.execroot_dir.display(),
            ctx.outputs_dir.display(),
        ),
    );
    append_pipeline_log(
        &ctx.root_dir,
        &format!("metadata rustc args: {:?}", rustc_args),
    );
    append_metadata_request_probes(&ctx.root_dir, request, &ctx.execroot_dir);
    append_rustc_extern_state_log(
        &ctx.root_dir,
        "metadata rustc extern",
        &rustc_args,
        &ctx.execroot_dir,
    );
    // Spawn rustc directly with the prepared env and args.
    let mut cmd = Command::new(&rustc_args[0]);
    cmd.args(&rustc_args[1..])
        .env_clear()
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
            let rmeta_path = rmeta_resolved.as_path();
            append_pipeline_log(
                &ctx.root_dir,
                &format!(
                    "metadata saw rmeta artifact: {} (resolved={}) {}",
                    rmeta_path_str,
                    rmeta_resolved_str,
                    describe_path_state(rmeta_path)
                ),
            );
            // Copy .rmeta to the declared output location (_pipeline/ subdirectory).
            match request.sandbox_dir.as_ref() {
                Some(ref dir) => {
                    let copy_start = Instant::now();
                    let copy_stats = copy_output_to_sandbox(
                        &rmeta_resolved_str,
                        dir,
                        &original_out_dir,
                        "_pipeline",
                    );
                    append_pipeline_log(
                        &ctx.root_dir,
                        &format!(
                            "metadata copied rmeta into sandbox pipeline dir: {}/{} files={} hardlinks={} copies={} materialize_ms={}",
                            dir,
                            original_out_dir,
                            copy_stats.files,
                            copy_stats.hardlinked_files,
                            copy_stats.copied_files,
                            copy_start.elapsed().as_millis()
                        ),
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
                            if let Err(e) = std::fs::copy(rmeta_src, &dest) {
                                append_pipeline_log(
                                    &ctx.root_dir,
                                    &format!("metadata failed to copy rmeta to execroot pipeline dir: {e}"),
                                );
                            }
                        }
                    }
                }
            }
            maybe_fault_inject_metadata_artifact(&ctx.root_dir, &key, rmeta_path);

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
            lock_or_recover(pipeline_state).store(
                key.clone(),
                BackgroundRustc {
                    child,
                    metadata_request_id: request.request_id,
                    diagnostics_before,
                    stderr_drain: drain,
                    pipeline_root_dir: ctx.root_dir.clone(),
                    pipeline_output_dir: ctx.outputs_dir.clone(),
                    original_out_dir,
                },
            );
            append_pipeline_log(
                &ctx.root_dir,
                &format!(
                    "metadata stored background rustc; pipeline outputs now={:?}",
                    list_regular_files(&ctx.outputs_dir)
                ),
            );
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
    append_pipeline_log(
        &ctx.root_dir,
        &format!(
            "metadata rustc exited before emitting rmeta: exit_code={exit_code} diagnostics_bytes={}",
            diagnostics.len()
        ),
    );
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

/// Extracts the artifact path from an rmeta artifact notification JSON line.
/// Returns `Some(path)` for `{"artifact":"path/to/lib.rmeta","emit":"metadata"}`,
/// `None` for all other lines.
fn extract_rmeta_path(line: &str) -> Option<String> {
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
fn extract_rendered_diagnostic(json: &JsonValue) -> Option<String> {
    if let JsonValue::Object(ref map) = json {
        if let Some(JsonValue::String(rendered)) = map.get("rendered") {
            return Some(rendered.clone());
        }
    }
    None
}

/// Handles a `--pipelining-full` request (sandboxed or unsandboxed).
///
/// Looks up the background rustc by pipeline key. If found, waits for it to
/// finish and copies outputs to the correct location. If not found (worker was
/// restarted), falls back to running rustc normally as a one-shot compilation.
fn handle_pipelining_full(
    request: &WorkRequestContext,
    args: Vec<String>,
    key: String,
    pipeline_state: &Arc<Mutex<PipelineState>>,
    self_path: &std::path::Path,
) -> (i32, String) {
    let bg = lock_or_recover(pipeline_state).take(&key);

    match bg {
        Some(mut bg) => {
            let _ = snapshot_named_request(&bg.pipeline_root_dir, "full_request.json", request);
            append_pipeline_log(
                &bg.pipeline_root_dir,
                &format!(
                    "full start request_id={} key={} sandbox_dir={:?} outputs_before_wait={:?}",
                    request.request_id,
                    key,
                    request.sandbox_dir,
                    list_regular_files(&bg.pipeline_output_dir)
                ),
            );
            let full_base = request
                .sandbox_dir
                .as_ref()
                .map(PathBuf::from)
                .or_else(|| std::env::current_dir().ok())
                .unwrap_or_else(|| PathBuf::from("."));
            append_request_input_state_log(
                &bg.pipeline_root_dir,
                "full request input",
                request,
                |path| resolve_relative_to(path, &full_base),
            );
            // Join the drain thread first (avoids deadlock: child blocks on stderr
            // write if the pipe buffer fills up before we drain it).
            let remaining = bg.stderr_drain.join().unwrap_or_default();
            let all_diagnostics = bg.diagnostics_before + &remaining;

            match bg.child.wait() {
                Ok(status) => {
                    let exit_code = status.code().unwrap_or(1);
                    let staged_outputs = list_regular_files(&bg.pipeline_output_dir);
                    append_pipeline_log(
                        &bg.pipeline_root_dir,
                        &format!(
                            "full child finished exit_code={exit_code} staged_outputs={staged_outputs:?}"
                        ),
                    );
                    if exit_code == 0 {
                        // Copy all outputs from the persistent pipeline dir.
                        match request.sandbox_dir.as_ref() {
                            Some(dir) => {
                                let copy_start = Instant::now();
                                let copy_stats = copy_all_outputs_to_sandbox(
                                    &bg.pipeline_output_dir,
                                    dir,
                                    &bg.original_out_dir,
                                );
                                let dest_dir = std::path::Path::new(dir).join(&bg.original_out_dir);
                                append_pipeline_log(
                                    &bg.pipeline_root_dir,
                                    &format!(
                                        "full copied outputs into sandbox dir {}; files={} hardlinks={} copies={} materialize_ms={} dest_files={:?}",
                                        dest_dir.display(),
                                        copy_stats.files,
                                        copy_stats.hardlinked_files,
                                        copy_stats.copied_files,
                                        copy_start.elapsed().as_millis(),
                                        list_regular_files(&dest_dir)
                                    ),
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
                                                let _ = std::fs::copy(entry.path(), &dest);
                                            }
                                        }
                                    }
                                }
                                append_pipeline_log(
                                    &bg.pipeline_root_dir,
                                    &format!(
                                        "full copied outputs into execroot dir {}; dest_files={:?}",
                                        dest_dir.display(),
                                        list_regular_files(dest_dir)
                                    ),
                                );
                            }
                        }
                    }
                    maybe_cleanup_pipeline_dir(
                        &bg.pipeline_root_dir,
                        should_preserve_pipeline_dir(&key, exit_code, &staged_outputs),
                        "full action failed or missing .rlib in staged outputs",
                    );
                    (exit_code, all_diagnostics)
                }
                Err(e) => (1, format!("failed to wait for background rustc: {e}")),
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
            match request.sandbox_dir.as_ref() {
                Some(ref dir) => run_sandboxed_request(self_path, filtered_args, dir)
                    .unwrap_or_else(|e| (1, format!("pipelining fallback error: {e}"))),
                None => {
                    prepare_outputs(&filtered_args);
                    run_request(self_path, filtered_args)
                        .unwrap_or_else(|e| (1, format!("pipelining fallback error: {e}")))
                }
            }
        }
    }
}

/// Strips pipelining protocol flags from a direct arg list.
///
/// Used for the full-action fallback path (where pipelining flags may appear
/// in direct args if no @paramfile was used). When flags are in a @paramfile,
/// `options.rs` `prepare_param_file` handles stripping during expansion.
fn strip_pipelining_flags(args: &[String]) -> Vec<String> {
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
fn relocate_pw_flags(args: &mut Vec<String>) {
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

/// Applies substitution mappings to a single argument string.
fn apply_substs(arg: &str, subst: &[(String, String)]) -> String {
    let mut a = arg.to_owned();
    for (k, v) in subst {
        a = a.replace(&format!("${{{k}}}"), v);
    }
    a
}

/// Builds the rustc argument list from the post-`--` section of process_wrapper
/// args, expanding any @paramfile references inline and stripping pipelining flags.
///
/// Rustc natively supports @paramfile expansion, but the paramfile may contain
/// pipelining protocol flags (`--pipelining-metadata`, `--pipelining-key=*`) that
/// rustc doesn't understand. By expanding and filtering here we avoid passing
/// unknown flags to rustc.
fn expand_rustc_args(
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
                            result.push(line);
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
            result.push(arg);
        }
    }
    result
}

// ---------------------------------------------------------------------------
// Sandbox helpers
// ---------------------------------------------------------------------------

/// Extracts the `sandboxDir` field from a WorkRequest.
fn extract_sandbox_dir(request: &JsonValue) -> Option<String> {
    if let JsonValue::Object(map) = request {
        if let Some(JsonValue::String(dir)) = map.get("sandboxDir") {
            return Some(dir.clone());
        }
    }
    None
}

/// Extracts the `inputs` array from a WorkRequest.
fn extract_inputs(request: &JsonValue) -> Vec<WorkRequestInput> {
    let mut result = Vec::new();
    let JsonValue::Object(map) = request else {
        return result;
    };
    let Some(JsonValue::Array(inputs)) = map.get("inputs") else {
        return result;
    };

    for input in inputs {
        let JsonValue::Object(obj) = input else {
            continue;
        };

        let path = obj.get("path").and_then(|value| match value {
            JsonValue::String(path) => Some(path.clone()),
            _ => None,
        });
        let digest = obj.get("digest").and_then(|value| match value {
            JsonValue::String(digest) => Some(digest.clone()),
            _ => None,
        });

        if let Some(path) = path {
            result.push(WorkRequestInput { path, digest });
        }
    }

    result
}

/// Extracts the `cancel` field from a WorkRequest (false if absent).
fn extract_cancel(request: &JsonValue) -> bool {
    if let JsonValue::Object(map) = request {
        if let Some(JsonValue::Boolean(cancel)) = map.get("cancel") {
            return *cancel;
        }
    }
    false
}

/// Kills the background rustc process associated with a cancelled request.
///
/// Looks up the pipeline key by metadata_request_id, then kills the child
/// process and joins the stderr drain thread. This prevents wasted CPU when
/// the remote leg wins a dynamic execution race.
fn kill_pipelined_request(
    pipeline_state: &Arc<Mutex<PipelineState>>,
    request_id: i64,
) {
    let mut state = lock_or_recover(pipeline_state);
    let key_to_kill: Option<String> = state.active.iter().find_map(|(key, bg)| {
        if bg.metadata_request_id == request_id {
            Some(key.clone())
        } else {
            None
        }
    });
    if let Some(key) = key_to_kill {
        if let Some(mut bg) = state.active.remove(&key) {
            append_worker_lifecycle_log(&format!(
                "pid={} event=cancel_kill request_id={} key={}",
                current_pid(),
                request_id,
                key,
            ));
            let _ = bg.child.kill();
            let _ = bg.child.wait(); // reap zombie
            let _ = bg.stderr_drain.join();
        }
    }
}

/// Builds a JSON WorkResponse with `wasCancelled: true`.
fn build_cancel_response(request_id: i64) -> String {
    format!(
        "{{\"exitCode\":0,\"output\":{},\"requestId\":{},\"wasCancelled\":true}}",
        json_string_literal(""),
        request_id
    )
}

fn build_shutdown_response(request_id: i64) -> String {
    build_response(1, "worker shutting down", request_id)
}

fn snapshot_request_context(
    state_roots: &WorkerStateRoots,
    request: &WorkRequestContext,
) -> Result<(), ProcessWrapperError> {
    let request_dir = state_roots.request_dir(request.request_id);
    std::fs::create_dir_all(&request_dir)
        .map_err(|e| ProcessWrapperError(format!("failed to create worker request dir: {e}")))?;
    let snapshot = build_request_snapshot(request);
    std::fs::write(request_dir.join("request.json"), snapshot).map_err(|e| {
        ProcessWrapperError(format!("failed to write worker request snapshot: {e}"))
    })?;
    Ok(())
}

fn build_request_snapshot(request: &WorkRequestContext) -> String {
    let mut fields = HashMap::new();
    fields.insert(
        "requestId".to_string(),
        JsonValue::Number(request.request_id as f64),
    );
    fields.insert(
        "arguments".to_string(),
        JsonValue::Array(
            request
                .arguments
                .iter()
                .cloned()
                .map(JsonValue::String)
                .collect(),
        ),
    );
    if let Some(sandbox_dir) = &request.sandbox_dir {
        fields.insert(
            "sandboxDir".to_string(),
            JsonValue::String(sandbox_dir.clone()),
        );
    }
    fields.insert("cancel".to_string(), JsonValue::Boolean(request.cancel));
    fields.insert(
        "inputs".to_string(),
        JsonValue::Array(
            request
                .inputs
                .iter()
                .map(|input| {
                    let mut input_fields = HashMap::new();
                    input_fields.insert("path".to_string(), JsonValue::String(input.path.clone()));
                    if let Some(digest) = &input.digest {
                        input_fields
                            .insert("digest".to_string(), JsonValue::String(digest.clone()));
                    }
                    JsonValue::Object(input_fields)
                })
                .collect(),
        ),
    );
    JsonValue::Object(fields)
        .stringify()
        .unwrap_or_else(|_| "{}".to_string())
}

/// Like `run_request` but sets `current_dir(sandbox_dir)` on the subprocess.
///
/// When Bazel provides a `sandboxDir`, setting the subprocess CWD to it makes
/// all relative paths in arguments resolve correctly within the sandbox.
fn run_sandboxed_request(
    self_path: &std::path::Path,
    arguments: Vec<String>,
    sandbox_dir: &str,
) -> Result<(i32, String), ProcessWrapperError> {
    let _ = seed_sandbox_cache_root(std::path::Path::new(sandbox_dir));
    let output = Command::new(self_path)
        .args(&arguments)
        .current_dir(sandbox_dir)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .map_err(|e| ProcessWrapperError(format!("failed to spawn sandboxed subprocess: {e}")))?;

    let exit_code = output.status.code().unwrap_or(1);
    let mut combined = String::from_utf8_lossy(&output.stdout).into_owned();
    combined.push_str(&String::from_utf8_lossy(&output.stderr));
    Ok((exit_code, combined))
}

/// Resolves `path` relative to `sandbox_dir` if it is not absolute.
fn resolve_sandbox_path(path: &str, sandbox_dir: &str) -> String {
    let p = std::path::Path::new(path);
    if p.is_absolute() {
        path.to_string()
    } else {
        std::path::Path::new(sandbox_dir)
            .join(p)
            .to_string_lossy()
            .into_owned()
    }
}

/// Like `prepare_outputs` but resolves relative `--out-dir` paths against
/// `sandbox_dir` before making files writable.
fn prepare_outputs_sandboxed(args: &[String], sandbox_dir: &str) {
    let mut out_dirs: Vec<String> = Vec::new();

    let mut i = 0;
    while i < args.len() {
        let arg = &args[i];
        if let Some(dir) = arg.strip_prefix("--out-dir=") {
            out_dirs.push(resolve_sandbox_path(dir, sandbox_dir));
        } else if let Some(flagfile_path) = arg.strip_prefix('@') {
            scan_file_for_out_dir_sandboxed(flagfile_path, sandbox_dir, &mut out_dirs);
        } else if arg == "--arg-file" {
            if let Some(path) = args.get(i + 1) {
                scan_file_for_out_dir_sandboxed(path, sandbox_dir, &mut out_dirs);
                i += 1;
            }
        }
        i += 1;
    }

    for out_dir in out_dirs {
        make_dir_files_writable(&out_dir);
        let pipeline_dir = format!("{out_dir}/_pipeline");
        make_dir_files_writable(&pipeline_dir);
    }
}

/// Like `scan_file_for_out_dir` but resolves found paths against `sandbox_dir`.
fn scan_file_for_out_dir_sandboxed(path: &str, sandbox_dir: &str, out_dirs: &mut Vec<String>) {
    let Ok(content) = std::fs::read_to_string(path) else {
        return;
    };
    for line in content.lines() {
        if let Some(dir) = line.strip_prefix("--out-dir=") {
            out_dirs.push(resolve_sandbox_path(dir, sandbox_dir));
        }
    }
}

/// Searches already-expanded rustc args for `--out-dir=<path>`.
fn find_out_dir_in_expanded(args: &[String]) -> Option<String> {
    for arg in args {
        if let Some(dir) = arg.strip_prefix("--out-dir=") {
            return Some(dir.to_string());
        }
    }
    None
}

/// Returns a copy of `args` where `--out-dir=<old>` is replaced by
/// `--out-dir=<new_out_dir>`. Other args are unchanged.
/// Rewrites `--emit=metadata=<path>` to write the .rmeta into the pipeline outputs dir.
/// The original relative path's filename is preserved; only the directory changes.
fn rewrite_emit_metadata_path(args: Vec<String>, outputs_dir: &std::path::Path) -> Vec<String> {
    args.into_iter()
        .map(|arg| {
            if let Some(path_str) = arg.strip_prefix("--emit=metadata=") {
                let filename = std::path::Path::new(path_str)
                    .file_name()
                    .unwrap_or_default()
                    .to_string_lossy();
                format!("--emit=metadata={}", outputs_dir.join(filename.as_ref()).display())
            } else {
                arg
            }
        })
        .collect()
}

fn rewrite_out_dir_in_expanded(args: Vec<String>, new_out_dir: &std::path::Path) -> Vec<String> {
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

/// Copies the file at `src` into `<sandbox_dir>/<original_out_dir>/<dest_subdir>/`.
///
/// Used after the metadata action to make the `.rmeta` file visible to Bazel
/// inside the sandbox before the sandbox is cleaned up.
fn copy_output_to_sandbox(
    src: &str,
    sandbox_dir: &str,
    original_out_dir: &str,
    dest_subdir: &str,
) -> OutputMaterializationStats {
    let mut stats = OutputMaterializationStats::default();
    let src_path = std::path::Path::new(src);
    let filename = match src_path.file_name() {
        Some(n) => n,
        None => return stats,
    };
    let dest_dir = std::path::Path::new(sandbox_dir)
        .join(original_out_dir)
        .join(dest_subdir);
    if let Ok(hardlinked) = materialize_output_file(src_path, &dest_dir.join(filename)) {
        stats.files = 1;
        if hardlinked {
            stats.hardlinked_files = 1;
        } else {
            stats.copied_files = 1;
        }
    }
    stats
}

/// Copies all regular files from `pipeline_dir` into `<sandbox_dir>/<original_out_dir>/`.
///
/// Used by the full action to move the `.rlib` (and `.d`, etc.) from the
/// persistent directory into the sandbox before responding to Bazel.
fn copy_all_outputs_to_sandbox(
    pipeline_dir: &PathBuf,
    sandbox_dir: &str,
    original_out_dir: &str,
) -> OutputMaterializationStats {
    let dest_dir = std::path::Path::new(sandbox_dir).join(original_out_dir);
    let mut stats = OutputMaterializationStats::default();
    if let Ok(entries) = std::fs::read_dir(pipeline_dir) {
        for entry in entries.flatten() {
            if let Ok(meta) = entry.metadata() {
                if meta.is_file() {
                    if let Ok(hardlinked) =
                        materialize_output_file(&entry.path(), &dest_dir.join(entry.file_name()))
                    {
                        stats.files += 1;
                        if hardlinked {
                            stats.hardlinked_files += 1;
                        } else {
                            stats.copied_files += 1;
                        }
                    }
                }
            }
        }
    }
    stats
}

// ---------------------------------------------------------------------------
// Core worker helpers (unchanged from singleplex implementation)
// ---------------------------------------------------------------------------

/// Extracts the `requestId` field from a WorkRequest (defaults to 0).
fn extract_request_id(request: &JsonValue) -> i64 {
    if let JsonValue::Object(map) = request {
        if let Some(JsonValue::Number(id)) = map.get("requestId") {
            return *id as i64;
        }
    }
    0
}

/// Extracts the `arguments` array from a WorkRequest.
fn extract_arguments(request: &JsonValue) -> Vec<String> {
    if let JsonValue::Object(map) = request {
        if let Some(JsonValue::Array(args)) = map.get("arguments") {
            return args
                .iter()
                .filter_map(|v| {
                    if let JsonValue::String(s) = v {
                        Some(s.clone())
                    } else {
                        None
                    }
                })
                .collect();
        }
    }
    vec![]
}

/// Executes a single WorkRequest by spawning process_wrapper with the given
/// arguments. Returns (exit_code, combined_output).
///
/// The spawned process runs with the worker's environment and working directory
/// (Bazel's execroot), so incremental compilation caches see stable paths.
fn run_request(
    self_path: &std::path::Path,
    arguments: Vec<String>,
) -> Result<(i32, String), ProcessWrapperError> {
    let output = Command::new(self_path)
        .args(&arguments)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .map_err(|e| {
            ProcessWrapperError(format!("failed to spawn process_wrapper subprocess: {e}"))
        })?;

    let exit_code = output.status.code().unwrap_or(1);

    // Combine stdout and stderr for the WorkResponse output field.
    // process_wrapper normally writes rustc diagnostics to its stderr,
    // so this captures compilation errors/warnings for display in Bazel.
    let mut combined = String::from_utf8_lossy(&output.stdout).into_owned();
    combined.push_str(&String::from_utf8_lossy(&output.stderr));

    Ok((exit_code, combined))
}

/// Ensures output files in rustc's `--out-dir` are writable before each request.
///
/// Workers run in execroot without sandboxing. Bazel marks action outputs
/// read-only after each successful action, and the disk cache hardlinks them
/// as read-only. With pipelined compilation, two separate actions (RustcMetadata
/// and Rustc) both write to the same `.rmeta` path. After the first succeeds,
/// Bazel makes its output read-only; the second worker request then fails with
/// "output file ... is not writeable".
///
/// This function scans `args` for `--out-dir=<dir>` — both inline and inside any
/// `--arg-file <path>` (process_wrapper's own arg-file mechanism) or `@flagfile`
/// (Bazel's param file convention) — and makes all regular files in those
/// directories writable.
fn prepare_outputs(args: &[String]) {
    let mut out_dirs: Vec<String> = Vec::new();

    let mut i = 0;
    while i < args.len() {
        let arg = &args[i];
        if let Some(dir) = arg.strip_prefix("--out-dir=") {
            out_dirs.push(dir.to_string());
        } else if let Some(flagfile_path) = arg.strip_prefix('@') {
            // Bazel @flagfile: one arg per line.
            scan_file_for_out_dir(flagfile_path, &mut out_dirs);
        } else if arg == "--arg-file" {
            // process_wrapper's --arg-file <path>: reads child (rustc) args from file.
            if let Some(path) = args.get(i + 1) {
                scan_file_for_out_dir(path, &mut out_dirs);
                i += 1; // skip the path argument
            }
        }
        i += 1;
    }

    for out_dir in out_dirs {
        make_dir_files_writable(&out_dir);
        // Also make writable any _pipeline/ subdir (worker-pipelining .rmeta files
        // from previous runs may be read-only after Bazel marks outputs immutable).
        let pipeline_dir = format!("{out_dir}/_pipeline");
        make_dir_files_writable(&pipeline_dir);
    }
}

fn make_path_writable(path: &std::path::Path) {
    let Ok(meta) = std::fs::metadata(path) else {
        return;
    };
    if !meta.is_file() {
        return;
    }

    let mut perms = meta.permissions();
    if perms.readonly() {
        perms.set_readonly(false);
        let _ = std::fs::set_permissions(path, perms);
    }
}

fn prepare_expanded_rustc_outputs(args: &[String]) {
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

/// Reads `path` line-by-line, collecting any `--out-dir=<dir>` values.
fn scan_file_for_out_dir(path: &str, out_dirs: &mut Vec<String>) {
    let Ok(content) = std::fs::read_to_string(path) else {
        return;
    };
    for line in content.lines() {
        if let Some(dir) = line.strip_prefix("--out-dir=") {
            out_dirs.push(dir.to_string());
        }
    }
}

/// Makes all regular files in `dir` writable (removes read-only bit).
fn make_dir_files_writable(dir: &str) {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };
    for entry in entries.flatten() {
        if let Ok(meta) = entry.metadata() {
            if meta.is_file() {
                let mut perms = meta.permissions();
                if perms.readonly() {
                    perms.set_readonly(false);
                    let _ = std::fs::set_permissions(entry.path(), perms);
                }
            }
        }
    }
}

/// Builds a JSON WorkResponse string.
fn build_response(exit_code: i32, output: &str, request_id: i64) -> String {
    let output = if exit_code == 0 {
        String::new()
    } else {
        sanitize_response_output(output)
    };
    format!(
        "{{\"exitCode\":{},\"output\":{},\"requestId\":{}}}",
        exit_code,
        json_string_literal(&output),
        request_id
    )
}

fn sanitize_response_output(output: &str) -> String {
    output
        .chars()
        .map(|ch| match ch {
            '\n' | '\r' | '\t' => ch,
            ch if ch.is_control() => ' ',
            ch => ch,
        })
        .collect()
}

fn json_string_literal(value: &str) -> String {
    JsonValue::String(value.to_owned())
        .stringify()
        .unwrap_or_else(|_| "\"\"".to_string())
}

#[cfg(test)]
mod test {
    use super::*;

    fn parse_json(s: &str) -> JsonValue {
        s.parse().unwrap()
    }

    #[test]
    fn test_extract_request_id_present() {
        let req = parse_json(r#"{"requestId": 42, "arguments": []}"#);
        assert_eq!(extract_request_id(&req), 42);
    }

    #[test]
    fn test_extract_request_id_missing() {
        let req = parse_json(r#"{"arguments": []}"#);
        assert_eq!(extract_request_id(&req), 0);
    }

    #[test]
    fn test_extract_arguments() {
        let req =
            parse_json(r#"{"requestId": 0, "arguments": ["--subst", "pwd=/work", "--", "rustc"]}"#);
        assert_eq!(
            extract_arguments(&req),
            vec!["--subst", "pwd=/work", "--", "rustc"]
        );
    }

    #[test]
    fn test_extract_arguments_empty() {
        let req = parse_json(r#"{"requestId": 0, "arguments": []}"#);
        assert_eq!(extract_arguments(&req), Vec::<String>::new());
    }

    #[test]
    fn test_build_response_sanitizes_control_characters() {
        let response = build_response(1, "hello\u{0}world\u{7}", 9);
        let parsed = parse_json(&response);
        let JsonValue::Object(map) = parsed else {
            panic!("expected object response");
        };
        let Some(JsonValue::String(output)) = map.get("output") else {
            panic!("expected string output");
        };
        assert_eq!(output, "hello world ");
    }

    #[test]
    #[cfg(unix)]
    fn test_prepare_outputs_inline_out_dir() {
        use std::fs;
        use std::os::unix::fs::PermissionsExt;

        let dir = std::env::temp_dir().join("pw_test_prepare_inline");
        fs::create_dir_all(&dir).unwrap();
        let file_path = dir.join("libfoo.rmeta");
        fs::write(&file_path, b"content").unwrap();

        let mut perms = fs::metadata(&file_path).unwrap().permissions();
        perms.set_mode(0o444);
        fs::set_permissions(&file_path, perms).unwrap();
        assert!(fs::metadata(&file_path).unwrap().permissions().readonly());

        let args = vec![format!("--out-dir={}", dir.display())];
        prepare_outputs(&args);

        assert!(!fs::metadata(&file_path).unwrap().permissions().readonly());
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    #[cfg(unix)]
    fn test_prepare_outputs_arg_file() {
        use std::fs;
        use std::os::unix::fs::PermissionsExt;

        let tmp = std::env::temp_dir().join("pw_test_prepare_argfile");
        fs::create_dir_all(&tmp).unwrap();

        // Create the output dir and a read-only file in it.
        let out_dir = tmp.join("out");
        fs::create_dir_all(&out_dir).unwrap();
        let file_path = out_dir.join("libfoo.rmeta");
        fs::write(&file_path, b"content").unwrap();
        let mut perms = fs::metadata(&file_path).unwrap().permissions();
        perms.set_mode(0o444);
        fs::set_permissions(&file_path, perms).unwrap();
        assert!(fs::metadata(&file_path).unwrap().permissions().readonly());

        // Write an --arg-file containing --out-dir.
        let arg_file = tmp.join("rustc.params");
        fs::write(
            &arg_file,
            format!("--out-dir={}\n--crate-name=foo\n", out_dir.display()),
        )
        .unwrap();

        let args = vec!["--arg-file".to_string(), arg_file.display().to_string()];
        prepare_outputs(&args);

        assert!(!fs::metadata(&file_path).unwrap().permissions().readonly());
        let _ = fs::remove_dir_all(&tmp);
    }

    #[test]
    #[cfg(unix)]
    fn test_prepare_expanded_rustc_outputs_emit_path() {
        use std::fs;
        use std::os::unix::fs::PermissionsExt;

        let tmp = std::env::temp_dir().join("pw_test_prepare_emit_path");
        fs::create_dir_all(&tmp).unwrap();

        let emit_path = tmp.join("libfoo.rmeta");
        fs::write(&emit_path, b"content").unwrap();
        let mut perms = fs::metadata(&emit_path).unwrap().permissions();
        perms.set_mode(0o555);
        fs::set_permissions(&emit_path, perms).unwrap();
        assert!(fs::metadata(&emit_path).unwrap().permissions().readonly());

        let args = vec![format!("--emit=metadata={}", emit_path.display())];
        prepare_expanded_rustc_outputs(&args);

        assert!(!fs::metadata(&emit_path).unwrap().permissions().readonly());
        let _ = fs::remove_dir_all(&tmp);
    }

    #[test]
    fn test_build_response_success() {
        let response = build_response(0, "", 0);
        assert_eq!(response, r#"{"exitCode":0,"output":"","requestId":0}"#);
        let parsed = parse_json(&response);
        if let JsonValue::Object(map) = parsed {
            assert!(matches!(map.get("exitCode"), Some(JsonValue::Number(n)) if *n == 0.0));
            assert!(matches!(map.get("requestId"), Some(JsonValue::Number(n)) if *n == 0.0));
        } else {
            panic!("expected object");
        }
    }

    #[test]
    fn test_build_response_failure() {
        let response = build_response(1, "error: type mismatch", 0);
        let parsed = parse_json(&response);
        if let JsonValue::Object(map) = parsed {
            assert!(matches!(map.get("exitCode"), Some(JsonValue::Number(n)) if *n == 1.0));
            assert!(
                matches!(map.get("output"), Some(JsonValue::String(s)) if s == "error: type mismatch")
            );
        } else {
            panic!("expected object");
        }
    }

    #[test]
    fn test_detect_pipelining_mode_none() {
        let args = vec!["--subst".to_string(), "pwd=/work".to_string()];
        assert!(matches!(
            detect_pipelining_mode(&args),
            PipeliningMode::None
        ));
    }

    #[test]
    fn test_detect_pipelining_mode_metadata() {
        let args = vec![
            "--pipelining-metadata".to_string(),
            "--pipelining-key=my_crate_abc123".to_string(),
        ];
        match detect_pipelining_mode(&args) {
            PipeliningMode::Metadata { key } => assert_eq!(key, "my_crate_abc123"),
            other => panic!(
                "expected Metadata, got {:?}",
                std::mem::discriminant(&other)
            ),
        }
    }

    #[test]
    fn test_detect_pipelining_mode_full() {
        let args = vec![
            "--pipelining-full".to_string(),
            "--pipelining-key=my_crate_abc123".to_string(),
        ];
        match detect_pipelining_mode(&args) {
            PipeliningMode::Full { key } => assert_eq!(key, "my_crate_abc123"),
            other => panic!("expected Full, got {:?}", std::mem::discriminant(&other)),
        }
    }

    #[test]
    fn test_detect_pipelining_mode_no_key() {
        // If pipelining flag present but no key, fall back to None.
        let args = vec!["--pipelining-metadata".to_string()];
        assert!(matches!(
            detect_pipelining_mode(&args),
            PipeliningMode::None
        ));
    }

    #[test]
    fn test_strip_pipelining_flags() {
        let args = vec![
            "--pipelining-metadata".to_string(),
            "--pipelining-key=my_crate_abc123".to_string(),
            "--arg-file".to_string(),
            "rustc.params".to_string(),
        ];
        let filtered = strip_pipelining_flags(&args);
        assert_eq!(filtered, vec!["--arg-file", "rustc.params"]);
    }

    #[test]
    fn test_pipeline_state_store_take() {
        let mut state = PipelineState::new();
        // Verify that take on an empty state returns None.
        assert!(state.take("nonexistent").is_none());
    }

    // --- Tests for new helpers added in the worker-key fix ---

    #[test]
    fn test_is_pipelining_flag() {
        assert!(is_pipelining_flag("--pipelining-metadata"));
        assert!(is_pipelining_flag("--pipelining-full"));
        assert!(is_pipelining_flag("--pipelining-key=foo_abc"));
        assert!(!is_pipelining_flag("--crate-name=foo"));
        assert!(!is_pipelining_flag("--emit=dep-info,metadata,link"));
        assert!(!is_pipelining_flag("-Zno-codegen"));
    }

    #[test]
    fn test_apply_substs() {
        let subst = vec![
            ("pwd".to_string(), "/work".to_string()),
            ("out".to_string(), "bazel-out/k8/bin".to_string()),
        ];
        assert_eq!(apply_substs("${pwd}/src", &subst), "/work/src");
        assert_eq!(
            apply_substs("${out}/foo.rlib", &subst),
            "bazel-out/k8/bin/foo.rlib"
        );
        assert_eq!(apply_substs("--crate-name=foo", &subst), "--crate-name=foo");
    }

    #[test]
    fn test_scan_pipelining_flags_metadata() {
        let (is_metadata, is_full, key) = scan_pipelining_flags(
            ["--pipelining-metadata", "--pipelining-key=foo_abc"]
                .iter()
                .copied(),
        );
        assert!(is_metadata);
        assert!(!is_full);
        assert_eq!(key, Some("foo_abc".to_string()));
    }

    #[test]
    fn test_scan_pipelining_flags_full() {
        let (is_metadata, is_full, key) = scan_pipelining_flags(
            ["--pipelining-full", "--pipelining-key=bar_xyz"]
                .iter()
                .copied(),
        );
        assert!(!is_metadata);
        assert!(is_full);
        assert_eq!(key, Some("bar_xyz".to_string()));
    }

    #[test]
    fn test_scan_pipelining_flags_none() {
        let (is_metadata, is_full, key) =
            scan_pipelining_flags(["--emit=link", "--crate-name=foo"].iter().copied());
        assert!(!is_metadata);
        assert!(!is_full);
        assert_eq!(key, None);
    }

    #[test]
    fn test_detect_pipelining_mode_from_paramfile() {
        use std::io::Write;
        // Write a temporary paramfile with pipelining flags.
        let tmp = std::env::temp_dir().join("pw_test_detect_paramfile");
        let param_path = tmp.join("rustc.params");
        std::fs::create_dir_all(&tmp).unwrap();
        let mut f = std::fs::File::create(&param_path).unwrap();
        writeln!(f, "--emit=dep-info,metadata,link").unwrap();
        writeln!(f, "--crate-name=foo").unwrap();
        writeln!(f, "--pipelining-metadata").unwrap();
        writeln!(f, "--pipelining-key=foo_abc123").unwrap();
        drop(f);

        // Full args: startup args before "--", then rustc + @paramfile.
        let args = vec![
            "--subst".to_string(),
            "pwd=/work".to_string(),
            "--".to_string(),
            "/path/to/rustc".to_string(),
            format!("@{}", param_path.display()),
        ];

        match detect_pipelining_mode(&args) {
            PipeliningMode::Metadata { key } => assert_eq!(key, "foo_abc123"),
            other => panic!(
                "expected Metadata, got {:?}",
                std::mem::discriminant(&other)
            ),
        }

        let _ = std::fs::remove_dir_all(&tmp);
    }

    #[test]
    fn test_expand_rustc_args_strips_pipelining_flags() {
        use std::io::Write;
        let tmp = std::env::temp_dir().join("pw_test_expand_rustc");
        let param_path = tmp.join("rustc.params");
        std::fs::create_dir_all(&tmp).unwrap();
        let mut f = std::fs::File::create(&param_path).unwrap();
        writeln!(f, "--emit=dep-info,metadata,link").unwrap();
        writeln!(f, "--crate-name=foo").unwrap();
        writeln!(f, "--pipelining-metadata").unwrap();
        writeln!(f, "--pipelining-key=foo_abc123").unwrap();
        drop(f);

        let rustc_and_after = vec![
            "/path/to/rustc".to_string(),
            format!("@{}", param_path.display()),
        ];
        let subst: Vec<(String, String)> = vec![];
        let expanded = expand_rustc_args(&rustc_and_after, &subst, std::path::Path::new("."));

        assert_eq!(expanded[0], "/path/to/rustc");
        assert!(expanded.contains(&"--emit=dep-info,metadata,link".to_string()));
        assert!(expanded.contains(&"--crate-name=foo".to_string()));
        // Pipelining flags must be stripped.
        assert!(!expanded.contains(&"--pipelining-metadata".to_string()));
        assert!(!expanded.iter().any(|a| a.starts_with("--pipelining-key=")));

        let _ = std::fs::remove_dir_all(&tmp);
    }

    #[test]
    fn test_expand_rustc_args_applies_substs() {
        use std::io::Write;
        let tmp = std::env::temp_dir().join("pw_test_expand_subst");
        let param_path = tmp.join("rustc.params");
        std::fs::create_dir_all(&tmp).unwrap();
        let mut f = std::fs::File::create(&param_path).unwrap();
        writeln!(f, "--out-dir=${{pwd}}/out").unwrap();
        drop(f);

        let rustc_and_after = vec![
            "/path/to/rustc".to_string(),
            format!("@{}", param_path.display()),
        ];
        let subst = vec![("pwd".to_string(), "/work".to_string())];
        let expanded = expand_rustc_args(&rustc_and_after, &subst, std::path::Path::new("."));

        assert!(
            expanded.contains(&"--out-dir=/work/out".to_string()),
            "expected substituted arg, got: {:?}",
            expanded
        );

        let _ = std::fs::remove_dir_all(&tmp);
    }

    // --- Tests for Phase 4 sandbox helpers ---

    #[test]
    fn test_extract_sandbox_dir_present() {
        let req = parse_json(r#"{"requestId": 1, "sandboxDir": "/tmp/sandbox/42"}"#);
        assert_eq!(
            extract_sandbox_dir(&req),
            Some("/tmp/sandbox/42".to_string())
        );
    }

    #[test]
    fn test_extract_sandbox_dir_absent() {
        let req = parse_json(r#"{"requestId": 1}"#);
        assert_eq!(extract_sandbox_dir(&req), None);
    }

    #[test]
    fn test_extract_inputs() {
        let req = parse_json(
            r#"{
                "requestId": 1,
                "inputs": [
                    {"path": "foo/bar.rs", "digest": "abc"},
                    {"path": "flagfile.params"}
                ]
            }"#,
        );
        assert_eq!(
            extract_inputs(&req),
            vec![
                WorkRequestInput {
                    path: "foo/bar.rs".to_string(),
                    digest: Some("abc".to_string()),
                },
                WorkRequestInput {
                    path: "flagfile.params".to_string(),
                    digest: None,
                },
            ]
        );
    }

    #[test]
    fn test_extract_cancel_true() {
        let req = parse_json(r#"{"requestId": 1, "cancel": true}"#);
        assert!(extract_cancel(&req));
    }

    #[test]
    fn test_extract_cancel_false() {
        let req = parse_json(r#"{"requestId": 1, "cancel": false}"#);
        assert!(!extract_cancel(&req));
    }

    #[test]
    fn test_extract_cancel_absent() {
        let req = parse_json(r#"{"requestId": 1}"#);
        assert!(!extract_cancel(&req));
    }

    #[test]
    fn test_build_cancel_response() {
        let response = build_cancel_response(7);
        assert_eq!(
            response,
            r#"{"exitCode":0,"output":"","requestId":7,"wasCancelled":true}"#
        );
        let parsed = parse_json(&response);
        if let JsonValue::Object(map) = parsed {
            assert!(matches!(map.get("requestId"), Some(JsonValue::Number(n)) if *n == 7.0));
            assert!(matches!(map.get("exitCode"), Some(JsonValue::Number(n)) if *n == 0.0));
            assert!(matches!(
                map.get("wasCancelled"),
                Some(JsonValue::Boolean(true))
            ));
        } else {
            panic!("expected object");
        }
    }

    #[test]
    fn test_resolve_sandbox_path_relative() {
        let result = resolve_sandbox_path("bazel-out/k8/bin/pkg", "/sandbox/42");
        assert_eq!(result, "/sandbox/42/bazel-out/k8/bin/pkg");
    }

    #[test]
    fn test_resolve_sandbox_path_absolute() {
        let result = resolve_sandbox_path("/absolute/path/out", "/sandbox/42");
        assert_eq!(result, "/absolute/path/out");
    }

    #[test]
    fn test_find_out_dir_in_expanded() {
        let args = vec![
            "--crate-name=foo".to_string(),
            "--out-dir=/work/bazel-out/k8/bin/pkg".to_string(),
            "--emit=link".to_string(),
        ];
        assert_eq!(
            find_out_dir_in_expanded(&args),
            Some("/work/bazel-out/k8/bin/pkg".to_string())
        );
    }

    #[test]
    fn test_find_out_dir_in_expanded_missing() {
        let args = vec!["--crate-name=foo".to_string(), "--emit=link".to_string()];
        assert_eq!(find_out_dir_in_expanded(&args), None);
    }

    #[test]
    fn test_rewrite_out_dir_in_expanded() {
        let args = vec![
            "--crate-name=foo".to_string(),
            "--out-dir=/old/path".to_string(),
            "--emit=link".to_string(),
        ];
        let new_dir = std::path::Path::new("/_pw_pipeline/foo_abc");
        let result = rewrite_out_dir_in_expanded(args, new_dir);
        assert_eq!(
            result,
            vec![
                "--crate-name=foo",
                "--out-dir=/_pw_pipeline/foo_abc",
                "--emit=link",
            ]
        );
    }

    #[test]
    fn test_parse_pw_args_substitutes_pwd_from_real_execroot() {
        let parsed = parse_pw_args(
            &[
                "--subst".to_string(),
                "pwd=${pwd}".to_string(),
                "--output-file".to_string(),
                "diag.txt".to_string(),
            ],
            std::path::Path::new("/real/execroot"),
        );

        assert_eq!(
            parsed.subst,
            vec![("pwd".to_string(), "/real/execroot".to_string())]
        );
        assert_eq!(parsed.output_file, Some("diag.txt".to_string()));
        assert_eq!(parsed.stable_status_file, None);
        assert_eq!(parsed.volatile_status_file, None);
    }

    #[test]
    fn test_build_rustc_env_applies_stamp_and_subst_mappings() {
        let tmp =
            std::env::temp_dir().join(format!("pw_test_build_rustc_env_{}", std::process::id()));
        std::fs::create_dir_all(&tmp).unwrap();

        let env_file = tmp.join("env.txt");
        let stable_status = tmp.join("stable-status.txt");
        let volatile_status = tmp.join("volatile-status.txt");

        std::fs::write(
            &env_file,
            "STAMPED={BUILD_USER}:{BUILD_SCM_REVISION}:${pwd}\nUNCHANGED=value\n",
        )
        .unwrap();
        std::fs::write(&stable_status, "BUILD_USER alice\n").unwrap();
        std::fs::write(&volatile_status, "BUILD_SCM_REVISION deadbeef\n").unwrap();

        let env = build_rustc_env(
            &[env_file.display().to_string()],
            Some(stable_status.to_str().unwrap()),
            Some(volatile_status.to_str().unwrap()),
            &[("pwd".to_string(), "/real/execroot".to_string())],
        );

        assert_eq!(
            env.get("STAMPED"),
            Some(&"alice:deadbeef:/real/execroot".to_string())
        );
        assert_eq!(env.get("UNCHANGED"), Some(&"value".to_string()));

        let _ = std::fs::remove_dir_all(&tmp);
    }

    #[test]
    fn test_is_tracked_artifact_input() {
        assert!(is_tracked_artifact_input(
            "bazel-out/k8-fastbuild/bin/lib/foo/_pipeline/libfoo.rmeta"
        ));
        assert!(is_tracked_artifact_input(
            "bazel-out/k8-fastbuild/bin/tools/foo/libfoo.rlib"
        ));
        assert!(!is_tracked_artifact_input("src/main.rs"));
    }

    #[test]
    fn test_collect_rustc_extern_specs() {
        let args = vec![
            "rustc".to_string(),
            "--extern=foo=bazel-out/k8-fastbuild/bin/lib/foo/libfoo.rlib".to_string(),
            "--extern".to_string(),
            "bar=bazel-out/k8-fastbuild/bin/lib/bar/_pipeline/libbar.rmeta".to_string(),
        ];

        assert_eq!(
            collect_rustc_extern_specs(&args),
            vec![
                (
                    "foo".to_string(),
                    "bazel-out/k8-fastbuild/bin/lib/foo/libfoo.rlib".to_string()
                ),
                (
                    "bar".to_string(),
                    "bazel-out/k8-fastbuild/bin/lib/bar/_pipeline/libbar.rmeta".to_string()
                ),
            ]
        );
    }

    #[test]
    fn test_worker_forced_exit_mode_reads_env() {
        let key = "PROCESS_WRAPPER_TEST_WORKER_MODE";
        let old = std::env::var(key).ok();
        std::env::set_var(key, "exit_after_response");
        assert_eq!(
            worker_forced_exit_mode().as_deref(),
            Some("exit_after_response")
        );
        if let Some(old) = old {
            std::env::set_var(key, old);
        } else {
            std::env::remove_var(key);
        }
    }

    #[test]
    fn test_build_shutdown_response() {
        let response = build_shutdown_response(11);
        assert_eq!(
            response,
            r#"{"exitCode":1,"output":"worker shutting down","requestId":11}"#
        );
    }

    #[test]
    fn test_begin_worker_shutdown_sets_flag() {
        WORKER_SHUTTING_DOWN.store(false, Ordering::SeqCst);
        begin_worker_shutdown("test");
        assert!(worker_is_shutting_down());
        WORKER_SHUTTING_DOWN.store(false, Ordering::SeqCst);
    }

    #[test]
    fn test_extract_rmeta_path_valid() {
        let line = r#"{"artifact":"/work/out/libfoo.rmeta","emit":"metadata"}"#;
        assert_eq!(
            extract_rmeta_path(line),
            Some("/work/out/libfoo.rmeta".to_string())
        );
    }

    #[test]
    fn test_should_preserve_pipeline_dir_for_zerobuf_chain_keys() {
        assert!(should_preserve_pipeline_dir(
            "lib_zerobuf_codegen_libzerobuf_codegen-229785134_rlib",
            0,
            &["libzerobuf_codegen-229785134.rlib".to_string()],
        ));
        assert!(should_preserve_pipeline_dir(
            "lib_cli_config_getter_libcli_config_getter-1472696652_rlib",
            0,
            &["libcli_config_getter-1472696652.rlib".to_string()],
        ));
        assert!(should_preserve_pipeline_dir(
            "lib_platform_version_libplatform_version-1023817015_rlib",
            0,
            &["libplatform_version-1023817015.rlib".to_string()],
        ));
        assert!(should_preserve_pipeline_dir(
            "lib_zerobuf_cli_libzerobuf_cli-630641045_rlib",
            0,
            &["libzerobuf_cli-630641045.rlib".to_string()],
        ));
        assert!(!should_preserve_pipeline_dir(
            "lib_other_libother-123_rlib",
            0,
            &["libother-123.rlib".to_string()],
        ));
    }

    #[test]
    fn test_extract_rmeta_path_rlib() {
        // rlib artifact should not match (only rmeta)
        let line = r#"{"artifact":"/work/out/libfoo.rlib","emit":"link"}"#;
        assert_eq!(extract_rmeta_path(line), None);
    }

    #[test]
    #[cfg(unix)]
    fn test_copy_output_to_sandbox() {
        use std::fs;

        let tmp = std::env::temp_dir().join("pw_test_copy_to_sandbox");
        let pipeline_dir = tmp.join("pipeline");
        let sandbox_dir = tmp.join("sandbox");
        let out_rel = "bazel-out/k8/bin/pkg";

        fs::create_dir_all(&pipeline_dir).unwrap();
        fs::create_dir_all(&sandbox_dir).unwrap();

        // Write a fake rmeta into the pipeline dir.
        let rmeta_path = pipeline_dir.join("libfoo.rmeta");
        fs::write(&rmeta_path, b"fake rmeta content").unwrap();

        copy_output_to_sandbox(
            &rmeta_path.display().to_string(),
            &sandbox_dir.display().to_string(),
            out_rel,
            "_pipeline",
        );

        let dest = sandbox_dir
            .join(out_rel)
            .join("_pipeline")
            .join("libfoo.rmeta");
        assert!(dest.exists(), "expected rmeta copied to sandbox/_pipeline/");
        assert_eq!(fs::read(&dest).unwrap(), b"fake rmeta content");

        let _ = fs::remove_dir_all(&tmp);
    }

    #[test]
    #[cfg(unix)]
    fn test_copy_all_outputs_to_sandbox() {
        use std::fs;

        let tmp = std::env::temp_dir().join("pw_test_copy_all_to_sandbox");
        let pipeline_dir = tmp.join("pipeline");
        let sandbox_dir = tmp.join("sandbox");
        let out_rel = "bazel-out/k8/bin/pkg";

        fs::create_dir_all(&pipeline_dir).unwrap();
        fs::create_dir_all(&sandbox_dir).unwrap();

        fs::write(pipeline_dir.join("libfoo.rlib"), b"fake rlib").unwrap();
        fs::write(pipeline_dir.join("libfoo.rmeta"), b"fake rmeta").unwrap();
        fs::write(pipeline_dir.join("libfoo.d"), b"fake dep-info").unwrap();

        copy_all_outputs_to_sandbox(&pipeline_dir, &sandbox_dir.display().to_string(), out_rel);

        let dest = sandbox_dir.join(out_rel);
        assert!(dest.join("libfoo.rlib").exists());
        assert!(dest.join("libfoo.rmeta").exists());
        assert!(dest.join("libfoo.d").exists());

        let _ = fs::remove_dir_all(&tmp);
    }

    #[test]
    #[cfg(unix)]
    fn test_copy_all_outputs_to_sandbox_prefers_hardlinks() {
        use std::fs;
        use std::os::unix::fs::MetadataExt;

        let tmp =
            std::env::temp_dir().join("pw_test_copy_all_outputs_to_sandbox_prefers_hardlinks");
        let pipeline_dir = tmp.join("pipeline");
        let sandbox_dir = tmp.join("sandbox");
        let out_rel = "bazel-out/k8/bin/pkg";

        fs::create_dir_all(&pipeline_dir).unwrap();
        fs::create_dir_all(&sandbox_dir).unwrap();

        let src = pipeline_dir.join("libfoo.rlib");
        fs::write(&src, b"fake rlib").unwrap();

        copy_all_outputs_to_sandbox(&pipeline_dir, &sandbox_dir.display().to_string(), out_rel);

        let dest = sandbox_dir.join(out_rel).join("libfoo.rlib");
        assert!(dest.exists());
        assert_eq!(
            fs::metadata(&src).unwrap().ino(),
            fs::metadata(&dest).unwrap().ino()
        );

        let _ = fs::remove_dir_all(&tmp);
    }

    #[test]
    #[cfg(unix)]
    fn test_seed_sandbox_cache_root() {
        use std::fs;

        let tmp = std::env::temp_dir().join("pw_test_seed_sandbox_cache_root");
        let sandbox_dir = tmp.join("sandbox");
        let cache_repo = tmp.join("cache/repos/v1/contents/hash/repo");
        fs::create_dir_all(&sandbox_dir).unwrap();
        fs::create_dir_all(cache_repo.join("tool/src")).unwrap();
        symlink_path(&cache_repo, &sandbox_dir.join("external_repo"), true).unwrap();

        seed_sandbox_cache_root(&sandbox_dir).unwrap();

        let cache_link = sandbox_dir.join("cache");
        assert!(cache_link.exists());
        assert_eq!(cache_link.canonicalize().unwrap(), tmp.join("cache"));

        let _ = fs::remove_dir_all(&tmp);
    }

    // --- relocate_pw_flags tests ---

    #[test]
    fn test_relocate_pw_flags_moves_output_file_before_separator() {
        let mut args = vec![
            "--subst".into(),
            "pwd=${pwd}".into(),
            "--".into(),
            "/path/to/rustc".into(),
            "--output-file".into(),
            "bazel-out/foo/libbar.rmeta".into(),
            "src/lib.rs".into(),
            "--crate-name=foo".into(),
        ];
        relocate_pw_flags(&mut args);
        assert_eq!(
            args,
            vec![
                "--subst",
                "pwd=${pwd}",
                "--output-file",
                "bazel-out/foo/libbar.rmeta",
                "--",
                "/path/to/rustc",
                "src/lib.rs",
                "--crate-name=foo",
            ]
        );
    }

    #[test]
    fn test_relocate_pw_flags_moves_multiple_flags() {
        let mut args = vec![
            "--subst".into(),
            "pwd=${pwd}".into(),
            "--".into(),
            "/path/to/rustc".into(),
            "--output-file".into(),
            "out.rmeta".into(),
            "--rustc-output-format".into(),
            "rendered".into(),
            "--env-file".into(),
            "build_script.env".into(),
            "--arg-file".into(),
            "build_script.linksearchpaths".into(),
            "--stable-status-file".into(),
            "stable.status".into(),
            "--volatile-status-file".into(),
            "volatile.status".into(),
            "src/lib.rs".into(),
        ];
        relocate_pw_flags(&mut args);
        let sep = args.iter().position(|a| a == "--").unwrap();
        // All pw flags should be before --
        assert!(args[..sep].contains(&"--output-file".to_string()));
        assert!(args[..sep].contains(&"--rustc-output-format".to_string()));
        assert!(args[..sep].contains(&"--env-file".to_string()));
        assert!(args[..sep].contains(&"--arg-file".to_string()));
        assert!(args[..sep].contains(&"--stable-status-file".to_string()));
        assert!(args[..sep].contains(&"--volatile-status-file".to_string()));
        // Rustc args should be after --
        assert!(args[sep + 1..].contains(&"/path/to/rustc".to_string()));
        assert!(args[sep + 1..].contains(&"src/lib.rs".to_string()));
    }

    #[test]
    fn test_relocate_pw_flags_noop_when_no_flags() {
        let mut args = vec![
            "--subst".into(),
            "pwd=${pwd}".into(),
            "--".into(),
            "/path/to/rustc".into(),
            "src/lib.rs".into(),
        ];
        let expected = args.clone();
        relocate_pw_flags(&mut args);
        assert_eq!(args, expected);
    }

    #[test]
    fn test_relocate_pw_flags_noop_when_no_separator() {
        let mut args = vec!["--output-file".into(), "foo".into()];
        let expected = args.clone();
        relocate_pw_flags(&mut args);
        assert_eq!(args, expected);
    }

}
