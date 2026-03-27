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
//! `RustcInvocation` is the shared handle held by request threads; `MonitorHandle`
//! is given to the monitor thread that owns the `Child` process and drives state
//! transitions via condvar notifications.

use std::io::BufRead;
use std::path::PathBuf;
use std::process::Child;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Condvar, Mutex};
use std::time::Duration;

use super::pipeline::extract_rmeta_path;
use super::types::OutputDir;
use crate::rustc::RustcStderrPolicy;

// ---------------------------------------------------------------------------
// Data types
// ---------------------------------------------------------------------------

/// Directories associated with a pipelined invocation.
#[derive(Clone, Debug)]
pub(crate) struct InvocationDirs {
    pub pipeline_output_dir: PathBuf,
    pub pipeline_root_dir: PathBuf,
    pub original_out_dir: OutputDir,
}

/// Returned from `wait_for_metadata` on success.
pub(crate) struct MetadataResult {
    pub diagnostics_before: String,
}

/// Returned from `wait_for_completion` on success.
pub(crate) struct CompletionResult {
    pub exit_code: i32,
    pub diagnostics: String,
    pub dirs: InvocationDirs,
}

/// Returned from wait methods on failure.
#[derive(Debug)]
pub(crate) struct FailureResult {
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
}

// ---------------------------------------------------------------------------
// Platform-specific kill helpers
// ---------------------------------------------------------------------------

#[cfg(unix)]
extern "C" {
    fn kill(pid: i32, sig: i32) -> i32;
}

