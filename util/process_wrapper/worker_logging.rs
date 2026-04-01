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

//! Worker lifecycle logging utilities.
//!
//! All structured logging for the persistent worker process is centralized here.
//! Log entries are appended to `_pw_state/worker_lifecycle.log` as key-value
//! pairs for easy extraction by tooling.

use std::io::Write;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Instant;

use super::pipeline::RequestKind;
use super::protocol::WorkRequestContext;

pub(crate) fn current_pid() -> u32 {
    std::process::id()
}

pub(crate) fn current_thread_label() -> String {
    format!("{:?}", thread::current().id())
}

pub(crate) fn append_worker_lifecycle_log(message: &str) {
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

pub(crate) struct WorkerLifecycleGuard {
    pid: u32,
    start: Instant,
    request_counter: Arc<AtomicUsize>,
}

impl WorkerLifecycleGuard {
    pub(crate) fn new(argv: &[String], request_counter: &Arc<AtomicUsize>) -> Self {
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

pub(crate) fn install_worker_panic_hook() {
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

fn pipeline_key_label(kind: &RequestKind) -> &str {
    kind.key().map(|key| key.as_str()).unwrap_or("-")
}

pub(crate) fn log_request_received(request: &WorkRequestContext, kind: &RequestKind) {
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

pub(crate) fn log_request_thread_start(request: &WorkRequestContext, kind: &RequestKind) {
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
