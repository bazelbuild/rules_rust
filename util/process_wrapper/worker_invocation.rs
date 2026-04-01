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

//! State machine for a single rustc invocation lifecycle.
//!
//! `RustcInvocation` is shared (via `Arc`) between request threads and a
//! rustc thread. The rustc thread owns the `Child` process and drives
//! state transitions via condvar notifications.

use std::io::BufRead;
use std::path::PathBuf;
use std::process::Child;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Condvar, Mutex};
use std::time::Duration;

use tinyjson::JsonValue;

use super::types::OutputDir;
use crate::rustc::RustcStderrPolicy;

// ---------------------------------------------------------------------------
// Data types
// ---------------------------------------------------------------------------

/// Directories associated with a pipelined invocation.
#[derive(Clone, Debug, Default)]
pub(crate) struct InvocationDirs {
    pub pipeline_output_dir: PathBuf,
    pub pipeline_root_dir: PathBuf,
    pub original_out_dir: OutputDir,
}

/// Returned from `wait_for_metadata` on success.
pub(crate) struct MetadataOutput {
    pub diagnostics_before: String,
    /// Path to the .rmeta artifact (from rustc's artifact notification).
    pub rmeta_path: Option<String>,
}

/// Returned from `wait_for_completion` on success.
#[derive(Debug)]
pub(crate) struct CompletionOutput {
    pub exit_code: i32,
    pub diagnostics: String,
    pub dirs: InvocationDirs,
}

/// Returned from wait methods on failure.
#[derive(Debug)]
pub(crate) struct FailureOutput {
    pub exit_code: i32,
    pub diagnostics: String,
}

// ---------------------------------------------------------------------------
// State enum
// ---------------------------------------------------------------------------

/// The lifecycle state of a single rustc invocation.
pub(crate) enum InvocationState {
    Pending,
    Running {
        pid: u32,
        dirs: InvocationDirs,
    },
    MetadataReady {
        pid: u32,
        diagnostics_before: String,
        rmeta_path: Option<String>,
        dirs: InvocationDirs,
    },
    Completed {
        exit_code: i32,
        diagnostics: String,
        dirs: InvocationDirs,
    },
    Failed {
        exit_code: i32,
        diagnostics: String,
    },
    ShuttingDown,
}

impl InvocationState {
    fn is_terminal(&self) -> bool {
        matches!(
            self,
            InvocationState::Completed { .. }
                | InvocationState::Failed { .. }
                | InvocationState::ShuttingDown
        )
    }

    /// Returns the child PID if the state has one (Running or MetadataReady).
    fn pid(&self) -> Option<u32> {
        match self {
            InvocationState::Running { pid, .. } | InvocationState::MetadataReady { pid, .. } => {
                Some(*pid)
            }
            _ => None,
        }
    }

    /// Consume this state and return its `dirs`, or a default if the variant has none.
    fn into_dirs(self) -> InvocationDirs {
        match self {
            InvocationState::Running { dirs, .. }
            | InvocationState::MetadataReady { dirs, .. }
            | InvocationState::Completed { dirs, .. } => dirs,
            InvocationState::Pending
            | InvocationState::Failed { .. }
            | InvocationState::ShuttingDown => InvocationDirs::default(),
        }
    }

    /// If the state is ready for a metadata response, convert to a result.
    /// Returns `None` for non-terminal, non-metadata-ready states (Pending, Running).
    fn as_metadata_result(&self) -> Option<Result<MetadataOutput, FailureOutput>> {
        match self {
            InvocationState::MetadataReady {
                diagnostics_before,
                rmeta_path,
                ..
            } => Some(Ok(MetadataOutput {
                diagnostics_before: diagnostics_before.clone(),
                rmeta_path: rmeta_path.clone(),
            })),
            InvocationState::Completed {
                exit_code: 0,
                diagnostics,
                ..
            } => Some(Ok(MetadataOutput {
                diagnostics_before: diagnostics.clone(),
                rmeta_path: None,
            })),
            InvocationState::Completed {
                exit_code,
                diagnostics,
                ..
            }
            | InvocationState::Failed {
                exit_code,
                diagnostics,
            } => Some(Err(FailureOutput {
                exit_code: *exit_code,
                diagnostics: diagnostics.clone(),
            })),
            InvocationState::ShuttingDown => Some(Err(FailureOutput {
                exit_code: -1,
                diagnostics: "shutdown requested".to_string(),
            })),
            InvocationState::Pending | InvocationState::Running { .. } => None,
        }
    }

