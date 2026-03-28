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
//! See `DESIGN.md` in this directory for the worker/pipelining protocol notes.

#[path = "worker_pipeline.rs"]
pub(crate) mod pipeline;
#[path = "worker_protocol.rs"]
pub(crate) mod protocol;
#[path = "worker_sandbox.rs"]
pub(crate) mod sandbox;
#[path = "worker_types.rs"]
pub(crate) mod types;
#[path = "worker_invocation.rs"]
pub(crate) mod invocation;
#[path = "worker_registry.rs"]
pub(crate) mod registry;
#[path = "worker_request.rs"]
pub(crate) mod request;

use std::io::{self, BufRead, Write};
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use crate::ProcessWrapperError;

use pipeline::{
    handle_pipelining_full, handle_pipelining_metadata, kill_pipelined_request, relocate_pw_flags,
    PipelineState, RequestKind, WorkerStateRoots,
};
use protocol::{
    build_cancel_response, build_response, build_shutdown_response, extract_request_id,
    extract_request_id_from_raw_line, WorkRequestContext,
};
use registry::{RequestRegistry, SharedRequestRegistry};
use request::BazelRequest;
use sandbox::{prepare_outputs, prepare_outputs_in_dir, run_request, run_sandboxed_request};
use types::RequestId;

// ---------------------------------------------------------------------------
// Worker lifecycle and signal handling
// ---------------------------------------------------------------------------

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

static WORKER_SHUTTING_DOWN: AtomicBool = AtomicBool::new(false);

#[cfg(unix)]
const SIG_TERM: i32 = 15;

