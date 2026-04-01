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

#[path = "worker_logging.rs"]
pub(crate) mod logging;
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

use std::io::{self, BufRead};
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};

use crate::ProcessWrapperError;

use logging::{
    append_worker_lifecycle_log, current_pid, current_thread_label, install_worker_panic_hook,
    log_request_received, log_request_thread_start, WorkerLifecycleGuard,
};
use pipeline::{relocate_pw_flags, RequestKind, WorkerStateRoots};
use protocol::{
    build_cancel_response, build_response, extract_request_id,
    extract_request_id_from_raw_line, WorkRequestContext,
};
use registry::{RequestRegistry, SharedRequestRegistry};
use request::RequestExecutor;
use sandbox::{prepare_outputs, prepare_outputs_in_dir, run_request};

// ---------------------------------------------------------------------------
// Worker lifecycle and signal handling
// ---------------------------------------------------------------------------

static WORKER_SHUTTING_DOWN: AtomicBool = AtomicBool::new(false);

#[cfg(unix)]
const SIG_TERM: i32 = 15;

#[cfg(unix)]
unsafe extern "C" {
    fn signal(signum: i32, handler: usize) -> usize;
    fn close(fd: i32) -> i32;
    fn write(fd: i32, buf: *const std::ffi::c_void, count: usize) -> isize;
}

pub(crate) fn worker_is_shutting_down() -> bool {
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

// ---------------------------------------------------------------------------
// Helper functions used in worker_main
// ---------------------------------------------------------------------------

fn write_worker_response(
    stdout: &Arc<Mutex<()>>,
    response: &str,
) -> Result<(), ProcessWrapperError> {
    let _guard = stdout
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
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

/// Request thread using RequestExecutor + RustcInvocation.
fn run_request_thread(
    self_path: std::path::PathBuf,
    startup_args: Vec<String>,
    request: WorkRequestContext,
    request_executor: RequestExecutor,
    stdout: SharedStdout,
    registry: SharedRequestRegistry,
    state_roots: Arc<WorkerStateRoots>,
    claim_flag: Arc<AtomicBool>,
) {
    log_request_thread_start(&request, &request_executor.kind);

    // Process-level shutdown: Bazel has sent SIGTERM and won't read responses.
    // Just clean up and exit — no point sending a response into a dead pipe.
    if worker_is_shutting_down() {
        registry
            .lock()
            .expect("request registry mutex poisoned")
            .remove_request(request.request_id);
        return;
    }

    let (exit_code, output) = match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let full_args = build_full_args(&startup_args, &request.arguments);
        if let Err(e) = prepare_request_outputs(&full_args, &request) {
            return (1, format!("worker thread error: {e}"));
        }

        if claim_flag.load(Ordering::SeqCst) {
            registry
                .lock()
                .expect("request registry mutex poisoned")
                .remove_request(request.request_id);
            return (0, String::new());
        }

        match &request_executor.kind {
            RequestKind::Metadata { .. } => {
                request_executor.execute_metadata(&request, full_args, &state_roots, &registry)
            }
            RequestKind::Full { .. } => {
                request_executor.execute_full(&request, full_args, &self_path)
            }
            RequestKind::NonPipelined => request_executor.execute_non_pipelined(
                full_args,
                &self_path,
                request.sandbox_dir.as_ref().map(|d| d.as_str()),
            ),
        }
    })) {
        Ok(result) => result,
        Err(_) => {
            let mut reg = registry.lock().expect("request registry mutex poisoned");
            // Shut down via registry (covers both metadata and full requests).
            if let Some(inv) = &request_executor.invocation {
                inv.request_shutdown();
            }
            if let Some(key) = request_executor.kind.key() {
                if let Some(inv) = reg.get_invocation(key) {
                    inv.request_shutdown();
                }
            }
            reg.remove_request(request.request_id);
            drop(reg);
            (1, "internal error: worker thread panicked".to_string())
        }
    };

    {
        let mut reg = registry.lock().expect("request registry mutex poisoned");
        reg.remove_request(request.request_id);
        // Full and non-pipelined requests are the last consumer of an
        // invocation — remove it to prevent stale entries accumulating
        // across builds in this long-lived worker process.
        if let Some(key) = request_executor.kind.key() {
            if !matches!(request_executor.kind, RequestKind::Metadata { .. }) {
                reg.remove_invocation(key);
            }
        }
    }
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
    let registry: SharedRequestRegistry = Arc::new(Mutex::new(RequestRegistry::default()));
    let state_roots = Arc::new(WorkerStateRoots::ensure()?);

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

        if request.request_id.is_singleplex() {
            execute_singleplex_request(&self_path, &startup_args, &request, &stdout)?;
            continue;
        }

        if request.cancel {
            let flag = registry
                .lock()
                .expect("request registry mutex poisoned")
                .get_claim_flag(request.request_id);
            if let Some(flag) = flag {
                if !flag.swap(true, Ordering::SeqCst) {
                    registry
                        .lock()
                        .expect("request registry mutex poisoned")
                        .cancel(request.request_id);
                    let response = build_cancel_response(request.request_id);
                    let _ = write_worker_response(&stdout, &response);
                }
            }
            continue;
        }

        let (claim_flag, invocation) = {
            let mut reg = registry.lock().expect("request registry mutex poisoned");
            match &request_kind {
                RequestKind::Metadata { key } => {
                    let flag = reg.register_metadata(request.request_id, key.clone());
                    (flag, None)
                }
                RequestKind::Full { key } => {
                    let (flag, inv) = reg.register_full(request.request_id, key.clone());
                    (flag, inv)
                }
                RequestKind::NonPipelined => {
                    let flag = reg.register_non_pipelined(request.request_id);
                    (flag, None)
                }
            }
        };
        let request_executor = RequestExecutor::new(request_kind.clone(), invocation);
        // Request threads are detached (handle dropped). Bazel shuts down workers
        // via SIGTERM with no drain phase, so there's no opportunity to join.
        // Process exit is the cleanup mechanism.
        drop(std::thread::spawn({
            let self_path = self_path.clone();
            let startup_args = startup_args.clone();
            let request = request.clone();
            let stdout = Arc::clone(&stdout);
            let registry = Arc::clone(&registry);
            let state_roots = Arc::clone(&state_roots);
            let claim_flag = Arc::clone(&claim_flag);
            move || {
                run_request_thread(
                    self_path,
                    startup_args,
                    request,
                    request_executor,
                    stdout,
                    registry,
                    state_roots,
                    claim_flag,
                )
            }
        }));
    }

    begin_worker_shutdown("stdin_eof");
    registry
        .lock()
        .expect("request registry mutex poisoned")
        .shutdown_all();

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
