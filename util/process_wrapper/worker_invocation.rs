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

//! Shared state for a single rustc invocation.

use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Condvar, Mutex};

use super::exec::send_sigterm;
use super::types::OutputDir;

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

    /// Takes the directories from states that carry them.
    fn take_dirs(&mut self) -> InvocationDirs {
        match self {
            InvocationState::Running { dirs, .. }
            | InvocationState::MetadataReady { dirs, .. }
            | InvocationState::Completed { dirs, .. } => {
                std::mem::take(dirs)
            }
            InvocationState::Pending
            | InvocationState::Failed { .. }
            | InvocationState::ShuttingDown => InvocationDirs::default(),
        }
    }

    /// Converts failed or shutting-down states to `FailureOutput`.
    fn as_failure(&self) -> Option<FailureOutput> {
        match self {
            InvocationState::Completed {
                exit_code,
                diagnostics,
                ..
            } if *exit_code != 0 => Some(FailureOutput {
                exit_code: *exit_code,
                diagnostics: diagnostics.clone(),
            }),
            InvocationState::Failed {
                exit_code,
                diagnostics,
            } => Some(FailureOutput {
                exit_code: *exit_code,
                diagnostics: diagnostics.clone(),
            }),
            InvocationState::ShuttingDown => Some(FailureOutput {
                exit_code: -1,
                diagnostics: "shutdown requested".to_string(),
            }),
            _ => None,
        }
    }

    /// Returns a metadata result once the state can produce one.
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
            InvocationState::Pending | InvocationState::Running { .. } => None,
            _ => self.as_failure().map(Err),
        }
    }

    /// Returns a completion result once the state is terminal.
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
            InvocationState::Pending
            | InvocationState::Running { .. }
            | InvocationState::MetadataReady { .. } => None,
            _ => self.as_failure().map(Err),
        }
    }
}

/// Shared handle to an invocation lifecycle.
///
/// Request threads wait on it while the rustc thread drives transitions.
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

    /// Waits until metadata is ready, the invocation finishes, or shutdown is requested.
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

    /// Waits until the invocation reaches a terminal state.
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

    /// Requests shutdown and sends SIGTERM to any running child process.
    pub fn request_shutdown(&self) {
        self.shutdown_requested.store(true, Ordering::SeqCst);
        let mut state = self
            .state
            .lock()
            .expect("rustc invocation state mutex poisoned");
        if state.is_terminal() {
            return;
        }
        let pid = state.pid();
        *state = InvocationState::ShuttingDown;
        self.cvar.notify_all();
        drop(state);
        // Send SIGTERM outside the lock so the rustc thread can unblock.
        if let Some(pid) = pid {
            send_sigterm(pid);
        }
    }

    pub(crate) fn is_shutdown_requested(&self) -> bool {
        self.shutdown_requested.load(Ordering::SeqCst)
    }

    pub(crate) fn transition_to_running(&self, pid: u32, dirs: InvocationDirs) {
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

    pub(crate) fn transition_to_metadata_ready(
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
        let dirs = state.take_dirs();
        *state = InvocationState::MetadataReady {
            pid,
            diagnostics_before,
            rmeta_path,
            dirs,
        };
        self.cvar.notify_all();
        true
    }

    pub(crate) fn transition_to_finished(&self, exit_code: i32, diagnostics: String) {
        let mut state = self
            .state
            .lock()
            .expect("rustc invocation state mutex poisoned");
        if exit_code == 0 {
            if matches!(*state, InvocationState::ShuttingDown) {
                return;
            }
            let dirs = state.take_dirs();
            *state = InvocationState::Completed {
                exit_code,
                diagnostics,
                dirs,
            };
        } else {
            *state = InvocationState::Failed {
                exit_code,
                diagnostics,
            };
        }
        self.cvar.notify_all();
    }

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
}

// Cleanup is driven explicitly by `RequestCoordinator`.