#[cfg(unix)]
unsafe extern "C" {
    fn signal(signum: i32, handler: usize) -> usize;
    fn close(fd: i32) -> i32;
    fn write(fd: i32, buf: *const std::ffi::c_void, count: usize) -> isize;
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

// ---------------------------------------------------------------------------
// Helper functions used in worker_main
// ---------------------------------------------------------------------------

fn crate_name_from_args(args: &[String]) -> Option<&str> {
    args.iter()
        .find_map(|arg| arg.strip_prefix("--crate-name="))
}

fn emit_arg_from_args(args: &[String]) -> Option<&str> {
    args.iter().find_map(|arg| arg.strip_prefix("--emit="))
}

fn write_worker_response(
    stdout: &Arc<Mutex<()>>,
    response: &str,
) -> Result<(), ProcessWrapperError> {
    let _guard = lock_or_recover(stdout);
    write_all_stdout_fd(response.as_bytes())
        .and_then(|_| write_all_stdout_fd(b"\n"))
        .map_err(|e| ProcessWrapperError(format!("failed to write WorkResponse: {e}")))?;
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

type SharedStdout = Arc<Mutex<()>>;
type SharedPipelineState = Arc<Mutex<PipelineState>>;

fn startup_args() -> Vec<String> {
    std::env::args()
        .skip(1)
        .filter(|arg| arg != "--persistent_worker")
        .collect()
}

fn build_full_args(startup_args: &[String], request_args: &[String]) -> Vec<String> {
    let mut full_args = startup_args.to_vec();
    full_args.extend_from_slice(request_args);
    relocate_pw_flags(&mut full_args);
    full_args
}

fn request_base_dir(
    request: &WorkRequestContext,
) -> Result<std::path::PathBuf, ProcessWrapperError> {
    if let Some(sandbox_dir) = request.sandbox_dir.as_ref() {
        if sandbox_dir.as_path().is_absolute() {
            return Ok(sandbox_dir.as_path().to_path_buf());
        }
        return std::env::current_dir()
            .map(|cwd| cwd.join(sandbox_dir.as_path()))
            .map_err(|e| ProcessWrapperError(format!("failed to resolve worker cwd: {e}")));
    }
    std::env::current_dir()
        .map_err(|e| ProcessWrapperError(format!("failed to resolve worker cwd: {e}")))
}

fn classify_request(
    startup_args: &[String],
    request: &WorkRequestContext,
) -> Result<RequestKind, ProcessWrapperError> {
    let full_args = build_full_args(startup_args, &request.arguments);
    let base_dir = request_base_dir(request)?;
    Ok(RequestKind::parse_in_dir(&full_args, &base_dir))
}

fn pipeline_key_label(kind: &RequestKind) -> &str {
    kind.key().map(|key| key.as_str()).unwrap_or("-")
}

fn parse_request_line(line: &str, stdout: &SharedStdout) -> Option<WorkRequestContext> {
    let request: tinyjson::JsonValue = match line.parse::<tinyjson::JsonValue>() {
        Ok(request) => request,
        Err(e) => {
            if let Some(request_id) = extract_request_id_from_raw_line(line) {
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
                let _ = write_worker_response(stdout, &response);
            }
            return None;
        }
    };

    match WorkRequestContext::from_json(&request) {
        Ok(ctx) => Some(ctx),
        Err(e) => {
            let request_id = extract_request_id(&request);
            let response = build_response(1, &e, request_id);
            let _ = write_worker_response(stdout, &response);
            None
        }
    }
}

fn log_request_received(request: &WorkRequestContext, kind: &RequestKind) {
    append_worker_lifecycle_log(&format!(
        "pid={} thread={} request_received request_id={} cancel={} crate={} emit={} pipeline_key={}",
        current_pid(),
        current_thread_label(),
        request.request_id,
        request.cancel,
        crate_name_from_args(&request.arguments).unwrap_or("-"),
        emit_arg_from_args(&request.arguments).unwrap_or("-"),
        pipeline_key_label(kind),
    ));
}

fn log_request_thread_start(request: &WorkRequestContext, kind: &RequestKind) {
    append_worker_lifecycle_log(&format!(
        "pid={} thread={} request_thread_start request_id={} crate={} emit={} pipeline_key={}",
        current_pid(),
        current_thread_label(),
        request.request_id,
        crate_name_from_args(&request.arguments).unwrap_or("-"),
        emit_arg_from_args(&request.arguments).unwrap_or("-"),
        pipeline_key_label(kind),
    ));
}

fn prepare_request_outputs(
    full_args: &[String],
    request: &WorkRequestContext,
) -> Result<(), ProcessWrapperError> {
    match request.sandbox_dir.as_ref() {
        Some(_) => {
            let base_dir = request_base_dir(request)?;
            prepare_outputs_in_dir(full_args, &base_dir);
        }
        None => prepare_outputs(full_args),
    }
    Ok(())
}

fn run_non_pipelined_request(
    self_path: &std::path::Path,
    full_args: Vec<String>,
    sandbox_dir: Option<&str>,
) -> (i32, String) {
    match sandbox_dir {
        Some(dir) => run_sandboxed_request(self_path, full_args, dir)
            .unwrap_or_else(|e| (1, format!("sandboxed worker error: {e}"))),
        None => run_request(self_path, full_args)
            .unwrap_or_else(|e| (1, format!("worker thread error: {e}"))),
    }
}

fn execute_singleplex_request(
    self_path: &std::path::Path,
    startup_args: &[String],
    request: &WorkRequestContext,
    stdout: &SharedStdout,
) -> Result<(), ProcessWrapperError> {
    let full_args = build_full_args(startup_args, &request.arguments);
    prepare_outputs(&full_args);
    let (exit_code, output) = run_request(self_path, full_args)?;
    let response = build_response(exit_code, &output, request.request_id);
    write_worker_response(stdout, &response)?;
    append_worker_lifecycle_log(&format!(
        "pid={} thread={} request_complete request_id={} exit_code={} output_bytes={} mode=singleplex",
        current_pid(),
        current_thread_label(),
        request.request_id,
        exit_code,
        output.len(),
    ));
    Ok(())
}

fn try_handle_cancel_request(
    request: &WorkRequestContext,
    stdout: &SharedStdout,
    pipeline_state: &SharedPipelineState,
) -> bool {
    let flag = lock_or_recover(pipeline_state).get_claim_flag(request.request_id);
    let Some(flag) = flag else {
        return true;
    };
    if !flag.swap(true, Ordering::SeqCst) {
        kill_pipelined_request(pipeline_state, request.request_id);
        let response = build_cancel_response(request.request_id);
        let _ = write_worker_response(stdout, &response);
    }
    true
}

fn register_request(
    pipeline_state: &SharedPipelineState,
    request_id: RequestId,
    kind: &RequestKind,
) -> Arc<AtomicBool> {
    let mut state = lock_or_recover(pipeline_state);
    match kind {
        RequestKind::Metadata { key } => state.register_metadata(request_id, key.clone()),
        RequestKind::Full { key } => state.register_full(request_id, key.clone()),
        RequestKind::NonPipelined => state.register_non_pipelined(request_id),
    }
}

fn discard_pending_request(
    pipeline_state: &SharedPipelineState,
    request_kind: &RequestKind,
    request_id: RequestId,
) {
    let mut state = lock_or_recover(pipeline_state);
    match request_kind {
        RequestKind::Metadata { key } => state.cleanup(key, request_id),
        RequestKind::Full { .. } | RequestKind::NonPipelined => state.discard_request(request_id),
    }
}

fn cleanup_after_panic(
    pipeline_state: &SharedPipelineState,
    request_kind: &RequestKind,
    request_id: RequestId,
) {
    let orphan = {
        let mut state = lock_or_recover(pipeline_state);
        match request_kind {
            RequestKind::Metadata { key } | RequestKind::Full { key } => {
                state.cleanup_key_fully(key)
            }
            RequestKind::NonPipelined => {
                state.discard_request(request_id);
                None
            }
        }
    };
    if let Some(mut bg) = orphan {
        let _ = bg.child.kill();
        let _ = bg.child.wait();
        let _ = bg.stderr_drain.join();
    }
}

fn execute_request(
    self_path: &std::path::Path,
    startup_args: &[String],
    request: &WorkRequestContext,
    request_kind: &RequestKind,
    pipeline_state: &SharedPipelineState,
    state_roots: &Arc<WorkerStateRoots>,
    claim_flag: &Arc<AtomicBool>,
) -> (i32, String) {
    let full_args = build_full_args(startup_args, &request.arguments);
    if let Err(e) = prepare_request_outputs(&full_args, request) {
        return (1, format!("worker thread error: {e}"));
    }

    if claim_flag.load(Ordering::SeqCst) {
        discard_pending_request(pipeline_state, request_kind, request.request_id);
        return (0, String::new());
    }

    match request_kind {
        RequestKind::Metadata { key } => {
            let result = handle_pipelining_metadata(
                request,
                full_args,
                key.clone(),
                state_roots,
                pipeline_state,
            );
            if result.0 != 0 {
                lock_or_recover(pipeline_state).cleanup(key, request.request_id);
            }
            result
        }
        RequestKind::Full { key } => {
            handle_pipelining_full(request, full_args, key.clone(), pipeline_state, self_path)
        }
        RequestKind::NonPipelined => run_non_pipelined_request(
            self_path,
            full_args,
            request.sandbox_dir.as_ref().map(|dir| dir.as_str()),
        ),
    }
}

fn run_request_thread(
    self_path: std::path::PathBuf,
    startup_args: Vec<String>,
    request: WorkRequestContext,
    request_kind: RequestKind,
    stdout: SharedStdout,
    pipeline_state: SharedPipelineState,
    state_roots: Arc<WorkerStateRoots>,
    claim_flag: Arc<AtomicBool>,
) {
    log_request_thread_start(&request, &request_kind);

    if worker_is_shutting_down() {
        if !claim_flag.swap(true, Ordering::SeqCst) {
            let response = build_shutdown_response(request.request_id);
            let _ = write_worker_response(&stdout, &response);
        }
        discard_pending_request(&pipeline_state, &request_kind, request.request_id);
        append_worker_lifecycle_log(&format!(
            "pid={} thread={} request_thread_skipped_for_shutdown request_id={} claimed={}",
            current_pid(),
            current_thread_label(),
            request.request_id,
            claim_flag.load(Ordering::SeqCst),
        ));
        return;
    }

    let (exit_code, output) = match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        execute_request(
            &self_path,
            &startup_args,
            &request,
            &request_kind,
            &pipeline_state,
            &state_roots,
            &claim_flag,
        )
    })) {
        Ok(result) => result,
        Err(_) => {
            cleanup_after_panic(&pipeline_state, &request_kind, request.request_id);
            (1, "internal error: worker thread panicked".to_string())
        }
    };

    lock_or_recover(&pipeline_state).remove_claim(request.request_id);
    if !claim_flag.swap(true, Ordering::SeqCst) {
        let response = build_response(exit_code, &output, request.request_id);
        let _ = write_worker_response(&stdout, &response);
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
}

