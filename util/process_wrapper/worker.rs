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

use std::io::{self, BufRead, Write};
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use crate::ProcessWrapperError;

use pipeline::{
    handle_pipelining_full, handle_pipelining_metadata,
    kill_pipelined_request, relocate_pw_flags, PipelineState, RequestKind, WorkerStateRoots,
};
use protocol::{
    build_cancel_response, build_response, build_shutdown_response, extract_request_id,
    extract_request_id_from_raw_line, WorkRequestContext,
};
use sandbox::{prepare_outputs, prepare_outputs_sandboxed, run_request, run_sandboxed_request};
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

fn request_base_dir(request: &WorkRequestContext) -> Result<std::path::PathBuf, ProcessWrapperError> {
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

fn prepare_request_outputs(full_args: &[String], sandbox_dir: Option<&str>) {
    match sandbox_dir {
        Some(dir) => prepare_outputs_sandboxed(full_args, dir),
        None => prepare_outputs(full_args),
    }
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
            RequestKind::Metadata { key } | RequestKind::Full { key } => state.cleanup_key_fully(key),
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
    prepare_request_outputs(
        &full_args,
        request.sandbox_dir.as_ref().map(|dir| dir.as_str()),
    );

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
        RequestKind::Full { key } => handle_pipelining_full(
            request,
            full_args,
            key.clone(),
            pipeline_state,
            self_path,
        ),
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

    let (exit_code, output) =
        match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
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
            let _ = try_handle_cancel_request(&request, &stdout, &pipeline_state);
            continue;
        }

        let claim_flag = register_request(&pipeline_state, request.request_id, &request_kind);
        let handle = std::thread::spawn({
            let self_path = self_path.clone();
            let startup_args = startup_args.clone();
            let request = request.clone();
            let request_kind = request_kind.clone();
            let stdout = Arc::clone(&stdout);
            let pipeline_state = Arc::clone(&pipeline_state);
            let state_roots = Arc::clone(&state_roots);
            let claim_flag = Arc::clone(&claim_flag);
            move || {
                run_request_thread(
                    self_path,
                    startup_args,
                    request,
                    request_kind,
                    stdout,
                    pipeline_state,
                    state_roots,
                    claim_flag,
                )
            }
        });
        lock_or_recover(&in_flight).push(handle);
    }

    begin_worker_shutdown("stdin_eof");
    for entry in lock_or_recover(&pipeline_state).drain_all() {
        entry.kill();
    }
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
mod test {
    use super::pipeline::{
        apply_substs, build_rustc_env, detect_pipelining_mode, expand_rustc_args,
        extract_rmeta_path, find_out_dir_in_expanded, parse_pw_args,
        prepare_expanded_rustc_outputs, rewrite_out_dir_in_expanded, scan_pipelining_flags,
        strip_pipelining_flags, BackgroundRustc, CancelledEntry, FullRequestAction,
        PipelineState, RequestKind, StoreBackgroundResult,
    };
    use super::protocol::{
        extract_arguments, extract_cancel, extract_inputs, extract_request_id, extract_sandbox_dir,
        WorkRequestInput,
    };
    use super::sandbox::resolve_sandbox_path;
    use super::types::{OutputDir, PipelineKey, RequestId};
    #[cfg(unix)]
    use super::sandbox::{
        copy_all_outputs_to_sandbox, copy_output_to_sandbox, seed_sandbox_cache_root, symlink_path,
    };
    use super::*;
    use crate::options::is_pipelining_flag;
    use tinyjson::JsonValue;

    fn parse_json(s: &str) -> JsonValue {
        s.parse().unwrap()
    }

    #[test]
    fn test_extract_request_id_present() {
        let req = parse_json(r#"{"requestId": 42, "arguments": []}"#);
        assert_eq!(extract_request_id(&req), RequestId(42));
    }

    #[test]
    fn test_extract_request_id_missing() {
        let req = parse_json(r#"{"arguments": []}"#);
        assert_eq!(extract_request_id(&req), RequestId(0));
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
        let response = build_response(1, "hello\u{0}world\u{7}", RequestId(9));
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
        let response = build_response(0, "", RequestId(0));
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
        let response = build_response(1, "error: type mismatch", RequestId(0));
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
            RequestKind::NonPipelined
        ));
    }

