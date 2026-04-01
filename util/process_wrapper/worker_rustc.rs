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

//! Rustc process driver threads for the persistent worker.
//!
//! These functions spawn background threads that own the rustc `Child` process
//! and drive state transitions on a shared `RustcInvocation`. The invocation
//! state machine itself lives in `worker_invocation.rs`.

use std::io::BufRead;
use std::process::Child;
use std::sync::Arc;

use super::exec::graceful_kill;
use super::invocation::{InvocationDirs, RustcInvocation};
use crate::rustc::RustcStderrPolicy;

// ---------------------------------------------------------------------------
// spawn_non_pipelined_rustc — rustc thread for a non-pipelined invocation
// ---------------------------------------------------------------------------

/// Spawn a thread for a non-pipelined subprocess (e.g. nested
/// process_wrapper). Creates a new `RustcInvocation`, transitions it to
/// Running, then spawns a thread that blocks on `wait_with_output()` and
/// transitions to Completed or Failed based on the exit code.
///
/// On shutdown, `request_shutdown()` sends SIGTERM to the child PID (stored in
/// the Running state), which causes `wait_with_output()` to return. The rustc
/// thread then detects the shutdown flag and transitions to Failed.
pub(crate) fn spawn_non_pipelined_rustc(child: Child) -> Arc<RustcInvocation> {
    let invocation = Arc::new(RustcInvocation::new());
    let pid = child.id();

    // Non-pipelined invocations don't use pipeline dirs — use defaults.
    invocation.transition_to_running(pid, InvocationDirs::default());

    let ret = Arc::clone(&invocation);
    std::thread::spawn(move || {
        let output = child.wait_with_output();

        if invocation.is_shutdown_requested() {
            invocation.transition_to_finished(-1, "shutdown requested".to_string());
            return;
        }

        let (exit_code, diagnostics) = match output {
            Ok(output) => {
                let exit_code = output.status.code().unwrap_or(-1);
                let stdout = String::from_utf8_lossy(&output.stdout);
                let stderr = String::from_utf8_lossy(&output.stderr);
                let mut diagnostics = String::new();
                if !stderr.is_empty() {
                    diagnostics.push_str(&stderr);
                }
                if !stdout.is_empty() {
                    if !diagnostics.is_empty() {
                        diagnostics.push('\n');
                    }
                    diagnostics.push_str(&stdout);
                }
                (exit_code, diagnostics)
            }
            Err(e) => (-1, format!("wait_with_output failed: {}", e)),
        };

        invocation.transition_to_finished(exit_code, diagnostics);
    });

    ret
}

// ---------------------------------------------------------------------------
// Artifact detection
// ---------------------------------------------------------------------------

/// Processes a single stderr line through the policy and appends to diagnostics.
fn accumulate_diagnostic(line: &str, policy: &mut RustcStderrPolicy, diagnostics: &mut String) {
    if let Some(processed) = policy.process_line(line) {
        if !diagnostics.is_empty() {
            diagnostics.push('\n');
        }
        diagnostics.push_str(&processed);
    }
}

// ---------------------------------------------------------------------------
// spawn_pipelined_rustc — rustc thread for a pipelined invocation
// ---------------------------------------------------------------------------

/// Spawn a thread that owns the rustc child process and drives state
/// transitions on a new `RustcInvocation`.
///
/// Creates the invocation internally and returns it (like
/// `spawn_non_pipelined_rustc`). The caller should insert the returned
/// invocation into the registry so that the full request can find it.
///
/// The thread reads stderr line-by-line, processes diagnostics, detects the
/// rmeta artifact notification, and transitions through Running → MetadataReady
/// → Completed (or Failed). On shutdown request, the child is killed via
/// `graceful_kill`.
pub(crate) fn spawn_pipelined_rustc(
    mut child: Child,
    dirs: InvocationDirs,
    rustc_output_format: Option<String>,
) -> Arc<RustcInvocation> {
    let invocation = Arc::new(RustcInvocation::new());
    let pid = child.id();
    let stderr = child
        .stderr
        .take()
        .expect("child must be spawned with Stdio::piped() stderr");

    invocation.transition_to_running(pid, dirs);

    let ret = Arc::clone(&invocation);
    std::thread::spawn(move || {
        let reader = std::io::BufReader::new(stderr);
        let mut policy = RustcStderrPolicy::from_option_str(rustc_output_format.as_deref());

        let mut diagnostics = String::new();
        let mut lines = reader.lines().map_while(Result::ok);

        // Phase 1: process lines until metadata (.rmeta) is emitted.
        for line in lines.by_ref() {
            if let Some(rmeta_path) = crate::rustc::extract_rmeta_path(&line) {
                invocation.transition_to_metadata_ready(
                    pid,
                    diagnostics.clone(),
                    Some(rmeta_path),
                );
                break;
            }
            accumulate_diagnostic(&line, &mut policy, &mut diagnostics);
        }

        // Phase 2: process remaining lines (codegen diagnostics).
        for line in lines {
            if crate::rustc::extract_rmeta_path(&line).is_some() {
                continue;
            }
            accumulate_diagnostic(&line, &mut policy, &mut diagnostics);
        }

        // stderr EOF — child has closed its stderr (likely exiting).
        if invocation.is_shutdown_requested() {
            graceful_kill(&mut child);
            invocation.transition_to_finished(-1, "shutdown requested".to_string());
            return;
        }

        let exit_code = match child.wait() {
            Ok(status) => status.code().unwrap_or(-1),
            Err(_) => -1,
        };

        invocation.transition_to_finished(exit_code, diagnostics);
    });

    ret
}