/// Request thread using BazelRequest delegation layer.
///
/// CLEANUP: Once all handlers are migrated to use RustcInvocation, this
/// replaces `run_request_thread` and the `pipeline_state` parameter is removed.
fn run_request_thread_v2(
    self_path: std::path::PathBuf,
    startup_args: Vec<String>,
    request: WorkRequestContext,
    bazel_request: BazelRequest,
    stdout: SharedStdout,
    pipeline_state: SharedPipelineState,
    registry: SharedRequestRegistry,
    state_roots: Arc<WorkerStateRoots>,
    claim_flag: Arc<AtomicBool>,
) {
    log_request_thread_start(&request, &bazel_request.kind);

    if worker_is_shutting_down() {
        if !claim_flag.swap(true, Ordering::SeqCst) {
            let response = build_shutdown_response(request.request_id);
            let _ = write_worker_response(&stdout, &response);
        }
        discard_pending_request(&pipeline_state, &bazel_request.kind, request.request_id);
        lock_or_recover(&registry).remove_request(request.request_id);
        append_worker_lifecycle_log(&format!(
            "pid={} thread={} request_thread_skipped_for_shutdown request_id={} claimed={}",
            current_pid(),
            current_thread_label(),
            request.request_id,
            claim_flag.load(Ordering::SeqCst),
        ));
        return;
    }

    let (exit_code, output) = match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let full_args = build_full_args(&startup_args, &request.arguments);
        if let Err(e) = prepare_request_outputs(&full_args, &request) {
            return (1, format!("worker thread error: {e}"));
        }

        if claim_flag.load(Ordering::SeqCst) {
            discard_pending_request(&pipeline_state, &bazel_request.kind, request.request_id);
            lock_or_recover(&registry).remove_request(request.request_id);
            return (0, String::new());
        }

        match &bazel_request.kind {
            RequestKind::Metadata { .. } => {
                bazel_request.execute_metadata(&request, full_args, &state_roots, &registry)
            }
            RequestKind::Full { .. } => {
                bazel_request.execute_full(&request, full_args, &registry, &self_path)
            }
            RequestKind::NonPipelined => bazel_request.execute_non_pipelined(
                full_args,
                &self_path,
                request.sandbox_dir.as_ref().map(|d| d.as_str()),
                &registry,
            ),
        }
    })) {
        Ok(result) => result,
        Err(_) => {
            cleanup_after_panic(&pipeline_state, &bazel_request.kind, request.request_id);
            if let Some(inv) = &bazel_request.invocation {
                inv.request_shutdown();
            }
            lock_or_recover(&registry).remove_request(request.request_id);
            (1, "internal error: worker thread panicked".to_string())
        }
    };

    lock_or_recover(&pipeline_state).remove_claim(request.request_id);
    lock_or_recover(&registry).remove_request(request.request_id);
    if !claim_flag.swap(true, Ordering::SeqCst) {
        let response = build_response(exit_code, &output, request.request_id);
        let _ = write_worker_response(&stdout, &response);
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
}