    /// If the state is terminal, convert to a completion result.
    /// Returns `None` for non-terminal states (Pending, Running, MetadataReady).
    fn as_completion_result(&self) -> Option<Result<CompletionOutput, FailureOutput>> {
        match self {
            InvocationState::Completed {
                exit_code,
                diagnostics,
                dirs,
            } => Some(Ok(CompletionOutput {
                exit_code: *exit_code,
                diagnostics: diagnostics.clone(),
                dirs: dirs.clone(),
            })),
            InvocationState::Failed {
                exit_code,
                diagnostics,
            } => Some(Err(FailureOutput {
                exit_code: *exit_code,
                diagnostics: diagnostics.clone(),
            })),
            InvocationState::ShuttingDown => Some(Err(FailureOutput {
                exit_code: -1,
                diagnostics: "shutdown requested".to_string(),
            })),
            InvocationState::Pending
            | InvocationState::Running { .. }
            | InvocationState::MetadataReady { .. } => None,
        }
    }
}

// ---------------------------------------------------------------------------
// Platform-specific kill helpers
// ---------------------------------------------------------------------------

#[cfg(unix)]
unsafe extern "C" {
    fn kill(pid: i32, sig: i32) -> i32;
}

#[cfg(unix)]
fn send_sigterm(pid: u32) {
    if pid > i32::MAX as u32 {
        return; // Prevent wrapping to negative (process group kill).
    }
    unsafe {
        kill(pid as i32, 15); // SIGTERM
    }
}

#[cfg(not(unix))]
fn send_sigterm(_pid: u32) {
    // No SIGTERM on non-Unix; graceful_kill will use Child::kill().
}

/// Send SIGTERM, poll try_wait for 500ms (10 x 50ms), then SIGKILL + wait.
pub(crate) fn graceful_kill(child: &mut Child) {
    #[cfg(unix)]
    {
        send_sigterm(child.id());
        for _ in 0..10 {
            match child.try_wait() {
                Ok(Some(_)) => return,
                _ => std::thread::sleep(Duration::from_millis(50)),
            }
        }
        let _ = child.kill();
        let _ = child.wait();
    }
    #[cfg(not(unix))]
    {
        let _ = child.kill();
        let _ = child.wait();
    }
}

// ---------------------------------------------------------------------------
// RustcInvocation — shared handle
// ---------------------------------------------------------------------------

/// Shared handle to an invocation's lifecycle.
///
/// Always used behind `Arc<RustcInvocation>`. The rustc thread holds a clone
/// of that `Arc` for driving state transitions; request threads use
/// `wait_for_metadata` / `wait_for_completion` to block on progress.
pub(crate) struct RustcInvocation {
    state: Mutex<InvocationState>,
    cvar: Condvar,
    shutdown_requested: AtomicBool,
}

impl RustcInvocation {
    pub fn new() -> Self {
        RustcInvocation {
            state: Mutex::new(InvocationState::Pending),
            cvar: Condvar::new(),
            shutdown_requested: AtomicBool::new(false),
        }
    }

    /// Block until metadata is ready, the invocation completes, or shutdown is requested.
    ///
    /// If the invocation went directly to `Completed` with exit_code == 0 (e.g. the
    /// full compilation finished before we got scheduled), we return Ok with the
    /// diagnostics as `diagnostics_before`.
    pub fn wait_for_metadata(&self) -> Result<MetadataOutput, FailureOutput> {
        let mut state = self
            .state
            .lock()
            .expect("rustc invocation state mutex poisoned");
        loop {
            if let Some(result) = state.as_metadata_result() {
                return result;
            }
            state = self
                .cvar
                .wait(state)
                .expect("rustc invocation state mutex poisoned while waiting");
        }
    }

    /// Block until the invocation reaches a terminal state (Completed/Failed/ShuttingDown).
    pub fn wait_for_completion(&self) -> Result<CompletionOutput, FailureOutput> {
        let mut state = self
            .state
            .lock()
            .expect("rustc invocation state mutex poisoned");
        loop {
            if let Some(result) = state.as_completion_result() {
                return result;
            }
            state = self
                .cvar
                .wait(state)
                .expect("rustc invocation state mutex poisoned while waiting");
        }
    }