#[cfg(unix)]
fn send_sigterm(pid: u32) {
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
        unsafe {
            kill(child.id() as i32, 15); // SIGTERM
        }
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

/// Shared handle to an invocation's lifecycle, held by request threads.
pub(crate) struct RustcInvocation {
    inner: Arc<(Mutex<InvocationState>, Condvar)>,
    shutdown_requested: Arc<AtomicBool>,
}

impl RustcInvocation {
    pub fn new() -> Self {
        RustcInvocation {
            inner: Arc::new((Mutex::new(InvocationState::Pending), Condvar::new())),
            shutdown_requested: Arc::new(AtomicBool::new(false)),
        }
    }

    /// Create a `MonitorHandle` for the monitor thread.
    pub fn monitor_handle(&self) -> MonitorHandle {
        MonitorHandle {
            inner: Arc::clone(&self.inner),
            shutdown_requested: Arc::clone(&self.shutdown_requested),
        }
    }

    /// Block until metadata is ready, the invocation completes, or shutdown is requested.
    ///
    /// If the invocation went directly to `Completed` with exit_code == 0 (e.g. the
    /// full compilation finished before we got scheduled), we return Ok with the
    /// diagnostics as `diagnostics_before`.
    pub fn wait_for_metadata(&self) -> Result<MetadataResult, FailureResult> {
        let (lock, cvar) = &*self.inner;
        let mut state = lock.lock().unwrap();
        loop {
            match &*state {
                InvocationState::MetadataReady {
                    diagnostics_before, ..
                } => {
                    let result = MetadataResult {
                        diagnostics_before: diagnostics_before.clone(),
                    };
                    return Ok(result);
                }
                InvocationState::Completed {
                    exit_code,
                    diagnostics,
                    ..
                } => {
                    if *exit_code == 0 {
                        return Ok(MetadataResult {
                            diagnostics_before: diagnostics.clone(),
                        });
                    } else {
                        return Err(FailureResult {
                            exit_code: *exit_code,
                            diagnostics: diagnostics.clone(),
                        });
                    }
                }
                InvocationState::Failed {
                    exit_code,
                    diagnostics,
                } => {
                    return Err(FailureResult {
                        exit_code: *exit_code,
                        diagnostics: diagnostics.clone(),
                    });
                }
                InvocationState::ShuttingDown => {
                    return Err(FailureResult {
                        exit_code: -1,
                        diagnostics: "shutdown requested".to_string(),
                    });
                }
                InvocationState::Pending | InvocationState::Running { .. } => {
                    state = cvar.wait(state).unwrap();
                }
            }
        }
    }

    /// Block until the invocation reaches a terminal state (Completed/Failed/ShuttingDown).
    pub fn wait_for_completion(&self) -> Result<CompletionResult, FailureResult> {
        let (lock, cvar) = &*self.inner;
        let mut state = lock.lock().unwrap();
        loop {
            match &*state {
                InvocationState::Completed {
                    exit_code,
                    diagnostics,
                    dirs,
                } => {
                    return Ok(CompletionResult {
                        exit_code: *exit_code,
                        diagnostics: diagnostics.clone(),
                        dirs: dirs.clone(),
                    });
                }
                InvocationState::Failed {
                    exit_code,
                    diagnostics,
                } => {
                    return Err(FailureResult {
                        exit_code: *exit_code,
                        diagnostics: diagnostics.clone(),
                    });
                }
                InvocationState::ShuttingDown => {
                    return Err(FailureResult {
                        exit_code: -1,
                        diagnostics: "shutdown requested".to_string(),
                    });
                }
                InvocationState::Pending
                | InvocationState::Running { .. }
                | InvocationState::MetadataReady { .. } => {
                    state = cvar.wait(state).unwrap();
                }
            }
        }
    }

    /// Request graceful shutdown. Transitions to ShuttingDown and sends SIGTERM
    /// to the child process if one is running.
    pub fn request_shutdown(&self) {
        self.shutdown_requested.store(true, Ordering::SeqCst);
        let (lock, cvar) = &*self.inner;
        let mut state = lock.lock().unwrap();
        if state.is_terminal() {
            return; // Already done — nothing to shut down.
        }
        // Extract PID before overwriting state.
        let pid = match &*state {
            InvocationState::Running { pid, .. } | InvocationState::MetadataReady { pid, .. } => {
                Some(*pid)
            }
            _ => None,
        };
        *state = InvocationState::ShuttingDown;
        cvar.notify_all();
        drop(state);
        // Send SIGTERM outside the lock to unblock any blocking read_line in monitor.
        if let Some(pid) = pid {
            send_sigterm(pid);
        }
    }

    // -----------------------------------------------------------------------
    // Test-only accessors
    // -----------------------------------------------------------------------

    #[cfg(test)]
    pub fn is_pending(&self) -> bool {
        let (lock, _) = &*self.inner;
        matches!(*lock.lock().unwrap(), InvocationState::Pending)
    }

    #[cfg(test)]
    pub fn is_shutting_down_or_terminal(&self) -> bool {
        let (lock, _) = &*self.inner;
        let state = lock.lock().unwrap();
        matches!(
            *state,
            InvocationState::ShuttingDown
                | InvocationState::Completed { .. }
                | InvocationState::Failed { .. }
        )
    }

    /// Test helper: directly transition to Completed (bypasses monitor).
    #[cfg(test)]
    pub fn transition_to_completed(
        &self,
        exit_code: i32,
        diagnostics: String,
        dirs: InvocationDirs,
    ) {
        let (lock, cvar) = &*self.inner;
        let mut state = lock.lock().unwrap();
        *state = InvocationState::Completed {
            exit_code,
            diagnostics,
            dirs,
        };
        cvar.notify_all();
    }

    #[cfg(test)]
    pub fn inner_arc(&self) -> &Arc<(Mutex<InvocationState>, Condvar)> {
        &self.inner
    }
}

impl Clone for RustcInvocation {
    fn clone(&self) -> Self {
        RustcInvocation {
            inner: Arc::clone(&self.inner),
            shutdown_requested: Arc::clone(&self.shutdown_requested),
        }
    }
}

impl Drop for RustcInvocation {
    fn drop(&mut self) {
        // Only act if we hold the last external reference (besides MonitorHandle copies).
        // Always try to transition to ShuttingDown if not already terminal.
        let (lock, cvar) = &*self.inner;
        if let Ok(mut state) = lock.lock() {
            if !state.is_terminal() {
                let pid = match &*state {
                    InvocationState::Running { pid, .. }
                    | InvocationState::MetadataReady { pid, .. } => Some(*pid),
                    _ => None,
                };
                *state = InvocationState::ShuttingDown;
                cvar.notify_all();
                drop(state);
                if let Some(pid) = pid {
                    send_sigterm(pid);
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// MonitorHandle — given to the monitor thread
// ---------------------------------------------------------------------------

/// Handle given to the monitor thread for driving state transitions.
pub(crate) struct MonitorHandle {
    inner: Arc<(Mutex<InvocationState>, Condvar)>,
    shutdown_requested: Arc<AtomicBool>,
}

impl MonitorHandle {
    /// Check if shutdown has been requested.
    pub fn is_shutdown_requested(&self) -> bool {
        self.shutdown_requested.load(Ordering::SeqCst)
    }

    /// Transition from Pending to Running. No-op if ShuttingDown.
    pub fn transition_to_running(&self, pid: u32, dirs: InvocationDirs) {
        let (lock, cvar) = &*self.inner;
        let mut state = lock.lock().unwrap();
        if matches!(*state, InvocationState::ShuttingDown) {
            return;
        }
        *state = InvocationState::Running { pid, dirs };
        cvar.notify_all();
    }

    /// Transition to MetadataReady. Returns false if ShuttingDown (metadata
    /// notification was too late).
    pub fn transition_to_metadata_ready(
        &self,
        pid: u32,
        diagnostics_before: String,
        dirs: InvocationDirs,
    ) -> bool {
        let (lock, cvar) = &*self.inner;
        let mut state = lock.lock().unwrap();
        if matches!(*state, InvocationState::ShuttingDown) {
            return false;
        }
        *state = InvocationState::MetadataReady {
            pid,
            diagnostics_before,
            dirs,
        };
        cvar.notify_all();
        true
    }

    /// Transition to Completed. Always overwrites (terminal state).
    pub fn transition_to_completed(&self, exit_code: i32, diagnostics: String, dirs: InvocationDirs) {
        let (lock, cvar) = &*self.inner;
        let mut state = lock.lock().unwrap();
        *state = InvocationState::Completed {
            exit_code,
            diagnostics,
            dirs,
        };
        cvar.notify_all();
    }

    /// Transition to Failed. Always overwrites (terminal state).
    pub fn transition_to_failed(&self, exit_code: i32, diagnostics: String) {
        let (lock, cvar) = &*self.inner;
        let mut state = lock.lock().unwrap();
        *state = InvocationState::Failed {
            exit_code,
            diagnostics,
        };
        cvar.notify_all();
    }
}

// ---------------------------------------------------------------------------
// spawn_pipelined_monitor — monitor thread for a pipelined rustc invocation
// ---------------------------------------------------------------------------

/// Spawn a monitor thread that owns the rustc child process and drives state
/// transitions on the `RustcInvocation`.
///
/// The thread reads stderr line-by-line, processes diagnostics, detects the
/// rmeta artifact notification, and transitions through Running → MetadataReady
/// → Completed (or Failed). On shutdown request, the child is killed via
/// `graceful_kill`.
pub(crate) fn spawn_pipelined_monitor(
    invocation: &RustcInvocation,
    mut child: Child,
    dirs: InvocationDirs,
    rustc_output_format: Option<String>,
) -> std::thread::JoinHandle<()> {
    let monitor = invocation.monitor_handle();
    let pid = child.id();
    let stderr = child
        .stderr
        .take()
        .expect("child must be spawned with Stdio::piped() stderr");

    monitor.transition_to_running(pid, dirs.clone());

    std::thread::spawn(move || {
        let reader = std::io::BufReader::new(stderr);
        let mut policy =
            RustcStderrPolicy::from_option_str(rustc_output_format.as_deref());

        let mut diagnostics = String::new();
        let mut metadata_emitted = false;
        let mut diagnostics_before = String::new();

        for line_result in reader.lines() {
            let line = match line_result {
                Ok(l) => l,
                Err(_) => break,
            };

            let trimmed = line.trim_end_matches('\n').trim_end_matches('\r');

            // Check for rmeta artifact notification before processing as diagnostic.
            if !metadata_emitted {
                if let Some(_rmeta_path) = extract_rmeta_path(trimmed) {
                    metadata_emitted = true;
                    diagnostics_before = diagnostics.clone();
                    monitor.transition_to_metadata_ready(
                        pid,
                        diagnostics_before.clone(),
                        dirs.clone(),
                    );
                    // Don't add the artifact JSON line to diagnostics output.
                    continue;
                }
            } else {
                // After metadata, still skip artifact lines from diagnostics.
                if extract_rmeta_path(trimmed).is_some() {
                    continue;
                }
            }

            if let Some(processed) = policy.process_line(trimmed) {
                if !diagnostics.is_empty() {
                    diagnostics.push('\n');
                }
                diagnostics.push_str(&processed);
            }
        }

        // stderr EOF — child has closed its stderr (likely exiting).
        if monitor.is_shutdown_requested() {
            graceful_kill(&mut child);
            monitor.transition_to_failed(-1, "shutdown requested".to_string());
            return;
        }

        let exit_code = match child.wait() {
            Ok(status) => status.code().unwrap_or(-1),
            Err(_) => -1,
        };

        if exit_code == 0 && metadata_emitted {
            monitor.transition_to_completed(exit_code, diagnostics, dirs);
        } else {
            // If we never emitted metadata but exit_code == 0, that's still
            // a failure from the pipelining perspective (no rmeta produced).
            // However, treat exit_code == 0 without metadata as completed
            // to allow non-pipelined rustc to work through this path.
            if exit_code == 0 {
                monitor.transition_to_completed(exit_code, diagnostics, dirs);
            } else {
                monitor.transition_to_failed(exit_code, diagnostics);
            }
        }
    })
}