fn join_in_flight_threads(in_flight: &Arc<Mutex<Vec<thread::JoinHandle<()>>>>) {
    let handles: Vec<_> = lock_or_recover(in_flight).drain(..).collect();
    let deadline = Instant::now() + Duration::from_secs(10);
    for handle in handles {
        if deadline.saturating_duration_since(Instant::now()).is_zero() {
            break;
        }
        let _ = handle.join();
    }
}

pub(crate) fn worker_main() -> Result<(), ProcessWrapperError> {
    let request_counter = Arc::new(AtomicUsize::new(0));
    install_worker_panic_hook();
    let _lifecycle =
        WorkerLifecycleGuard::new(&std::env::args().collect::<Vec<_>>(), &request_counter);
    install_worker_signal_handlers();

    let self_path = std::env::current_exe()
        .map_err(|e| ProcessWrapperError(format!("failed to get worker executable path: {e}")))?;

    let startup_args = startup_args();

    let stdin = io::stdin();
    let stdout: SharedStdout = Arc::new(Mutex::new(()));
    let pipeline_state: SharedPipelineState = Arc::new(Mutex::new(PipelineState::new()));
    let registry: SharedRequestRegistry = Arc::new(Mutex::new(RequestRegistry::new()));
    let state_roots = Arc::new(WorkerStateRoots::ensure()?);
    let in_flight: Arc<Mutex<Vec<thread::JoinHandle<()>>>> = Arc::new(Mutex::new(Vec::new()));

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

        let request = match parse_request_line(&line, &stdout) {
            Some(request) => request,
            None => continue,
        };
        let request_kind = match classify_request(&startup_args, &request) {
            Ok(kind) => kind,
            Err(e) => {
                let response = build_response(1, &e.to_string(), request.request_id);
                let _ = write_worker_response(&stdout, &response);
                continue;
            }
        };
        log_request_received(&request, &request_kind);

        if worker_is_shutting_down() {
            let response = build_shutdown_response(request.request_id);
            let _ = write_worker_response(&stdout, &response);
            continue;
        }

        if request.request_id.is_singleplex() {
            execute_singleplex_request(&self_path, &startup_args, &request, &stdout)?;
            continue;
        }

        if request.cancel {
            // CLEANUP: Once handlers are migrated, cancel via registry only.
            let _ = try_handle_cancel_request(&request, &stdout, &pipeline_state);
            lock_or_recover(&registry).cancel(request.request_id);
            continue;
        }

        // Register in both old PipelineState (for delegation) and new RequestRegistry.
        let claim_flag = register_request(&pipeline_state, request.request_id, &request_kind);
        let invocation = {
            let mut reg = lock_or_recover(&registry);
            match &request_kind {
                RequestKind::Metadata { key } => {
                    let (_flag, inv) = reg.register_metadata(request.request_id, key.clone());
                    Some(inv)
                }
                RequestKind::Full { key } => {
                    let (_flag, inv) = reg.register_full(request.request_id, key.clone());
                    inv
                }
                RequestKind::NonPipelined => {
                    let _flag = reg.register_non_pipelined(request.request_id);
                    None
                }
            }
        };
        let bazel_request = BazelRequest::new(request.request_id, request_kind.clone(), invocation);
        let handle = std::thread::spawn({
            let self_path = self_path.clone();
            let startup_args = startup_args.clone();
            let request = request.clone();
            let request_kind = request_kind.clone();
            let stdout = Arc::clone(&stdout);
            let pipeline_state = Arc::clone(&pipeline_state);
            let registry = Arc::clone(&registry);
            let state_roots = Arc::clone(&state_roots);
            let claim_flag = Arc::clone(&claim_flag);
            move || {
                run_request_thread_v2(
                    self_path,
                    startup_args,
                    request,
                    bazel_request,
                    stdout,
                    pipeline_state,
                    registry,
                    state_roots,
                    claim_flag,
                )
            }
        });
        lock_or_recover(&in_flight).push(handle);
    }

    begin_worker_shutdown("stdin_eof");
    // CLEANUP: Once handlers are migrated, shutdown via registry only.
    for entry in lock_or_recover(&pipeline_state).drain_all() {
        entry.kill();
    }
    lock_or_recover(&registry).shutdown_all();
    join_in_flight_threads(&in_flight);

    append_worker_lifecycle_log(&format!(
        "pid={} event=stdin_eof thread={} requests_seen={}",
        current_pid(),
        current_thread_label(),
        request_counter.load(Ordering::SeqCst),
    ));

    Ok(())
}

#[cfg(test)]
#[path = "test/worker.rs"]
mod test;
