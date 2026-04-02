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

//! Bazel JSON persistent worker implementation.

#[path = "worker_args.rs"]
pub(crate) mod args;
#[path = "worker_exec.rs"]
pub(crate) mod exec;
#[path = "worker_invocation.rs"]
pub(crate) mod invocation;
#[path = "worker_logging.rs"]
pub(crate) mod logging;
#[path = "worker_pipeline.rs"]
pub(crate) mod pipeline;
#[path = "worker_protocol.rs"]
pub(crate) mod protocol;
#[path = "worker_request.rs"]
pub(crate) mod request;
#[path = "worker_rustc.rs"]
pub(crate) mod rustc_driver;
#[path = "worker_sandbox.rs"]
pub(crate) mod sandbox;
#[path = "worker_types.rs"]
pub(crate) mod types;

use std::collections::HashMap;
use std::io::{self, BufRead};
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};

use crate::ProcessWrapperError;

use args::assemble_request_argv;
use exec::{prepare_outputs, run_request};
use logging::{
    append_worker_lifecycle_log, current_pid, current_thread_label, install_worker_panic_hook,
    log_request_received, log_request_thread_start, WorkerLifecycleGuard,
};
use pipeline::WorkerStateRoots;
use protocol::{
    build_cancel_response, build_response, extract_arguments, extract_cancel, extract_request_id,
    extract_sandbox_dir,
};
use request::{RequestExecutor, RequestKind, WorkRequest};

use self::invocation::RustcInvocation;
use self::types::{PipelineKey, RequestId};

/// Thread-safe shared handle to the `RequestCoordinator`.
type SharedRequestCoordinator = Arc<Mutex<RequestCoordinator>>;

/// Shared state for request threads and rustc threads.
#[derive(Default)]
struct RequestCoordinator {
    /// Pipeline key -> shared invocation.
    invocations: HashMap<PipelineKey, Arc<RustcInvocation>>,
    /// All in-flight requests. Value is `Some(key)` for pipelined requests,
    /// `None` for non-pipelined. Presence in this map means the request is
    /// active and no response has been sent yet. Removal IS the atomic claim —
    /// whoever removes the entry owns the right to send the `WorkResponse`.
    requests: HashMap<RequestId, Option<PipelineKey>>,
}

impl RequestCoordinator {
    /// Cancels a request and shuts down the associated invocation.
    /// Returns `true` if the cancel was claimed (caller should send the cancel
    /// response), `false` if the request already completed.
    fn cancel(&mut self, request_id: RequestId) -> bool {
        if let Some(maybe_key) = self.requests.remove(&request_id) {
            if let Some(key) = maybe_key
                && let Some(inv) = self.invocations.get(&key)
            {
                inv.request_shutdown();
            }
            true
        } else {
            false
        }
    }

    /// Requests shutdown for all tracked invocations and clears the registry.
    fn shutdown_all(&mut self) {
        for inv in self.invocations.values() {
            inv.request_shutdown();
        }
        self.invocations.clear();
        self.requests.clear();
    }
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
    } // Unblock the reader loop.
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

fn build_full_args(
    startup_args: &[String],
    request_args: &[String],
) -> Result<Vec<String>, ProcessWrapperError> {
    assemble_request_argv(startup_args, request_args)
}