    #[test]
    fn test_detect_pipelining_mode_metadata() {
        let args = vec![
            "--pipelining-metadata".to_string(),
            "--pipelining-key=my_crate_abc123".to_string(),
        ];
        match detect_pipelining_mode(&args) {
            RequestKind::Metadata { key } => assert_eq!(key.as_str(), "my_crate_abc123"),
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
            RequestKind::Full { key } => assert_eq!(key.as_str(), "my_crate_abc123"),
            other => panic!("expected Full, got {:?}", std::mem::discriminant(&other)),
        }
    }

    #[test]
    fn test_detect_pipelining_mode_no_key() {
        // If pipelining flag present but no key, fall back to None.
        let args = vec!["--pipelining-metadata".to_string()];
        assert!(matches!(
            detect_pipelining_mode(&args),
            RequestKind::NonPipelined
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
    fn test_pipeline_state_take_for_full_empty() {
        let mut state = PipelineState::new();
        let key = PipelineKey("nonexistent".to_string());
        let _flag = state.register_full(RequestId(1), key.clone());
        assert!(matches!(
            state.claim_for_full(&key, RequestId(1)),
            FullRequestAction::Fallback
        ));
    }

    #[test]
    fn test_request_kind_parse_in_dir_reads_relative_paramfile() {
        use std::fs;

        let dir = std::env::temp_dir().join("pw_request_kind_relative_paramfile");
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        let paramfile = dir.join("rustc.params");
        fs::write(
            &paramfile,
            "--crate-name=foo\n--pipelining-full\n--pipelining-key=foo_key\n",
        )
        .unwrap();

        let args = vec!["--".to_string(), "rustc".to_string(), "@rustc.params".to_string()];
        match RequestKind::parse_in_dir(&args, &dir) {
            RequestKind::Full { key } => assert_eq!(key.as_str(), "foo_key"),
            other => panic!("expected full request, got {:?}", other),
        }

        let _ = fs::remove_dir_all(&dir);
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
            RequestKind::Metadata { key } => assert_eq!(key.as_str(), "foo_abc123"),
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
    fn test_extract_sandbox_dir_absent() {
        let req = parse_json(r#"{"requestId": 1}"#);
        assert_eq!(extract_sandbox_dir(&req), Ok(None));
    }

    #[test]
    fn test_extract_sandbox_dir_empty_string_returns_none() {
        let req = parse_json(r#"{"requestId": 1, "sandboxDir": ""}"#);
        assert_eq!(extract_sandbox_dir(&req), Ok(None));
    }

    /// A nonexistent sandbox directory is an error — it means the platform
    /// doesn't support sandboxing and the user should remove the flag.
    #[test]
    fn test_extract_sandbox_dir_nonexistent_is_err() {
        let req = parse_json(r#"{"requestId": 1, "sandboxDir": "/no/such/sandbox/dir"}"#);
        let result = extract_sandbox_dir(&req);
        assert!(result.is_err(), "expected Err for nonexistent sandbox dir");
        let msg = result.unwrap_err();
        assert!(
            msg.contains("--experimental_worker_multiplex_sandboxing"),
            "error should mention the flag: {}",
            msg
        );
    }

    /// An existing but empty sandbox directory is an error. On Windows, Bazel
    /// creates the directory without populating it with symlinks because there
    /// is no real sandbox implementation.
    #[test]
    #[cfg(unix)]
    fn test_extract_sandbox_dir_empty_dir_is_err_unix() {
        let dir = std::env::temp_dir().join("pw_test_sandbox_empty_unix");
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let dir_str = dir.to_string_lossy().into_owned();
        let json = format!(r#"{{"requestId": 1, "sandboxDir": "{}"}}"#, dir_str);
        let req = parse_json(&json);
        let result = extract_sandbox_dir(&req);
        assert!(result.is_err(), "expected Err for empty sandbox dir");
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    #[cfg(windows)]
    fn test_extract_sandbox_dir_empty_dir_is_err_windows() {
        let dir = std::env::temp_dir().join("pw_test_sandbox_empty_win");
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let dir_str = dir.to_string_lossy().into_owned();
        let escaped = dir_str.replace('\\', "\\\\");
        let json = format!(r#"{{"requestId": 1, "sandboxDir": "{}"}}"#, escaped);
        let req = parse_json(&json);
        let result = extract_sandbox_dir(&req);
        assert!(result.is_err(), "expected Err for empty sandbox dir");
        let _ = std::fs::remove_dir_all(&dir);
    }

    /// On Unix, a populated sandbox directory is accepted.
    #[test]
    #[cfg(unix)]
    fn test_extract_sandbox_dir_populated_unix() {
        let dir = std::env::temp_dir().join("pw_test_sandbox_pop_unix");
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(dir.join("marker"), b"").unwrap();
        let dir_str = dir.to_string_lossy().into_owned();
        let json = format!(r#"{{"requestId": 1, "sandboxDir": "{}"}}"#, dir_str);
        let req = parse_json(&json);
        let result = extract_sandbox_dir(&req).unwrap();
        assert_eq!(result.as_ref().map(|sd| sd.as_str()), Some(dir_str.as_str()));
        let _ = std::fs::remove_dir_all(&dir);
    }

    /// On Windows, a populated sandbox directory is accepted.
    /// Backslashes in the path must be escaped in JSON.
    #[test]
    #[cfg(windows)]
    fn test_extract_sandbox_dir_populated_windows() {
        let dir = std::env::temp_dir().join("pw_test_sandbox_pop_win");
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(dir.join("marker"), b"").unwrap();
        let dir_str = dir.to_string_lossy().into_owned();
        let escaped = dir_str.replace('\\', "\\\\");
        let json = format!(r#"{{"requestId": 1, "sandboxDir": "{}"}}"#, escaped);
        let req = parse_json(&json);
        let result = extract_sandbox_dir(&req).unwrap();
        assert_eq!(result.as_ref().map(|sd| sd.as_str()), Some(dir_str.as_str()));
        let _ = std::fs::remove_dir_all(&dir);
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
        let response = build_cancel_response(RequestId(7));
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
    #[cfg(unix)]
    fn test_resolve_sandbox_path_relative_unix() {
        let result = resolve_sandbox_path("bazel-out/k8/bin/pkg", "/sandbox/42");
        assert_eq!(result, "/sandbox/42/bazel-out/k8/bin/pkg");
    }

    #[test]
    #[cfg(windows)]
    fn test_resolve_sandbox_path_relative_windows() {
        // On Windows, Path::join produces backslash separators.
        let result = resolve_sandbox_path("bazel-out/k8/bin/pkg", "/sandbox/42");
        assert_eq!(result, "/sandbox/42\\bazel-out/k8/bin/pkg");
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
        )
        .unwrap();

        assert_eq!(
            env.get("STAMPED"),
            Some(&"alice:deadbeef:/real/execroot".to_string())
        );
        assert_eq!(env.get("UNCHANGED"), Some(&"value".to_string()));

        let _ = std::fs::remove_dir_all(&tmp);
    }

    #[test]
    fn test_build_shutdown_response() {
        let response = build_shutdown_response(RequestId(11));
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
        )
        .unwrap();

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

        copy_all_outputs_to_sandbox(&pipeline_dir, &sandbox_dir.display().to_string(), out_rel)
            .unwrap();

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

        copy_all_outputs_to_sandbox(&pipeline_dir, &sandbox_dir.display().to_string(), out_rel)
            .unwrap();

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

    // -------------------------------------------------------------------------
    // PipelineState cancel-tracking unit tests
    // -------------------------------------------------------------------------

    fn make_test_bg() -> BackgroundRustc {
        use std::process::Command;
        BackgroundRustc {
            child: Command::new("sleep").arg("60").spawn().unwrap(),
            diagnostics_before: String::new(),
            stderr_drain: std::thread::spawn(|| String::new()),
            pipeline_root_dir: std::path::PathBuf::from("/tmp"),
            pipeline_output_dir: std::path::PathBuf::from("/tmp"),
            original_out_dir: OutputDir("/tmp".to_string()),
        }
    }

    #[test]
    fn test_pipeline_state_store_and_cancel_metadata_phase() {
        let mut state = PipelineState::new();
        let key = PipelineKey("key1".to_string());
        let _flag = state.register_metadata(RequestId(42), key.clone());
        let bg = make_test_bg();
        assert!(matches!(
            state.store_metadata(&key, RequestId(42), bg),
            StoreBackgroundResult::Stored
        ));
        assert!(state.has_entry("key1"));
        assert!(state.has_request(42));

        let cancelled = state.cancel_by_request_id(RequestId(42));
        assert!(cancelled.kill(), "cancel should kill the child");
        assert!(state.is_empty(), "state should be empty after cancel");
    }

    #[test]
    fn test_pipeline_state_take_for_full_then_cancel() {
        let mut state = PipelineState::new();
        let key = PipelineKey("key1".to_string());
        let _meta_flag = state.register_metadata(RequestId(42), key.clone());
        let bg = make_test_bg();
        assert!(matches!(
            state.store_metadata(&key, RequestId(42), bg),
            StoreBackgroundResult::Stored
        ));

        let _full_flag = state.register_full(RequestId(99), key.clone());
        let (mut taken, child_reaped) = match state.claim_for_full(&key, RequestId(99)) {
            FullRequestAction::Background(bg, child_reaped) => (bg, child_reaped),
            other => panic!("expected background handoff, got {:?}", std::mem::discriminant(&other)),
        };

        assert!(state.has_entry("key1"));
        assert!(state.has_request(99));
        assert!(!state.has_request(42));

        #[cfg(unix)]
        {
            let cancelled = state.cancel_by_request_id(RequestId(99));
            assert!(cancelled.kill(), "cancel should kill via PID for full phase");
            assert!(state.is_empty(), "state should be empty after cancel");
        }

        // Verify child_reaped flag is initially false.
        assert!(!child_reaped.load(Ordering::SeqCst));

        // Reap the child to prevent zombies.
        let _ = taken.child.kill();
        let _ = taken.child.wait();
        let _ = taken.stderr_drain.join();
    }

    #[test]
    fn test_pipeline_state_cancel_nonexistent_request() {
        let mut state = PipelineState::new();
        let cancelled = state.cancel_by_request_id(RequestId(999));
        assert!(!cancelled.kill(), "cancel should return false for unknown request_id");
    }

    #[test]
    fn test_pipeline_state_pre_register_and_cancel() {
        let mut state = PipelineState::new();
        let _flag = state.register_metadata(RequestId(42), PipelineKey("key1".to_string()));
        assert!(state.has_request(42));
        assert!(state.has_entry("key1"));
        assert!(state.has_claim(42));

        // No process stored yet — cancel should not kill (no child).
        let cancelled = state.cancel_by_request_id(RequestId(42));
        assert!(!cancelled.kill(), "cancel should return false when no process was stored");
        // Entry is cleaned up.
        assert!(!state.has_entry("key1"));
        assert!(!state.has_request(42));
    }

    #[test]
    fn test_pipeline_state_cleanup_removes_all_entries() {
        let mut state = PipelineState::new();
        let _flag = state.register_metadata(RequestId(42), PipelineKey("key1".to_string()));
        assert!(state.has_request(42));
        assert!(state.has_claim(42));
        state.cleanup(&PipelineKey("key1".to_string()), RequestId(42));
        assert!(state.is_empty(), "state should be empty after cleanup");
        assert!(!state.has_claim(42), "claim should be removed after cleanup");
    }

    #[test]
    fn test_pipeline_state_register_claim_non_pipelined() {
        let mut state = PipelineState::new();
        let flag = state.register_non_pipelined(RequestId(42));
        assert!(state.has_claim(42));
        assert!(!state.has_entry("any_key"));
        assert!(!flag.load(Ordering::SeqCst));
        state.remove_claim(RequestId(42));
        assert!(!state.has_claim(42));
    }

    #[test]
    fn test_pipeline_state_get_claim_flag() {
        let mut state = PipelineState::new();
        assert!(state.get_claim_flag(RequestId(42)).is_none());
        let flag = state.register_non_pipelined(RequestId(42));
        let retrieved = state.get_claim_flag(RequestId(42)).expect("should find claim flag");
        assert!(Arc::ptr_eq(&flag, &retrieved));
    }

    #[test]
    fn test_fallback_claim_rejects_late_metadata_store() {
        let mut state = PipelineState::new();
        let key = PipelineKey("key1".to_string());
        let _full_flag = state.register_full(RequestId(99), key.clone());
        assert!(matches!(
            state.claim_for_full(&key, RequestId(99)),
            FullRequestAction::Fallback
        ));

        let _late_flag = state.register_metadata(RequestId(42), key.clone());
        let late_bg = make_test_bg();
        let rejected = match state.store_metadata(&key, RequestId(42), late_bg) {
            StoreBackgroundResult::Rejected(bg) => bg,
            _ => panic!("late metadata store should be rejected after fallback claim"),
        };

        assert!(state.has_entry("key1"));
        assert!(state.has_request(99));
        assert!(state.has_request(42));

        state.discard_request(RequestId(42));
        assert!(state.has_entry("key1"));
        assert!(!state.has_request(42));

        let mut rejected = rejected;
        let _ = rejected.child.kill();
        let _ = rejected.child.wait();
        let _ = rejected.stderr_drain.join();

        let cancelled = state.cancel_by_request_id(RequestId(99));
        assert!(!cancelled.kill());
        assert!(state.is_empty());
    }

    #[test]
    fn test_cleanup_key_fully_removes_late_metadata_mappings() {
        let mut state = PipelineState::new();
        let key = PipelineKey("key1".to_string());
        let _flag = state.register_full(RequestId(99), key.clone());
        let _late_flag = state.register_metadata(RequestId(42), key.clone());
        assert!(matches!(
            state.claim_for_full(&key, RequestId(99)),
            FullRequestAction::Fallback
        ));
        let _ = state.cleanup_key_fully(&key);
        assert!(!state.has_entry("key1"));
        assert!(!state.has_request(42));
        assert!(!state.has_request(99));
    }

    /// Regression: CancelledEntry::PidOnly used raw kill(pid, SIGKILL) without
    /// checking whether the child had already been reaped. If the full handler
    /// already called child.wait(), the PID could be recycled and the kill
    /// would hit an unrelated process.
    #[test]
    #[cfg(unix)]
    fn test_pid_only_cancel_respects_child_reaped_flag() {
        use std::process::Command;

        // Spawn a real child so we can observe kill behavior.
        let mut child = Command::new("sleep").arg("60").spawn().unwrap();
        let pid = child.id();

        // Case 1: child_reaped=false → kill should send SIGKILL (child dies).
        let reaped = Arc::new(AtomicBool::new(false));
        let cancelled = CancelledEntry::PidOnly(pid, reaped);
        assert!(cancelled.kill());
        // Child should now be dead. Reap to confirm.
        let status = child.wait().unwrap();
        assert!(!status.success(), "child should have been killed");

        // Case 2: child_reaped=true → kill must NOT send SIGKILL.
        // Use our own PID — if SIGKILL were sent, this test process would die.
        let self_pid = std::process::id();
        let reaped = Arc::new(AtomicBool::new(true));
        let cancelled = CancelledEntry::PidOnly(self_pid, reaped);
        assert!(cancelled.kill());
        // If we're still running, the guard worked.
    }

    /// Regression: build_response blanked output for exit_code==0, silently
    /// discarding rustc warnings from successful compilations.
    #[test]
    fn test_build_response_preserves_warnings_on_success() {
        let warning = "warning: unused variable `x`";
        let response = build_response(0, warning, RequestId(42));
        let parsed = parse_json(&response);
        let JsonValue::Object(map) = parsed else {
            panic!("expected object response");
        };
        let Some(JsonValue::String(output)) = map.get("output") else {
            panic!("expected string output");
        };
        assert_eq!(
            output, warning,
            "build_response should preserve warnings on success (exit_code=0)"
        );
    }
}
