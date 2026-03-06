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

use std::collections::HashMap;
use std::io::{self, BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;

use tinyjson::JsonValue;

use crate::options::is_pipelining_flag;
use crate::ProcessWrapperError;

/// Locks a mutex, recovering from poisoning instead of panicking.
///
/// If a worker thread panics while holding a mutex, the mutex becomes
/// "poisoned". Rather than cascading the panic to all other threads,
/// we recover the inner value — the data is still valid because
/// `catch_unwind` prevents partial updates from escaping.
fn lock_or_recover<T>(mutex: &Mutex<T>) -> std::sync::MutexGuard<'_, T> {
    mutex.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
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
    // Shared stdout protected by a mutex so concurrent threads don't interleave
    // their WorkResponse messages.
    let stdout = Arc::new(Mutex::new(io::stdout()));

    // Shared state for worker-managed pipelined compilation.
    // The metadata action stores a running rustc Child here; the full compile
    // action retrieves it and waits for completion.
    let pipeline_state: Arc<Mutex<PipelineState>> = Arc::new(Mutex::new(PipelineState::new()));

    // Tracks in-flight requests for cancel/completion race prevention.
    // Key: requestId, Value: claim flag (false = response not yet sent).
    // Whoever atomically sets the flag true first (cancel or worker thread) sends
    // the response; the other side skips. Entries are removed by the worker thread
    // when it finishes, so request IDs can be safely reused across builds when
    // Bazel keeps the worker process alive.
    let in_flight: Arc<Mutex<HashMap<i64, Arc<AtomicBool>>>> =
        Arc::new(Mutex::new(HashMap::new()));

    for line in stdin.lock().lines() {
        let line =
            line.map_err(|e| ProcessWrapperError(format!("failed to read WorkRequest: {e}")))?;
        if line.is_empty() {
            continue;
        }

        let request: JsonValue = line
            .parse()
            .map_err(|e: tinyjson::JsonParseError| {
                ProcessWrapperError(format!("failed to parse WorkRequest JSON: {e}"))
            })?;

        let request_id = extract_request_id(&request);
        let args = extract_arguments(&request);
        let sandbox_dir = extract_sandbox_dir(&request);
        let is_cancel = extract_cancel(&request);

        if request_id == 0 {
            // Singleplex: process inline on the main thread (backward-compatible).
            let mut full_args = startup_args.clone();
            full_args.extend(args);

            // Workers run in execroot without sandboxing. Bazel marks action outputs
            // read-only after each successful action. Make them writable first.
            prepare_outputs(&full_args);

            let (exit_code, output) = run_request(&self_path, full_args)?;

            let response = build_response(exit_code, &output, request_id);
            let mut out = lock_or_recover(&stdout);
            writeln!(out, "{response}")
                .map_err(|e| ProcessWrapperError(format!("failed to write WorkResponse: {e}")))?;
            out.flush()
                .map_err(|e| ProcessWrapperError(format!("failed to flush stdout: {e}")))?;
        } else {
            let stdout = Arc::clone(&stdout);
            let in_flight = Arc::clone(&in_flight);

            // Cancel request: Bazel no longer needs the result for this requestId.
            // Respond with wasCancelled=true immediately if we haven't already responded.
            if is_cancel {
                // Look up the flag for this in-flight request.
                let flag = lock_or_recover(&in_flight).get(&request_id).map(Arc::clone);
                if let Some(flag) = flag {
                    // Try to claim the response slot atomically.
                    if !flag.swap(true, Ordering::SeqCst) {
                        // We claimed it — send the cancel acknowledgment.
                        let response = build_cancel_response(request_id);
                        let mut out = lock_or_recover(&stdout);
                        let _ = writeln!(out, "{response}");
                        let _ = out.flush();
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
            lock_or_recover(&in_flight)
                .insert(request_id, Arc::clone(&claim_flag));

            // Multiplex: dispatch to a new thread. Bazel bounds concurrency via
            // --worker_max_multiplex_instances (default: 8), so no in-process
            // thread pool is needed.
            let self_path = self_path.clone();
            let startup_args = startup_args.clone();
            let pipeline_state = Arc::clone(&pipeline_state);

            std::thread::spawn(move || {
                let (exit_code, output) = match std::panic::catch_unwind(
                    std::panic::AssertUnwindSafe(|| {
                        let mut full_args = startup_args;
                        full_args.extend(args);

                        let sandbox_opt = if sandbox_dir.is_empty() {
                            None
                        } else {
                            Some(sandbox_dir)
                        };

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
                            PipeliningMode::Metadata { key } => {
                                handle_pipelining_metadata(
                                    full_args,
                                    key,
                                    sandbox_opt,
                                    &pipeline_state,
                                )
                            }
                            PipeliningMode::Full { key } => {
                                handle_pipelining_full(
                                    full_args,
                                    key,
                                    sandbox_opt,
                                    &pipeline_state,
                                    &self_path,
                                )
                            }
                            PipeliningMode::None => match sandbox_opt {
                                Some(ref dir) => {
                                    run_sandboxed_request(&self_path, full_args, dir)
                                        .unwrap_or_else(|e| {
                                            (1, format!("sandboxed worker error: {e}"))
                                        })
                                }
                                None => {
                                    run_request(&self_path, full_args)
                                        .unwrap_or_else(|e| {
                                            (1, format!("worker thread error: {e}"))
                                        })
                                }
                            },
                        }
                    }),
                ) {
                    Ok(result) => result,
                    Err(_) => (1, "internal error: worker thread panicked".to_string()),
                };

                // Remove our entry from in_flight regardless of who sends the response.
                // This keeps the map from growing indefinitely and allows request_id
                // to be reused in the next build.
                lock_or_recover(&in_flight).remove(&request_id);

                // Only send a response if a cancel acknowledgment hasn't already been sent.
                if !claim_flag.swap(true, Ordering::SeqCst) {
                    let response = build_response(exit_code, &output, request_id);
                    let mut out = lock_or_recover(&stdout);
                    let _ = writeln!(out, "{response}");
                    let _ = out.flush();
                }
            });
        }
    }

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
fn scan_pipelining_flags<'a>(
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
    /// Diagnostics captured from rustc stderr before the metadata signal.
    diagnostics_before: String,
    /// Background thread draining rustc's remaining stderr output after the
    /// metadata signal. Must be joined before waiting on `child` to avoid
    /// deadlock (child blocks on stderr write if the pipe buffer fills up).
    /// Returns the diagnostics captured after the metadata signal.
    stderr_drain: thread::JoinHandle<String>,
    /// Worker-managed persistent output directory for sandboxed pipelining.
    /// `None` when running unsandboxed — outputs are written directly to the
    /// execroot-relative `--out-dir`.
    pipeline_output_dir: Option<PathBuf>,
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
}

// ---------------------------------------------------------------------------
// Pipelining helpers (shared by metadata and full handlers)
// ---------------------------------------------------------------------------

/// Parsed process_wrapper arguments from before the `--` separator.
struct ParsedPwArgs {
    subst: Vec<(String, String)>,
    env_files: Vec<String>,
    arg_files: Vec<String>,
    output_file: Option<String>,
}

/// Parses process_wrapper flags from the pre-`--` portion of args.
fn parse_pw_args(pw_args: &[String]) -> ParsedPwArgs {
    let current_dir = std::env::current_dir()
        .map(|p| p.to_string_lossy().into_owned())
        .unwrap_or_default();
    let mut parsed = ParsedPwArgs {
        subst: Vec::new(),
        env_files: Vec::new(),
        arg_files: Vec::new(),
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
            _ => {}
        }
        i += 1;
    }
    parsed
}

/// Builds the environment map: inherit current process + env files + apply substitutions.
fn build_rustc_env(env_files: &[String], subst: &[(String, String)]) -> HashMap<String, String> {
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
) -> Result<(Vec<String>, String), (i32, String)> {
    let mut rustc_args = expand_rustc_args(rustc_and_after, &pw_args.subst);
    if rustc_args.is_empty() {
        return Err((1, "pipelining: no rustc arguments after expansion".to_string()));
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

/// Creates the worker-managed persistent output directory `_pw_pipeline/<key>/`.
///
/// Returns `(pipeline_dir_relative, pipeline_dir_absolute)`.
fn create_pipeline_dir(key: &str) -> Result<(PathBuf, PathBuf), (i32, String)> {
    let pipeline_dir = PathBuf::from(format!("_pw_pipeline/{}", key));
    if let Err(e) = std::fs::create_dir_all(&pipeline_dir) {
        return Err((1, format!("pipelining: failed to create pipeline dir: {e}")));
    }
    let pipeline_dir_abs = pipeline_dir
        .canonicalize()
        .map_err(|e| (1, format!("pipelining: failed to resolve pipeline dir: {e}")))?;
    Ok((pipeline_dir, pipeline_dir_abs))
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
/// When `sandbox_dir` is `Some`, sets `CWD = sandbox_dir` on rustc and copies
/// the `.rmeta` into the sandbox. When `None`, copies to the execroot.
fn handle_pipelining_metadata(
    args: Vec<String>,
    key: String,
    sandbox_dir: Option<String>,
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

    let pw_args = parse_pw_args(pw_raw);
    let env = build_rustc_env(&pw_args.env_files, &pw_args.subst);

    let (rustc_args, original_out_dir) = match prepare_rustc_args(rustc_and_after, &pw_args) {
        Ok(v) => v,
        Err(e) => return e,
    };

    let (pipeline_dir, pipeline_dir_abs) = match create_pipeline_dir(&key) {
        Ok(v) => v,
        Err(e) => return e,
    };

    // Redirect --out-dir to our persistent directory so rustc writes all outputs
    // (.rmeta, .rlib, .d) there instead of the Bazel-managed out-dir.
    let rustc_args = rewrite_out_dir_in_expanded(rustc_args, &pipeline_dir_abs);

    // Spawn rustc directly with the prepared env and args.
    let mut cmd = Command::new(&rustc_args[0]);
    cmd.args(&rustc_args[1..])
        .env_clear()
        .envs(&env)
        .stdout(Stdio::null())
        .stderr(Stdio::piped());
    if let Some(ref dir) = sandbox_dir {
        cmd.current_dir(dir);
    }
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
            // Copy .rmeta to the declared output location (_pipeline/ subdirectory).
            match sandbox_dir {
                Some(ref dir) => {
                    copy_output_to_sandbox(&rmeta_path_str, dir, &original_out_dir, "_pipeline");
                }
                None => {
                    let rmeta_src = std::path::Path::new(&rmeta_path_str);
                    if let Some(filename) = rmeta_src.file_name() {
                        let dest_pipeline =
                            std::path::Path::new(&original_out_dir).join("_pipeline");
                        let _ = std::fs::create_dir_all(&dest_pipeline);
                        let dest = dest_pipeline.join(filename);
                        if let Err(e) = std::fs::copy(rmeta_src, &dest) {
                            eprintln!(
                                "[worker-pipeline] metadata key={key} rmeta copy FAILED: {e}"
                            );
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
            lock_or_recover(pipeline_state).store(
                key,
                BackgroundRustc {
                    child,
                    diagnostics_before,
                    stderr_drain: drain,
                    pipeline_output_dir: Some(pipeline_dir_abs),
                    original_out_dir,
                },
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
    eprintln!("[worker-pipeline] metadata key={key} rustc exited (code={exit_code}) before .rmeta; cleaning up pipeline dir");
    let _ = std::fs::remove_dir_all(&pipeline_dir);
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
    args: Vec<String>,
    key: String,
    sandbox_dir: Option<String>,
    pipeline_state: &Arc<Mutex<PipelineState>>,
    self_path: &std::path::Path,
) -> (i32, String) {
    let bg = lock_or_recover(pipeline_state).take(&key);

    match bg {
        Some(mut bg) => {
            // Join the drain thread first (avoids deadlock: child blocks on stderr
            // write if the pipe buffer fills up before we drain it).
            let remaining = bg.stderr_drain.join().unwrap_or_default();
            let all_diagnostics = bg.diagnostics_before + &remaining;

            match bg.child.wait() {
                Ok(status) => {
                    let exit_code = status.code().unwrap_or(1);
                    if let Some(ref pipeline_dir) = bg.pipeline_output_dir {
                        if exit_code == 0 {
                            // Copy all outputs from the persistent pipeline dir.
                            match sandbox_dir {
                                Some(ref dir) => {
                                    copy_all_outputs_to_sandbox(
                                        pipeline_dir,
                                        dir,
                                        &bg.original_out_dir,
                                    );
                                }
                                None => {
                                    let dest_dir =
                                        std::path::Path::new(&bg.original_out_dir);
                                    let _ = std::fs::create_dir_all(dest_dir);
                                    if let Ok(entries) = std::fs::read_dir(pipeline_dir) {
                                        for entry in entries.flatten() {
                                            if let Ok(meta) = entry.metadata() {
                                                if meta.is_file() {
                                                    let dest =
                                                        dest_dir.join(entry.file_name());
                                                    if let Err(e) =
                                                        std::fs::copy(entry.path(), &dest)
                                                    {
                                                        eprintln!("[worker-pipeline] full key={key} copy FAILED: {e}");
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        let _ = std::fs::remove_dir_all(pipeline_dir);
                    }
                    (exit_code, all_diagnostics)
                }
                Err(e) => (1, format!("failed to wait for background rustc: {e}")),
            }
        }
        None => {
            // No cached process found (worker was restarted between the metadata
            // and full actions, or metadata was a cache hit). Fall back to a normal
            // one-shot compilation.
            let filtered_args = strip_pipelining_flags(&args);
            match sandbox_dir {
                Some(ref dir) => {
                    run_sandboxed_request(self_path, filtered_args, dir)
                        .unwrap_or_else(|e| (1, format!("pipelining fallback error: {e}")))
                }
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
    args.iter().filter(|a| !is_pipelining_flag(a)).cloned().collect()
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
fn expand_rustc_args(rustc_and_after: &[String], subst: &[(String, String)]) -> Vec<String> {
    let mut result = Vec::new();
    for raw in rustc_and_after {
        let arg = apply_substs(raw, subst);
        if let Some(path) = arg.strip_prefix('@') {
            match std::fs::read_to_string(path) {
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

/// Extracts the `sandboxDir` field from a WorkRequest (empty string if absent).
fn extract_sandbox_dir(request: &JsonValue) -> String {
    if let JsonValue::Object(map) = request {
        if let Some(JsonValue::String(dir)) = map.get("sandboxDir") {
            return dir.clone();
        }
    }
    String::new()
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

/// Builds a JSON WorkResponse with `wasCancelled: true`.
fn build_cancel_response(request_id: i64) -> String {
    let response = JsonValue::Object(HashMap::from([
        ("exitCode".to_string(), JsonValue::Number(0.0)),
        ("output".to_string(), JsonValue::String(String::new())),
        (
            "requestId".to_string(),
            JsonValue::Number(request_id as f64),
        ),
        ("wasCancelled".to_string(), JsonValue::Boolean(true)),
    ]));
    response.stringify().unwrap_or_else(|_| {
        format!(
            r#"{{"exitCode":0,"output":"","requestId":{request_id},"wasCancelled":true}}"#
        )
    })
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
    let output = Command::new(self_path)
        .args(&arguments)
        .current_dir(sandbox_dir)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .map_err(|e| {
            ProcessWrapperError(format!("failed to spawn sandboxed subprocess: {e}"))
        })?;

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
fn copy_output_to_sandbox(src: &str, sandbox_dir: &str, original_out_dir: &str, dest_subdir: &str) {
    let src_path = std::path::Path::new(src);
    let filename = match src_path.file_name() {
        Some(n) => n,
        None => return,
    };
    let dest_dir = std::path::Path::new(sandbox_dir).join(original_out_dir).join(dest_subdir);
    let _ = std::fs::create_dir_all(&dest_dir);
    let _ = std::fs::copy(src, dest_dir.join(filename));
}

/// Copies all regular files from `pipeline_dir` into `<sandbox_dir>/<original_out_dir>/`.
///
/// Used by the full action to move the `.rlib` (and `.d`, etc.) from the
/// persistent directory into the sandbox before responding to Bazel.
fn copy_all_outputs_to_sandbox(
    pipeline_dir: &PathBuf,
    sandbox_dir: &str,
    original_out_dir: &str,
) {
    let dest_dir = std::path::Path::new(sandbox_dir).join(original_out_dir);
    let _ = std::fs::create_dir_all(&dest_dir);
    if let Ok(entries) = std::fs::read_dir(pipeline_dir) {
        for entry in entries.flatten() {
            if let Ok(meta) = entry.metadata() {
                if meta.is_file() {
                    let _ = std::fs::copy(entry.path(), dest_dir.join(entry.file_name()));
                }
            }
        }
    }
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
    let response = JsonValue::Object(HashMap::from([
        (
            "exitCode".to_string(),
            JsonValue::Number(exit_code as f64),
        ),
        ("output".to_string(), JsonValue::String(output.to_string())),
        (
            "requestId".to_string(),
            JsonValue::Number(request_id as f64),
        ),
    ]));
    response.stringify().unwrap_or_else(|_| {
        // Fallback: hand-craft a minimal valid response if stringify fails.
        format!(r#"{{"exitCode":{exit_code},"output":"","requestId":{request_id}}}"#)
    })
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
        let req = parse_json(r#"{"requestId": 0, "arguments": ["--subst", "pwd=/work", "--", "rustc"]}"#);
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
        fs::write(&arg_file, format!("--out-dir={}\n--crate-name=foo\n", out_dir.display())).unwrap();

        let args = vec![
            "--arg-file".to_string(),
            arg_file.display().to_string(),
        ];
        prepare_outputs(&args);

        assert!(!fs::metadata(&file_path).unwrap().permissions().readonly());
        let _ = fs::remove_dir_all(&tmp);
    }

    #[test]
    fn test_build_response_success() {
        let response = build_response(0, "", 0);
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
        assert!(matches!(detect_pipelining_mode(&args), PipeliningMode::None));
    }

    #[test]
    fn test_detect_pipelining_mode_metadata() {
        let args = vec![
            "--pipelining-metadata".to_string(),
            "--pipelining-key=my_crate_abc123".to_string(),
        ];
        match detect_pipelining_mode(&args) {
            PipeliningMode::Metadata { key } => assert_eq!(key, "my_crate_abc123"),
            other => panic!("expected Metadata, got {:?}", std::mem::discriminant(&other)),
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
        assert!(matches!(detect_pipelining_mode(&args), PipeliningMode::None));
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
        assert_eq!(apply_substs("${out}/foo.rlib", &subst), "bazel-out/k8/bin/foo.rlib");
        assert_eq!(apply_substs("--crate-name=foo", &subst), "--crate-name=foo");
    }

    #[test]
    fn test_scan_pipelining_flags_metadata() {
        let (is_metadata, is_full, key) =
            scan_pipelining_flags(["--pipelining-metadata", "--pipelining-key=foo_abc"].iter().copied());
        assert!(is_metadata);
        assert!(!is_full);
        assert_eq!(key, Some("foo_abc".to_string()));
    }

    #[test]
    fn test_scan_pipelining_flags_full() {
        let (is_metadata, is_full, key) =
            scan_pipelining_flags(["--pipelining-full", "--pipelining-key=bar_xyz"].iter().copied());
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
            other => panic!("expected Metadata, got {:?}", std::mem::discriminant(&other)),
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
        let expanded = expand_rustc_args(&rustc_and_after, &subst);

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
        let expanded = expand_rustc_args(&rustc_and_after, &subst);

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
        assert_eq!(extract_sandbox_dir(&req), "/tmp/sandbox/42");
    }

    #[test]
    fn test_extract_sandbox_dir_absent() {
        let req = parse_json(r#"{"requestId": 1}"#);
        assert_eq!(extract_sandbox_dir(&req), "");
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
        let parsed = parse_json(&response);
        if let JsonValue::Object(map) = parsed {
            assert!(matches!(map.get("requestId"), Some(JsonValue::Number(n)) if *n == 7.0));
            assert!(matches!(map.get("exitCode"), Some(JsonValue::Number(n)) if *n == 0.0));
            assert!(matches!(map.get("wasCancelled"), Some(JsonValue::Boolean(true))));
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
    fn test_extract_rmeta_path_valid() {
        let line = r#"{"artifact":"/work/out/libfoo.rmeta","emit":"metadata"}"#;
        assert_eq!(
            extract_rmeta_path(line),
            Some("/work/out/libfoo.rmeta".to_string())
        );
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

        let dest = sandbox_dir.join(out_rel).join("_pipeline").join("libfoo.rmeta");
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

        copy_all_outputs_to_sandbox(
            &pipeline_dir,
            &sandbox_dir.display().to_string(),
            out_rel,
        );

        let dest = sandbox_dir.join(out_rel);
        assert!(dest.join("libfoo.rlib").exists());
        assert!(dest.join("libfoo.rmeta").exists());
        assert!(dest.join("libfoo.d").exists());

        let _ = fs::remove_dir_all(&tmp);
    }
}