    /// Request graceful shutdown. Transitions to ShuttingDown and sends SIGTERM
    /// to the child process if one is running.
    pub fn request_shutdown(&self) {
        self.shutdown_requested.store(true, Ordering::SeqCst);
        let mut state = self
            .state
            .lock()
            .expect("rustc invocation state mutex poisoned");
        if state.is_terminal() {
            return; // Already done — nothing to shut down.
        }
        let pid = state.pid();
        *state = InvocationState::ShuttingDown;
        self.cvar.notify_all();
        drop(state);
        // Send SIGTERM outside the lock to unblock any blocking read_line in rustc thread.
        if let Some(pid) = pid {
            send_sigterm(pid);
        }
    }

    // -----------------------------------------------------------------------
    // Rustc-thread transition methods
    // -----------------------------------------------------------------------

    fn is_shutdown_requested(&self) -> bool {
        self.shutdown_requested.load(Ordering::SeqCst)
    }

    fn transition_to_running(&self, pid: u32, dirs: InvocationDirs) {
        let mut state = self
            .state
            .lock()
            .expect("rustc invocation state mutex poisoned");
        if matches!(*state, InvocationState::ShuttingDown) {
            return;
        }
        *state = InvocationState::Running { pid, dirs };
        self.cvar.notify_all();
    }

    fn transition_to_metadata_ready(
        &self,
        pid: u32,
        diagnostics_before: String,
        rmeta_path: Option<String>,
    ) -> bool {
        let mut state = self
            .state
            .lock()
            .expect("rustc invocation state mutex poisoned");
        if matches!(*state, InvocationState::ShuttingDown) {
            return false;
        }
        let old = std::mem::replace(&mut *state, InvocationState::Pending);
        *state = InvocationState::MetadataReady {
            pid,
            diagnostics_before,
            rmeta_path,
            dirs: old.into_dirs(),
        };
        self.cvar.notify_all();
        true
    }

    fn transition_to_finished(&self, exit_code: i32, diagnostics: String) {
        let mut state = self
            .state
            .lock()
            .expect("rustc invocation state mutex poisoned");
        if exit_code == 0 {
            if matches!(*state, InvocationState::ShuttingDown) {
                return;
            }
            let old = std::mem::replace(&mut *state, InvocationState::Pending);
            *state = InvocationState::Completed {
                exit_code,
                diagnostics,
                dirs: old.into_dirs(),
            };
        } else {
            *state = InvocationState::Failed {
                exit_code,
                diagnostics,
            };
        }
        self.cvar.notify_all();
    }

    // -----------------------------------------------------------------------
    // Test-only accessors
    // -----------------------------------------------------------------------

    #[cfg(test)]
    pub fn is_pending(&self) -> bool {
        matches!(
            *self
                .state
                .lock()
                .expect("rustc invocation state mutex poisoned"),
            InvocationState::Pending
        )
    }

    #[cfg(test)]
    pub fn is_shutting_down_or_terminal(&self) -> bool {
        let state = self
            .state
            .lock()
            .expect("rustc invocation state mutex poisoned");
        matches!(
            *state,
            InvocationState::ShuttingDown
                | InvocationState::Completed { .. }
                | InvocationState::Failed { .. }
        )
    }

    /// Test helper: directly transition to Completed (bypasses rustc thread).
    #[cfg(test)]
    pub fn force_completed(&self, exit_code: i32, diagnostics: String, dirs: InvocationDirs) {
        let mut state = self
            .state
            .lock()
            .expect("rustc invocation state mutex poisoned");
        *state = InvocationState::Completed {
            exit_code,
            diagnostics,
            dirs,
        };
        self.cvar.notify_all();
    }
}

// No Drop impl — cleanup is driven explicitly by `RequestCoordinator::cancel()`
// and `RequestCoordinator::shutdown_all()`, which call `request_shutdown()`.

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

/// Extracts the artifact path from an rmeta artifact notification JSON line.
/// Returns `Some(path)` for `{"artifact":"path/to/lib.rmeta","emit":"metadata"}`,
/// `None` for all other lines.
pub(crate) fn extract_rmeta_path(line: &str) -> Option<String> {
    if let Ok(JsonValue::Object(ref map)) = line.parse::<JsonValue>()
        && let Some(JsonValue::String(artifact)) = map.get("artifact")
        && let Some(JsonValue::String(emit)) = map.get("emit")
        && artifact.ends_with(".rmeta")
        && emit == "metadata"
    {
        Some(artifact.clone())
    } else {
        None
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
            if let Some(rmeta_path) = extract_rmeta_path(&line) {
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
            if extract_rmeta_path(&line).is_some() {
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