fn parse_request_line(line: &str, stdout: &SharedStdout) -> Option<WorkRequest> {
    let request: tinyjson::JsonValue = match line.parse::<tinyjson::JsonValue>() {
        Ok(request) => request,
        Err(e) => {
            let request_id = (|| {
                let after_key = line.split_once("\"requestId\"")?.1;
                let after_colon = after_key.split_once(':')?.1.trim_start();
                let end = after_colon
                    .find(|ch: char| !ch.is_ascii_digit())
                    .unwrap_or(after_colon.len());
                after_colon[..end].parse().ok().map(types::RequestId)
            })();
            if let Some(request_id) = request_id {
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

    match extract_sandbox_dir(&request) {
        Ok(sandbox_dir) => Some(WorkRequest {
            request_id: extract_request_id(&request),
            arguments: extract_arguments(&request),
            sandbox_dir,
            cancel: extract_cancel(&request),
        }),
        Err(e) => {
            let request_id = extract_request_id(&request);
            let response = build_response(1, &e, request_id);
            let _ = write_worker_response(stdout, &response);
            None
        }
    }
}

fn execute_singleplex_request(
    self_path: &std::path::Path,
    startup_args: &[String],
    request: &WorkRequest,
    stdout: &SharedStdout,
) -> Result<(), ProcessWrapperError> {
    let full_args = build_full_args(startup_args, &request.arguments)?;
    prepare_outputs(&full_args, None);
    let (exit_code, output) = run_request(self_path, full_args, None, "process_wrapper subprocess")?;
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

/// Runs one multiplex request on a detached thread.
fn run_request_thread(
    self_path: std::path::PathBuf,
    startup_args: Vec<String>,
    request: WorkRequest,
    request_executor: RequestExecutor,
    stdout: SharedStdout,
    registry: SharedRequestCoordinator,
    state_roots: Arc<WorkerStateRoots>,
) {
    log_request_thread_start(&request, &request_executor.kind);

    // Once shutdown starts, just clean up; Bazel will not read more responses.
    if worker_is_shutting_down() {
        registry
            .lock()
            .expect("request registry mutex poisoned")
            .requests.remove(&request.request_id);
        return;
    }

    let (exit_code, output) = match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let full_args = match build_full_args(&startup_args, &request.arguments) {
            Ok(args) => args,
            Err(e) => return (1, format!("worker thread error: {e}")),
        };
        let base_dir = match request
            .sandbox_dir
            .as_ref()
            .map(|_| request.base_dir())
            .transpose()
        {
            Ok(dir) => dir,
            Err(e) => return (1, format!("worker thread error: {e}")),
        };
        prepare_outputs(&full_args, base_dir.as_deref());

        // If the request was already cancelled, bail out before running rustc.
        if !registry
            .lock()
            .expect("request registry mutex poisoned")
            .requests.contains_key(&request.request_id)
        {
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
            let reg = registry.lock().expect("request registry mutex poisoned");
            // Also shut down any shared invocation.
            if let Some(inv) = &request_executor.invocation {
                inv.request_shutdown();
            }
            if let Some(key) = request_executor.kind.key() {
                if let Some(inv) = reg.invocations.get(key) {
                    inv.request_shutdown();
                }
            }
            drop(reg);
            (1, "internal error: worker thread panicked".to_string())
        }
    };

    // Claim the right to respond, then clean up invocation state.
    let should_respond = {
        let mut reg = registry.lock().expect("request registry mutex poisoned");
        let claimed = reg.requests.remove(&request.request_id).is_some();
        if let Some(key) = request_executor.kind.key() {
            if !matches!(request_executor.kind, RequestKind::Metadata { .. }) {
                reg.invocations.remove(key);
            }
        }
        claimed
    };
    if should_respond {
        let response = build_response(exit_code, &output, request.request_id);
        let _ = write_worker_response(&stdout, &response);
    }
    append_worker_lifecycle_log(&format!(
        "pid={} thread={} request_thread_complete request_id={} exit_code={} output_bytes={} responded={}",
        current_pid(),
        current_thread_label(),
        request.request_id,
        exit_code,
        output.len(),
        should_respond,
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

    let startup_args: Vec<String> = std::env::args()
        .skip(1)
        .filter(|arg| arg != "--persistent_worker")
        .collect();

    let stdin = io::stdin();
    let stdout: SharedStdout = Arc::new(Mutex::new(()));
    let registry: SharedRequestCoordinator = Arc::new(Mutex::new(RequestCoordinator::default()));
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
        let request_kind = match build_full_args(&startup_args, &request.arguments)
            .and_then(|full_args| {
                let base_dir = request.base_dir().map_err(ProcessWrapperError)?;
                Ok(RequestKind::parse_in_dir(&full_args, &base_dir))
            }) {
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
            let should_respond = registry
                .lock()
                .expect("request registry mutex poisoned")
                .cancel(request.request_id);
            if should_respond {
                let response = build_cancel_response(request.request_id);
                let _ = write_worker_response(&stdout, &response);
            }
            continue;
        }

        let invocation = {
            let mut reg = registry.lock().expect("request registry mutex poisoned");
            reg.requests.insert(request.request_id, request_kind.key().cloned());
            request_kind.key().and_then(|k| reg.invocations.get(k).map(Arc::clone))
        };
        let request_executor = RequestExecutor::new(request_kind.clone(), invocation);
        // Request threads are detached; worker shutdown is process-driven.
        let _ = std::thread::spawn({
            let self_path = self_path.clone();
            let startup_args = startup_args.clone();
            let request = request.clone();
            let stdout = Arc::clone(&stdout);
            let registry = Arc::clone(&registry);
            let state_roots = Arc::clone(&state_roots);
            move || {
                run_request_thread(
                    self_path,
                    startup_args,
                    request,
                    request_executor,
                    stdout,
                    registry,
                    state_roots,
                )
            }
        });
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
