# Unified Request Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the split-state `PipelineState` with a `RequestRegistry` + `RustcInvocation` + `BazelRequest` architecture where each rustc process is managed by a monitor thread, all state transitions are atomic, and cleanup happens via `shutdown()` rather than ad-hoc deletion.

**Architecture:** `RustcInvocation` is a shared (`Arc`) state machine driven by a monitor thread that owns the `Child` handle. Request threads wait on a `Condvar` for state transitions. `RequestRegistry` owns invocations by pipeline key, claim flags by request_id, and monitor `JoinHandle`s. `BazelRequest` is a thread-local struct with methods (`execute_metadata`, `execute_full`, `execute_non_pipelined`) that interact with invocations via the registry.

**Tech Stack:** Rust std (`sync::Mutex`, `sync::Condvar`, `sync::Arc`, `process::Child`, `thread`)

**Spec:** `docs/superpowers/specs/2026-03-27-unified-request-lifecycle-design.md`

---

### File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `util/process_wrapper/worker_invocation.rs` | `RustcInvocation`, `InvocationState`, `InvocationDirs`, `MonitorThread`, `graceful_kill` |
| Create | `util/process_wrapper/worker_request.rs` | `BazelRequest` and its `execute_*` methods |
| Create | `util/process_wrapper/worker_registry.rs` | `RequestRegistry` (replaces `PipelineState`) |
| Modify | `util/process_wrapper/worker.rs` | Module declarations, `worker_main`, `run_request_thread` — rewire to use new types |
| Modify | `util/process_wrapper/worker_pipeline.rs` | Remove `PipelineState`, `PipelinePhase`, `BackgroundRustc`, `CancelledEntry`, cleanup functions. Keep utility functions (arg parsing, output copying, context creation, etc.) |
| Modify | `util/process_wrapper/worker_types.rs` | Add `InvocationId` type if needed (probably reuse `PipelineKey`) |
| Modify | `util/process_wrapper/test/worker.rs` | Replace old `PipelineState` tests with `RequestRegistry`/`RustcInvocation` tests |

---

### Task 1: `RustcInvocation` — State Machine and Monitor Thread

**Files:**
- Create: `util/process_wrapper/worker_invocation.rs`
- Modify: `util/process_wrapper/worker.rs:19-26` (add module declaration)
- Test: `util/process_wrapper/test/worker.rs`

- [ ] **Step 1: Write failing test — invocation state transitions**

Add to `util/process_wrapper/test/worker.rs`:

```rust
use super::invocation::{InvocationDirs, InvocationState, RustcInvocation};

#[test]
fn test_invocation_pending_to_running() {
    let inv = RustcInvocation::new();
    assert!(inv.is_pending());
}

#[test]
fn test_invocation_wait_for_metadata_on_completed_returns_err() {
    // A non-pipelined invocation goes Running -> Completed (skips MetadataReady).
    // wait_for_metadata should return Err because MetadataReady was never reached.
    let inv = RustcInvocation::new();
    // Simulate: transition directly to Completed (as a non-pipelined monitor would).
    inv.transition_to_completed(0, "all good".to_string(), InvocationDirs {
        pipeline_output_dir: PathBuf::from("/tmp/out"),
        pipeline_root_dir: PathBuf::from("/tmp/root"),
        original_out_dir: OutputDir::default(),
    });
    let result = inv.wait_for_completion();
    assert!(result.is_ok());
    let completion = result.unwrap();
    assert_eq!(completion.exit_code, 0);
    assert_eq!(completion.diagnostics, "all good");
}

#[test]
fn test_invocation_shutdown_from_pending() {
    let inv = RustcInvocation::new();
    inv.request_shutdown();
    assert!(inv.is_shutting_down_or_terminal());
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /var/mnt/dev/rules_rust && bazel test //util/process_wrapper:process_wrapper_test --nocache_test_results --test_output=errors 2>&1 | tail -20`
Expected: Compilation error — `invocation` module doesn't exist.

- [ ] **Step 3: Create `worker_invocation.rs` with core types and state machine**

Create `util/process_wrapper/worker_invocation.rs`:

```rust
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Condvar, Mutex};

use super::types::OutputDir;

/// Directories used by a pipelined rustc invocation.
#[derive(Debug, Clone)]
pub(super) struct InvocationDirs {
    pub(super) pipeline_output_dir: PathBuf,
    pub(super) pipeline_root_dir: PathBuf,
    pub(super) original_out_dir: OutputDir,
}

/// Result of waiting for metadata readiness.
pub(super) struct MetadataResult {
    pub(super) diagnostics_before: String,
}

/// Result of waiting for invocation completion.
pub(super) struct CompletionResult {
    pub(super) exit_code: i32,
    pub(super) diagnostics: String,
    pub(super) dirs: InvocationDirs,
}

/// Failure info from a failed or shut-down invocation.
pub(super) struct FailureResult {
    pub(super) exit_code: i32,
    pub(super) diagnostics: String,
}

pub(super) enum InvocationState {
    /// Registered but rustc not yet spawned.
    Pending,
    /// Rustc running, monitor thread active.
    Running {
        pid: u32,
        dirs: InvocationDirs,
    },
    /// rmeta artifact emitted, rustc still running.
    MetadataReady {
        pid: u32,
        diagnostics_before: String,
        dirs: InvocationDirs,
    },
    /// Rustc exited successfully. Outputs available in dirs.
    Completed {
        exit_code: i32,
        diagnostics: String,
        dirs: InvocationDirs,
    },
    /// Rustc exited with error or was killed.
    Failed {
        exit_code: i32,
        diagnostics: String,
    },
    /// Kill in progress. Monitor thread is sending SIGTERM/SIGKILL.
    ShuttingDown,
}

/// A shared handle to a rustc invocation's lifecycle.
///
/// The `Child` handle is owned exclusively by the monitor thread.
/// Request threads interact with the invocation only by waiting on
/// the condvar and reading the state.
pub(crate) struct RustcInvocation {
    inner: Arc<(Mutex<InvocationState>, Condvar)>,
    shutdown_requested: Arc<AtomicBool>,
}

impl Clone for RustcInvocation {
    fn clone(&self) -> Self {
        Self {
            inner: Arc::clone(&self.inner),
            shutdown_requested: Arc::clone(&self.shutdown_requested),
        }
    }
}

impl RustcInvocation {
    pub(super) fn new() -> Self {
        Self {
            inner: Arc::new((Mutex::new(InvocationState::Pending), Condvar::new())),
            shutdown_requested: Arc::new(AtomicBool::new(false)),
        }
    }

    /// Returns a handle the monitor thread uses to drive state transitions.
    pub(super) fn monitor_handle(&self) -> MonitorHandle {
        MonitorHandle {
            inner: Arc::clone(&self.inner),
            shutdown_requested: Arc::clone(&self.shutdown_requested),
        }
    }

    /// Blocks until the invocation reaches `MetadataReady`, `Completed`, `Failed`,
    /// or `ShuttingDown`.
    pub(super) fn wait_for_metadata(&self) -> Result<MetadataResult, FailureResult> {
        let (lock, cvar) = &*self.inner;
        let guard = cvar
            .wait_while(lock.lock().unwrap(), |state| {
                matches!(state, InvocationState::Pending | InvocationState::Running { .. })
            })
            .unwrap();
        match &*guard {
            InvocationState::MetadataReady { diagnostics_before, .. } => {
                Ok(MetadataResult {
                    diagnostics_before: diagnostics_before.clone(),
                })
            }
            InvocationState::Completed { exit_code, diagnostics, .. } => {
                // Rustc finished before we could observe MetadataReady.
                // This happens if the monitor thread transitions Running -> Completed
                // without going through MetadataReady (non-pipelined, or rmeta emitted
                // and completion happened before we got scheduled).
                if *exit_code == 0 {
                    // Successful completion before metadata wait returned — treat the
                    // completion diagnostics as the "before" diagnostics.
                    Ok(MetadataResult {
                        diagnostics_before: diagnostics.clone(),
                    })
                } else {
                    Err(FailureResult {
                        exit_code: *exit_code,
                        diagnostics: diagnostics.clone(),
                    })
                }
            }
            InvocationState::Failed { exit_code, diagnostics } => Err(FailureResult {
                exit_code: *exit_code,
                diagnostics: diagnostics.clone(),
            }),
            InvocationState::ShuttingDown => Err(FailureResult {
                exit_code: 1,
                diagnostics: "invocation shutting down".to_string(),
            }),
            InvocationState::Pending | InvocationState::Running { .. } => {
                unreachable!("wait_while should not return in Pending/Running")
            }
        }
    }

    /// Blocks until the invocation reaches `Completed`, `Failed`, or `ShuttingDown`.
    pub(super) fn wait_for_completion(&self) -> Result<CompletionResult, FailureResult> {
        let (lock, cvar) = &*self.inner;
        let guard = cvar
            .wait_while(lock.lock().unwrap(), |state| {
                matches!(
                    state,
                    InvocationState::Pending
                        | InvocationState::Running { .. }
                        | InvocationState::MetadataReady { .. }
                )
            })
            .unwrap();
        match &*guard {
            InvocationState::Completed { exit_code, diagnostics, dirs } => {
                Ok(CompletionResult {
                    exit_code: *exit_code,
                    diagnostics: diagnostics.clone(),
                    dirs: dirs.clone(),
                })
            }
            InvocationState::Failed { exit_code, diagnostics } => Err(FailureResult {
                exit_code: *exit_code,
                diagnostics: diagnostics.clone(),
            }),
            InvocationState::ShuttingDown => Err(FailureResult {
                exit_code: 1,
                diagnostics: "invocation shutting down".to_string(),
            }),
            _ => unreachable!("wait_while should not return in non-terminal state"),
        }
    }

    /// Requests shutdown. The monitor thread will kill the child process.
    pub(super) fn request_shutdown(&self) {
        self.shutdown_requested.store(true, Ordering::SeqCst);
        let (lock, cvar) = &*self.inner;
        let mut state = lock.lock().unwrap();
        match *state {
            InvocationState::Completed { .. } | InvocationState::Failed { .. } => {
                // Already terminal — nothing to do.
            }
            _ => {
                *state = InvocationState::ShuttingDown;
                cvar.notify_all();
            }
        }
    }

    // --- Transition helpers (used by tests and monitor thread) ---

    /// Transition to Completed. Used by monitor thread via MonitorHandle.
    #[cfg(test)]
    pub(super) fn transition_to_completed(
        &self,
        exit_code: i32,
        diagnostics: String,
        dirs: InvocationDirs,
    ) {
        let (lock, cvar) = &*self.inner;
        let mut state = lock.lock().unwrap();
        *state = InvocationState::Completed { exit_code, diagnostics, dirs };
        cvar.notify_all();
    }

    // --- Test accessors ---

    #[cfg(test)]
    pub(super) fn is_pending(&self) -> bool {
        let (lock, _) = &*self.inner;
        matches!(*lock.lock().unwrap(), InvocationState::Pending)
    }

    #[cfg(test)]
    pub(super) fn is_shutting_down_or_terminal(&self) -> bool {
        let (lock, _) = &*self.inner;
        matches!(
            *lock.lock().unwrap(),
            InvocationState::ShuttingDown
                | InvocationState::Completed { .. }
                | InvocationState::Failed { .. }
        )
    }
}

impl Drop for RustcInvocation {
    fn drop(&mut self) {
        // If this is the last reference (besides the monitor thread's),
        // request shutdown so the monitor thread can clean up.
        // We check strong_count == 2 because the monitor holds one Arc via
        // MonitorHandle. But Arc::strong_count is approximate, so we just
        // always request shutdown if not terminal — it's idempotent.
        let (lock, cvar) = &*self.inner;
        if let Ok(mut state) = lock.lock() {
            match *state {
                InvocationState::Completed { .. }
                | InvocationState::Failed { .. }
                | InvocationState::ShuttingDown => {}
                _ => {
                    self.shutdown_requested.store(true, Ordering::SeqCst);
                    *state = InvocationState::ShuttingDown;
                    cvar.notify_all();
                }
            }
        }
    }
}

/// Handle given to the monitor thread for driving state transitions.
///
/// The monitor thread is the sole owner of the `Child` handle. It reads
/// stderr, detects the rmeta signal, waits for exit, and transitions
/// the invocation state accordingly.
pub(super) struct MonitorHandle {
    inner: Arc<(Mutex<InvocationState>, Condvar)>,
    shutdown_requested: Arc<AtomicBool>,
}

impl MonitorHandle {
    pub(super) fn is_shutdown_requested(&self) -> bool {
        self.shutdown_requested.load(Ordering::SeqCst)
    }

    pub(super) fn transition_to_running(&self, pid: u32, dirs: InvocationDirs) {
        let (lock, cvar) = &*self.inner;
        let mut state = lock.lock().unwrap();
        if matches!(*state, InvocationState::ShuttingDown) {
            return; // Already shutting down, don't overwrite.
        }
        *state = InvocationState::Running { pid, dirs };
        cvar.notify_all();
    }

    pub(super) fn transition_to_metadata_ready(
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
        *state = InvocationState::MetadataReady { pid, diagnostics_before, dirs };
        cvar.notify_all();
        true
    }

    pub(super) fn transition_to_completed(
        &self,
        exit_code: i32,
        diagnostics: String,
        dirs: InvocationDirs,
    ) {
        let (lock, cvar) = &*self.inner;
        let mut state = lock.lock().unwrap();
        *state = InvocationState::Completed { exit_code, diagnostics, dirs };
        cvar.notify_all();
    }

    pub(super) fn transition_to_failed(&self, exit_code: i32, diagnostics: String) {
        let (lock, cvar) = &*self.inner;
        let mut state = lock.lock().unwrap();
        *state = InvocationState::Failed { exit_code, diagnostics };
        cvar.notify_all();
    }
}

/// Sends SIGTERM, waits up to 500ms, then SIGKILL if still alive.
pub(super) fn graceful_kill(child: &mut std::process::Child) {
    #[cfg(unix)]
    {
        unsafe {
            libc::kill(child.id() as i32, libc::SIGTERM);
        }
    }
    #[cfg(not(unix))]
    {
        // On non-Unix, just kill immediately.
        let _ = child.kill();
        let _ = child.wait();
        return;
    }

    // Poll for up to 500ms.
    for _ in 0..10 {
        match child.try_wait() {
            Ok(Some(_)) => return,
            _ => {}
        }
        std::thread::sleep(std::time::Duration::from_millis(50));
    }
    // Still alive — force kill.
    let _ = child.kill();
    let _ = child.wait();
}
```

- [ ] **Step 4: Add module declaration in `worker.rs`**

In `util/process_wrapper/worker.rs`, add after line 26:

```rust
#[path = "worker_invocation.rs"]
pub(crate) mod invocation;
```

- [ ] **Step 5: Update test imports**

In `util/process_wrapper/test/worker.rs`, add to the imports at the top:

```rust
use super::invocation::{InvocationDirs, RustcInvocation};
use std::path::PathBuf;
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd /var/mnt/dev/rules_rust && bazel test //util/process_wrapper:process_wrapper_test --nocache_test_results --test_output=errors 2>&1 | tail -20`
Expected: All tests pass, including the 3 new ones.

- [ ] **Step 7: Commit**

```bash
git add util/process_wrapper/worker_invocation.rs util/process_wrapper/worker.rs util/process_wrapper/test/worker.rs
git commit -m "feat: add RustcInvocation state machine and MonitorHandle"
```

---

### Task 2: `RustcInvocation` — Monitor Thread for Pipelined Rustc

**Files:**
- Modify: `util/process_wrapper/worker_invocation.rs`
- Test: `util/process_wrapper/test/worker.rs`

This task adds the `spawn_monitor_thread` function that creates the monitor thread for a pipelined rustc invocation. The monitor thread owns the `Child`, reads stderr, detects rmeta, waits for exit, and drives state transitions.

- [ ] **Step 1: Write failing test — monitor thread drives pipelined invocation to completion**

Add to `util/process_wrapper/test/worker.rs`:

```rust
#[test]
fn test_monitor_thread_pipelined_completes() {
    use std::process::{Command, Stdio};
    use std::io::Write;
    use super::invocation::spawn_pipelined_monitor;

    // Spawn a process that emits an rmeta-like artifact notification on stderr, then exits.
    // We use `sh -c` to control stderr output precisely.
    let mut child = Command::new("sh")
        .arg("-c")
        // Emit a fake artifact line that extract_rmeta_path will match,
        // then exit successfully.
        .arg(r#"echo '{"artifact":"/tmp/test.rmeta","emit":"metadata"}' >&2; exit 0"#)
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();

    let dirs = InvocationDirs {
        pipeline_output_dir: PathBuf::from("/tmp"),
        pipeline_root_dir: PathBuf::from("/tmp"),
        original_out_dir: OutputDir::default(),
    };

    let inv = RustcInvocation::new();
    let handle = spawn_pipelined_monitor(
        &inv,
        &mut child,
        dirs.clone(),
        None, // no rustc_output_format
    );

    // Metadata should become ready.
    let meta = inv.wait_for_metadata();
    assert!(meta.is_ok(), "metadata should be ready");

    // Completion should follow.
    let result = inv.wait_for_completion();
    assert!(result.is_ok(), "invocation should complete");
    assert_eq!(result.unwrap().exit_code, 0);

    // Monitor thread should exit cleanly.
    handle.join().expect("monitor thread should not panic");
}

#[test]
fn test_monitor_thread_failure_before_rmeta() {
    use std::process::{Command, Stdio};
    use super::invocation::spawn_pipelined_monitor;

    let mut child = Command::new("sh")
        .arg("-c")
        .arg("echo 'error: something broke' >&2; exit 1")
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();

    let dirs = InvocationDirs {
        pipeline_output_dir: PathBuf::from("/tmp"),
        pipeline_root_dir: PathBuf::from("/tmp"),
        original_out_dir: OutputDir::default(),
    };

    let inv = RustcInvocation::new();
    let handle = spawn_pipelined_monitor(&inv, &mut child, dirs, None);

    // Should fail — no rmeta emitted.
    let meta = inv.wait_for_metadata();
    assert!(meta.is_err());

    handle.join().expect("monitor thread should not panic");
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /var/mnt/dev/rules_rust && bazel test //util/process_wrapper:process_wrapper_test --nocache_test_results --test_output=errors 2>&1 | tail -20`
Expected: Compilation error — `spawn_pipelined_monitor` doesn't exist.

- [ ] **Step 3: Implement `spawn_pipelined_monitor`**

Add to `util/process_wrapper/worker_invocation.rs`:

```rust
use std::io::{BufRead, BufReader};
use std::process::Child;
use std::thread;

use crate::rustc::RustcStderrPolicy;
use super::pipeline::extract_rmeta_path;

/// Spawns a monitor thread that:
/// 1. Takes ownership of the child's stderr (caller must have piped it).
/// 2. Reads stderr line-by-line, looking for the rmeta artifact notification.
/// 3. On rmeta: transitions to MetadataReady, continues draining stderr.
/// 4. On EOF: waits for child exit, transitions to Completed or Failed.
/// 5. On shutdown request: sends SIGTERM → SIGKILL, transitions to Failed.
///
/// The `Child` handle is moved into the monitor thread. The caller should NOT
/// retain a reference to the child after calling this function.
///
/// The caller passes the child by `&mut` and this function takes `stderr`
/// from it. The child itself is moved into the thread via the returned closure.
pub(super) fn spawn_pipelined_monitor(
    invocation: &RustcInvocation,
    child: &mut Child,
    dirs: InvocationDirs,
    rustc_output_format: Option<&str>,
) -> thread::JoinHandle<()> {
    let monitor = invocation.monitor_handle();
    let stderr = child.stderr.take().expect("stderr must be piped");
    let pid = child.id();

    // We need to move child into the thread. To do this, we take a raw fd/handle
    // approach... actually, simpler: the caller constructs Child, we take ownership.
    // But the signature takes &mut Child. Let's change the approach: take Child by value.
    //
    // REVISED: caller passes Child by value. See updated signature below.
    todo!("see revised version")
}
```

Actually, let me revise — the caller should pass the `Child` by value so the monitor thread takes full ownership. Revised function:

```rust
/// Spawns a monitor thread for a pipelined rustc invocation.
///
/// Takes ownership of `child`. The monitor thread reads stderr, detects rmeta,
/// waits for exit, and drives invocation state transitions.
pub(super) fn spawn_pipelined_monitor(
    invocation: &RustcInvocation,
    mut child: Child,
    dirs: InvocationDirs,
    rustc_output_format: Option<String>,
) -> thread::JoinHandle<()> {
    let monitor = invocation.monitor_handle();
    let stderr = child.stderr.take().expect("stderr must be piped");
    let pid = child.id();

    monitor.transition_to_running(pid, dirs.clone());

    thread::spawn(move || {
        let mut reader = BufReader::new(stderr);
        let mut diagnostics = String::new();
        let mut policy = RustcStderrPolicy::from_option_str(rustc_output_format.as_deref());
        let mut metadata_emitted = false;

        // Phase 1: Read stderr, looking for rmeta.
        loop {
            if monitor.is_shutdown_requested() {
                graceful_kill(&mut child);
                monitor.transition_to_failed(1, diagnostics);
                return;
            }

            let mut line = String::new();
            match reader.read_line(&mut line) {
                Ok(0) => break, // EOF
                Err(_) => break,
                Ok(_) => {}
            }

            if let Some(output) = policy.process_line(&line) {
                diagnostics.push_str(&output);
            }

            let trimmed = line.trim_end_matches('\n').trim_end_matches('\r');
            if !metadata_emitted {
                if extract_rmeta_path(trimmed).is_some() {
                    metadata_emitted = true;
                    let diagnostics_before = diagnostics.clone();
                    if !monitor.transition_to_metadata_ready(pid, diagnostics_before, dirs.clone()) {
                        // Shutdown was requested while we were transitioning.
                        graceful_kill(&mut child);
                        monitor.transition_to_failed(1, diagnostics);
                        return;
                    }
                    // Continue draining stderr after metadata.
                }
            }
        }

        // Phase 2: stderr EOF — wait for child exit.
        if monitor.is_shutdown_requested() {
            graceful_kill(&mut child);
            monitor.transition_to_failed(1, diagnostics);
            return;
        }

        let exit_code = match child.wait() {
            Ok(status) => status.code().unwrap_or(1),
            Err(_) => 1,
        };

        if metadata_emitted {
            if exit_code == 0 {
                monitor.transition_to_completed(exit_code, diagnostics, dirs);
            } else {
                monitor.transition_to_failed(exit_code, diagnostics);
            }
        } else {
            // Rustc exited without emitting rmeta — compilation error.
            monitor.transition_to_failed(exit_code, diagnostics);
        }
    })
}
```

- [ ] **Step 4: Update test `spawn_pipelined_monitor` call to pass `Child` by value**

The tests from step 1 need the child passed by value. Update the test to not use `&mut child`:

```rust
#[test]
fn test_monitor_thread_pipelined_completes() {
    use std::process::{Command, Stdio};
    use super::invocation::{spawn_pipelined_monitor, InvocationDirs, RustcInvocation};

    let child = Command::new("sh")
        .arg("-c")
        .arg(r#"echo '{"artifact":"/tmp/test.rmeta","emit":"metadata"}' >&2; exit 0"#)
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();

    let dirs = InvocationDirs {
        pipeline_output_dir: PathBuf::from("/tmp"),
        pipeline_root_dir: PathBuf::from("/tmp"),
        original_out_dir: OutputDir::default(),
    };

    let inv = RustcInvocation::new();
    let handle = spawn_pipelined_monitor(&inv, child, dirs.clone(), None);

    let meta = inv.wait_for_metadata();
    assert!(meta.is_ok(), "metadata should be ready");

    let result = inv.wait_for_completion();
    assert!(result.is_ok(), "invocation should complete");
    assert_eq!(result.unwrap().exit_code, 0);

    handle.join().expect("monitor thread should not panic");
}

#[test]
fn test_monitor_thread_failure_before_rmeta() {
    use std::process::{Command, Stdio};
    use super::invocation::{spawn_pipelined_monitor, InvocationDirs, RustcInvocation};

    let child = Command::new("sh")
        .arg("-c")
        .arg("echo 'error: something broke' >&2; exit 1")
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();

    let dirs = InvocationDirs {
        pipeline_output_dir: PathBuf::from("/tmp"),
        pipeline_root_dir: PathBuf::from("/tmp"),
        original_out_dir: OutputDir::default(),
    };

    let inv = RustcInvocation::new();
    let handle = spawn_pipelined_monitor(&inv, child, dirs, None);

    let meta = inv.wait_for_metadata();
    assert!(meta.is_err());

    handle.join().expect("monitor thread should not panic");
}
```

- [ ] **Step 5: Make `extract_rmeta_path` accessible from `worker_invocation.rs`**

In `util/process_wrapper/worker_pipeline.rs`, ensure `extract_rmeta_path` is `pub(super)`:

```rust
pub(super) fn extract_rmeta_path(line: &str) -> Option<String> {
```

(Check current visibility — it may already be `pub(super)`. If not, change it.)

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd /var/mnt/dev/rules_rust && bazel test //util/process_wrapper:process_wrapper_test --nocache_test_results --test_output=errors 2>&1 | tail -20`
Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add util/process_wrapper/worker_invocation.rs util/process_wrapper/test/worker.rs
git commit -m "feat: add spawn_pipelined_monitor for RustcInvocation"
```

---

### Task 3: `RustcInvocation` — Monitor Thread Shutdown

**Files:**
- Modify: `util/process_wrapper/worker_invocation.rs`
- Test: `util/process_wrapper/test/worker.rs`

- [ ] **Step 1: Write failing test — shutdown kills child**

```rust
#[test]
#[cfg(unix)]
fn test_monitor_thread_shutdown_kills_child() {
    use std::process::{Command, Stdio};
    use super::invocation::{spawn_pipelined_monitor, InvocationDirs, RustcInvocation};

    // Spawn a long-running process.
    let child = Command::new("sleep")
        .arg("60")
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();

    let dirs = InvocationDirs {
        pipeline_output_dir: PathBuf::from("/tmp"),
        pipeline_root_dir: PathBuf::from("/tmp"),
        original_out_dir: OutputDir::default(),
    };

    let inv = RustcInvocation::new();
    let handle = spawn_pipelined_monitor(&inv, child, dirs, None);

    // Give monitor thread time to start reading stderr.
    std::thread::sleep(std::time::Duration::from_millis(50));

    // Request shutdown.
    inv.request_shutdown();

    // wait_for_metadata should return failure.
    let meta = inv.wait_for_metadata();
    assert!(meta.is_err());

    // Monitor thread should exit promptly (within ~600ms for SIGTERM + SIGKILL).
    handle.join().expect("monitor thread should not panic");
}
```

- [ ] **Step 2: Run test to verify it fails or behaves unexpectedly**

Run: `cd /var/mnt/dev/rules_rust && bazel test //util/process_wrapper:process_wrapper_test --nocache_test_results --test_output=errors --test_filter=test_monitor_thread_shutdown 2>&1 | tail -20`

This test may actually pass already if the monitor thread's shutdown check in the read loop works. If `sleep` produces no stderr output, the `read_line` call blocks forever and never checks `is_shutdown_requested`. We need to handle this case.

- [ ] **Step 3: Fix monitor thread to handle blocking reads during shutdown**

The problem: `read_line` blocks on stderr, so the shutdown check in the loop never fires when the child produces no output. Solution: use a non-blocking approach. On Unix, set the stderr fd to non-blocking mode and poll with a timeout. Cross-platform alternative: use a separate thread for the read and a channel with timeout.

The simplest cross-platform approach: the `request_shutdown` method also kills the child directly (in addition to setting the flag). This unblocks the `read_line` because stderr EOF arrives when the child dies.

Update `request_shutdown` in `worker_invocation.rs` — but we don't have the `Child` in `RustcInvocation`. The monitor thread owns it. Instead, store the child's PID in the state and have `request_shutdown` send SIGTERM via PID (like the existing `PidOnly` pattern):

```rust
pub(super) fn request_shutdown(&self) {
    self.shutdown_requested.store(true, Ordering::SeqCst);
    let (lock, cvar) = &*self.inner;
    let mut state = lock.lock().unwrap();
    // Extract PID before transitioning, so we can send SIGTERM.
    let pid = match &*state {
        InvocationState::Running { pid, .. } => Some(*pid),
        InvocationState::MetadataReady { pid, .. } => Some(*pid),
        _ => None,
    };
    match *state {
        InvocationState::Completed { .. } | InvocationState::Failed { .. } => {}
        _ => {
            *state = InvocationState::ShuttingDown;
            cvar.notify_all();
        }
    }
    drop(state); // Release lock before sending signal.

    if let Some(pid) = pid {
        #[cfg(unix)]
        unsafe {
            libc::kill(pid as i32, libc::SIGTERM);
        }
    }
}
```

This sends SIGTERM to the child, which closes stderr (child terminates), which unblocks `read_line` in the monitor thread. The monitor thread then sees `is_shutdown_requested() == true` and performs the full graceful kill sequence.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /var/mnt/dev/rules_rust && bazel test //util/process_wrapper:process_wrapper_test --nocache_test_results --test_output=errors 2>&1 | tail -20`
Expected: All tests pass. The shutdown test should complete in <1s.

- [ ] **Step 5: Commit**

```bash
git add util/process_wrapper/worker_invocation.rs util/process_wrapper/test/worker.rs
git commit -m "feat: RustcInvocation shutdown sends SIGTERM to unblock monitor"
```

---

### Task 4: `RustcInvocation` — Non-Pipelined Monitor Thread

**Files:**
- Modify: `util/process_wrapper/worker_invocation.rs`
- Test: `util/process_wrapper/test/worker.rs`

Non-pipelined invocations use a subprocess `process_wrapper` (not rustc directly). The monitor thread reads combined stdout+stderr and transitions `Running → Completed/Failed` directly, skipping `MetadataReady`.

- [ ] **Step 1: Write failing test**

```rust
#[test]
fn test_monitor_thread_non_pipelined_completes() {
    use std::process::{Command, Stdio};
    use super::invocation::{spawn_non_pipelined_monitor, InvocationDirs, RustcInvocation};

    let child = Command::new("sh")
        .arg("-c")
        .arg("echo 'hello' >&2; exit 0")
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();

    let inv = RustcInvocation::new();
    let handle = spawn_non_pipelined_monitor(&inv, child);

    let result = inv.wait_for_completion();
    assert!(result.is_ok());
    let completion = result.unwrap();
    assert_eq!(completion.exit_code, 0);

    handle.join().expect("monitor thread should not panic");
}

#[test]
#[cfg(unix)]
fn test_cancel_non_pipelined_kills_child() {
    use std::process::{Command, Stdio};
    use super::invocation::{spawn_non_pipelined_monitor, RustcInvocation};

    let child = Command::new("sleep")
        .arg("60")
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();

    let inv = RustcInvocation::new();
    let handle = spawn_non_pipelined_monitor(&inv, child);

    std::thread::sleep(std::time::Duration::from_millis(50));
    inv.request_shutdown();

    let result = inv.wait_for_completion();
    assert!(result.is_err());

    handle.join().expect("monitor thread should not panic");
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /var/mnt/dev/rules_rust && bazel test //util/process_wrapper:process_wrapper_test --nocache_test_results --test_output=errors --test_filter=test_monitor_thread_non_pipelined 2>&1 | tail -20`
Expected: Compilation error — `spawn_non_pipelined_monitor` doesn't exist.

- [ ] **Step 3: Implement `spawn_non_pipelined_monitor`**

Add to `util/process_wrapper/worker_invocation.rs`:

```rust
/// Spawns a monitor thread for a non-pipelined subprocess invocation.
///
/// Takes ownership of `child`. The monitor thread waits for the child to exit
/// and transitions the invocation to Completed or Failed. No MetadataReady
/// state is used.
pub(super) fn spawn_non_pipelined_monitor(
    invocation: &RustcInvocation,
    mut child: Child,
) -> thread::JoinHandle<()> {
    let monitor = invocation.monitor_handle();
    let pid = child.id();

    // Non-pipelined invocations don't have InvocationDirs — they use a dummy.
    // The completion result's dirs won't be used; output is collected from
    // wait_with_output directly.
    monitor.transition_to_running(pid, InvocationDirs {
        pipeline_output_dir: PathBuf::new(),
        pipeline_root_dir: PathBuf::new(),
        original_out_dir: OutputDir::default(),
    });

    thread::spawn(move || {
        let output = match child.wait_with_output() {
            Ok(output) => output,
            Err(e) => {
                monitor.transition_to_failed(1, format!("failed to wait for child: {e}"));
                return;
            }
        };

        let exit_code = output.status.code().unwrap_or(1);
        let mut combined = String::from_utf8_lossy(&output.stdout).into_owned();
        combined.push_str(&String::from_utf8_lossy(&output.stderr));

        if exit_code == 0 {
            monitor.transition_to_completed(exit_code, combined, InvocationDirs {
                pipeline_output_dir: PathBuf::new(),
                pipeline_root_dir: PathBuf::new(),
                original_out_dir: OutputDir::default(),
            });
        } else {
            monitor.transition_to_failed(exit_code, combined);
        }
    })
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /var/mnt/dev/rules_rust && bazel test //util/process_wrapper:process_wrapper_test --nocache_test_results --test_output=errors 2>&1 | tail -20`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add util/process_wrapper/worker_invocation.rs util/process_wrapper/test/worker.rs
git commit -m "feat: add spawn_non_pipelined_monitor for non-pipelined requests"
```

---

### Task 5: `RequestRegistry`

**Files:**
- Create: `util/process_wrapper/worker_registry.rs`
- Modify: `util/process_wrapper/worker.rs:19-26` (add module declaration)
- Test: `util/process_wrapper/test/worker.rs`

- [ ] **Step 1: Write failing tests**

```rust
use super::registry::RequestRegistry;
use super::invocation::RustcInvocation;

#[test]
fn test_registry_register_metadata_creates_invocation() {
    let mut reg = RequestRegistry::new();
    let (flag, inv) = reg.register_metadata(RequestId(42), PipelineKey("key1".to_string()));
    assert!(!flag.load(Ordering::SeqCst));
    assert!(inv.is_pending());
    assert!(reg.has_invocation("key1"));
}

#[test]
fn test_registry_register_full_finds_existing_invocation() {
    let mut reg = RequestRegistry::new();
    let (_flag1, inv1) = reg.register_metadata(RequestId(42), PipelineKey("key1".to_string()));
    let (_flag2, inv2) = reg.register_full(RequestId(99), PipelineKey("key1".to_string()));
    assert!(inv2.is_some(), "full should find existing invocation");
    // Both references point to the same invocation.
    assert!(Arc::ptr_eq(
        &inv1.inner_arc(),
        &inv2.unwrap().inner_arc(),
    ));
}

#[test]
fn test_registry_register_full_no_invocation_returns_none() {
    let mut reg = RequestRegistry::new();
    let (_flag, inv) = reg.register_full(RequestId(99), PipelineKey("key1".to_string()));
    assert!(inv.is_none(), "full should return None when no metadata registered");
}

#[test]
fn test_registry_cancel_shuts_down_invocation() {
    let mut reg = RequestRegistry::new();
    let (_flag, inv) = reg.register_metadata(RequestId(42), PipelineKey("key1".to_string()));
    reg.cancel(RequestId(42));
    assert!(inv.is_shutting_down_or_terminal());
}

#[test]
fn test_registry_shutdown_all() {
    let mut reg = RequestRegistry::new();
    let (_f1, inv1) = reg.register_metadata(RequestId(42), PipelineKey("key1".to_string()));
    let (_f2, _inv2) = reg.register_metadata(RequestId(43), PipelineKey("key2".to_string()));
    reg.shutdown_all();
    assert!(inv1.is_shutting_down_or_terminal());
}

#[test]
fn test_registry_metadata_cleanup_preserves_different_key_invocation() {
    let mut reg = RequestRegistry::new();
    let (_f1, _inv1) = reg.register_metadata(RequestId(42), PipelineKey("key1".to_string()));
    let (_f2, _inv2) = reg.register_metadata(RequestId(43), PipelineKey("key2".to_string()));
    reg.remove_request(RequestId(42));
    assert!(reg.has_invocation("key1"), "invocation should persist after request removal");
    assert!(reg.has_invocation("key2"));
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /var/mnt/dev/rules_rust && bazel test //util/process_wrapper:process_wrapper_test --nocache_test_results --test_output=errors 2>&1 | tail -20`
Expected: Compilation error — `registry` module doesn't exist.

- [ ] **Step 3: Create `worker_registry.rs`**

Create `util/process_wrapper/worker_registry.rs`:

```rust
use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;

use super::invocation::RustcInvocation;
use super::types::{PipelineKey, RequestId};

pub(crate) type SharedRequestRegistry = Arc<Mutex<RequestRegistry>>;

pub(crate) struct RequestRegistry {
    /// Pipeline key → shared invocation.
    invocations: HashMap<PipelineKey, Arc<RustcInvocation>>,
    /// Monitor thread handles for join during shutdown.
    monitors: Vec<thread::JoinHandle<()>>,
    /// request_id → pipeline key (pipelined requests, for O(1) cancel lookup).
    request_index: HashMap<RequestId, PipelineKey>,
    /// Claim flags for ALL in-flight requests (cancel/completion race prevention).
    claim_flags: HashMap<RequestId, Arc<AtomicBool>>,
}

impl RequestRegistry {
    pub(crate) fn new() -> Self {
        Self {
            invocations: HashMap::new(),
            monitors: Vec::new(),
            request_index: HashMap::new(),
            claim_flags: HashMap::new(),
        }
    }

    /// Register a metadata request. Creates a new invocation if none exists for this key.
    /// Returns (claim_flag, invocation).
    pub(crate) fn register_metadata(
        &mut self,
        request_id: RequestId,
        key: PipelineKey,
    ) -> (Arc<AtomicBool>, Arc<RustcInvocation>) {
        let flag = Arc::new(AtomicBool::new(false));
        self.claim_flags.insert(request_id, Arc::clone(&flag));
        self.request_index.insert(request_id, key.clone());

        let inv = self
            .invocations
            .entry(key)
            .or_insert_with(|| Arc::new(RustcInvocation::new()));
        (flag, Arc::clone(inv))
    }

    /// Register a full request. Returns existing invocation if one exists for this key.
    /// Returns (claim_flag, Option<invocation>).
    pub(crate) fn register_full(
        &mut self,
        request_id: RequestId,
        key: PipelineKey,
    ) -> (Arc<AtomicBool>, Option<Arc<RustcInvocation>>) {
        let flag = Arc::new(AtomicBool::new(false));
        self.claim_flags.insert(request_id, Arc::clone(&flag));
        self.request_index.insert(request_id, key.clone());

        let inv = self.invocations.get(&key).cloned();
        (flag, inv)
    }

    /// Register a non-pipelined request. Returns claim_flag only.
    /// Invocation will be stored later via `store_invocation`.
    pub(crate) fn register_non_pipelined(
        &mut self,
        request_id: RequestId,
    ) -> Arc<AtomicBool> {
        let flag = Arc::new(AtomicBool::new(false));
        self.claim_flags.insert(request_id, Arc::clone(&flag));
        flag
    }

    /// Store an invocation and its monitor thread handle.
    pub(crate) fn store_invocation(
        &mut self,
        key: PipelineKey,
        invocation: Arc<RustcInvocation>,
        monitor: thread::JoinHandle<()>,
    ) {
        self.invocations.insert(key, invocation);
        self.monitors.push(monitor);
    }

    /// Store just a monitor thread handle (for non-pipelined invocations
    /// that don't have a pipeline key).
    pub(crate) fn store_monitor(&mut self, monitor: thread::JoinHandle<()>) {
        self.monitors.push(monitor);
    }

    /// Cancel a request by swapping its claim flag and shutting down its invocation.
    pub(crate) fn cancel(&mut self, request_id: RequestId) {
        // Swap claim flag so the request thread won't send a response.
        if let Some(flag) = self.claim_flags.get(&request_id) {
            flag.store(true, Ordering::SeqCst);
        }

        // Shut down the invocation if this request has one.
        if let Some(key) = self.request_index.get(&request_id) {
            if let Some(inv) = self.invocations.get(key) {
                inv.request_shutdown();
            }
        }

        // Clean up request mappings.
        self.request_index.remove(&request_id);
        self.claim_flags.remove(&request_id);
    }

    /// Shut down all invocations and join all monitor threads.
    pub(crate) fn shutdown_all(&mut self) {
        for inv in self.invocations.values() {
            inv.request_shutdown();
        }
        for handle in self.monitors.drain(..) {
            let _ = handle.join();
        }
        self.invocations.clear();
        self.request_index.clear();
        self.claim_flags.clear();
    }

    /// Remove a request's metadata from the registry (claim_flag, request_index).
    /// Does NOT remove the invocation — it may still be needed by other requests.
    pub(crate) fn remove_request(&mut self, request_id: RequestId) {
        self.request_index.remove(&request_id);
        self.claim_flags.remove(&request_id);
    }

    /// Remove an invocation by key. Safe to call even if other Arc references exist.
    pub(crate) fn remove_invocation(&mut self, key: &PipelineKey) {
        self.invocations.remove(key);
    }

    pub(crate) fn get_claim_flag(&self, request_id: RequestId) -> Option<Arc<AtomicBool>> {
        self.claim_flags.get(&request_id).cloned()
    }

    // --- Test accessors ---

    #[cfg(test)]
    pub(super) fn has_invocation(&self, key: &str) -> bool {
        self.invocations.contains_key(&PipelineKey(key.to_string()))
    }
}
```

- [ ] **Step 4: Add `inner_arc` test accessor to `RustcInvocation`**

In `util/process_wrapper/worker_invocation.rs`, add:

```rust
#[cfg(test)]
pub(super) fn inner_arc(&self) -> &Arc<(Mutex<InvocationState>, Condvar)> {
    &self.inner
}
```

- [ ] **Step 5: Add module declaration in `worker.rs`**

In `util/process_wrapper/worker.rs`, add after the `invocation` module declaration:

```rust
#[path = "worker_registry.rs"]
pub(crate) mod registry;
```

- [ ] **Step 6: Update test imports**

Add to `util/process_wrapper/test/worker.rs` imports:

```rust
use super::registry::RequestRegistry;
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `cd /var/mnt/dev/rules_rust && bazel test //util/process_wrapper:process_wrapper_test --nocache_test_results --test_output=errors 2>&1 | tail -20`
Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add util/process_wrapper/worker_registry.rs util/process_wrapper/worker.rs util/process_wrapper/worker_invocation.rs util/process_wrapper/test/worker.rs
git commit -m "feat: add RequestRegistry as single owner of invocations"
```

---

### Task 6: `BazelRequest` — Thread-Local Request Struct

**Files:**
- Create: `util/process_wrapper/worker_request.rs`
- Modify: `util/process_wrapper/worker.rs` (add module declaration)
- Test: `util/process_wrapper/test/worker.rs`

`BazelRequest` is a thread-local struct that encapsulates request execution. It holds context and methods for executing metadata, full, and non-pipelined requests.

- [ ] **Step 1: Create `worker_request.rs` with `BazelRequest` struct and method stubs**

Create `util/process_wrapper/worker_request.rs`:

```rust
use std::sync::{Arc, Mutex};

use super::invocation::RustcInvocation;
use super::pipeline::{
    create_pipeline_context, prepare_rustc_args, parse_pw_args, build_rustc_env,
    rewrite_out_dir_in_expanded, rewrite_emit_metadata_path, prepare_expanded_rustc_outputs,
    strip_pipelining_flags, append_pipeline_log, maybe_cleanup_pipeline_dir,
    WorkerStateRoots, RequestKind,
};
use super::protocol::WorkRequestContext;
use super::registry::RequestRegistry;
use super::sandbox::{
    copy_all_outputs_to_sandbox, copy_output_to_sandbox, prepare_outputs,
    resolve_request_relative_path, run_request, run_sandboxed_request,
};
use super::types::{OutputDir, PipelineKey, RequestId, SandboxDir};

use crate::ProcessWrapperError;

/// Thread-local request context. Not stored in the registry.
pub(super) struct BazelRequest {
    pub(super) request_id: RequestId,
    pub(super) arguments: Vec<String>,
    pub(super) sandbox_dir: Option<SandboxDir>,
    pub(super) kind: RequestKind,
    pub(super) invocation: Option<Arc<RustcInvocation>>,
}

impl BazelRequest {
    pub(super) fn new(
        context: &WorkRequestContext,
        kind: RequestKind,
        invocation: Option<Arc<RustcInvocation>>,
    ) -> Self {
        Self {
            request_id: context.request_id,
            arguments: context.arguments.clone(),
            sandbox_dir: context.sandbox_dir.clone(),
            kind,
            invocation,
        }
    }
}
```

- [ ] **Step 2: Add module declaration in `worker.rs`**

```rust
#[path = "worker_request.rs"]
pub(crate) mod request;
```

- [ ] **Step 3: Run tests to verify compilation**

Run: `cd /var/mnt/dev/rules_rust && bazel test //util/process_wrapper:process_wrapper_test --nocache_test_results --test_output=errors 2>&1 | tail -20`
Expected: All existing tests still pass.

- [ ] **Step 4: Commit**

```bash
git add util/process_wrapper/worker_request.rs util/process_wrapper/worker.rs
git commit -m "feat: add BazelRequest thread-local request struct"
```

---

### Task 7: Rewire `handle_pipelining_metadata` to Use `RustcInvocation`

**Files:**
- Modify: `util/process_wrapper/worker_request.rs` (add `execute_metadata`)
- Modify: `util/process_wrapper/worker_invocation.rs` (integrate rmeta copy logic)
- Modify: `util/process_wrapper/worker.rs` (update `execute_request` to use `BazelRequest`)
- Test: `util/process_wrapper/test/worker.rs`

This is the core rewiring. The current `handle_pipelining_metadata` function:
1. Parses args, builds env, spawns rustc
2. Reads stderr looking for rmeta
3. Copies rmeta to output
4. Stores `BackgroundRustc` in `PipelineState`
5. Returns diagnostics

The new flow:
1. `BazelRequest::execute_metadata` parses args, builds env, spawns rustc
2. Spawns monitor thread (which reads stderr, detects rmeta, drives transitions)
3. Stores invocation + monitor in registry
4. Calls `invocation.wait_for_metadata()`
5. Copies rmeta to output (based on `MetadataResult`)
6. Returns diagnostics

- [ ] **Step 1: Implement `execute_metadata` on `BazelRequest`**

Add to `util/process_wrapper/worker_request.rs`:

```rust
use std::process::{Command, Stdio};

use super::invocation::{
    spawn_pipelined_monitor, InvocationDirs, RustcInvocation,
};
use super::registry::SharedRequestRegistry;
use super::{lock_or_recover};

use crate::rustc::RustcStderrPolicy;

impl BazelRequest {
    /// Execute a pipelined metadata request.
    ///
    /// Spawns rustc, starts a monitor thread, waits for metadata readiness,
    /// copies rmeta to output, returns diagnostics.
    pub(super) fn execute_metadata(
        &self,
        full_args: Vec<String>,
        state_roots: &WorkerStateRoots,
        registry: &SharedRequestRegistry,
    ) -> (i32, String) {
        let key = match &self.kind {
            RequestKind::Metadata { key } => key.clone(),
            _ => return (1, "execute_metadata called for non-metadata request".to_string()),
        };

        let filtered = strip_pipelining_flags(&full_args);
        let sep = filtered.iter().position(|a| a == "--");
        let (pw_raw, rustc_and_after) = match sep {
            Some(pos) => (&filtered[..pos], &filtered[pos + 1..]),
            None => return (1, "pipelining: no '--' separator in args".to_string()),
        };
        if rustc_and_after.is_empty() {
            return (1, "pipelining: no rustc executable after '--'".to_string());
        }

        let request_context = WorkRequestContext {
            request_id: self.request_id,
            arguments: self.arguments.clone(),
            sandbox_dir: self.sandbox_dir.clone(),
            inputs: Vec::new(), // inputs not needed for metadata handler
            cancel: false,
        };
        let ctx = match create_pipeline_context(state_roots, &key, &request_context) {
            Ok(v) => v,
            Err(e) => return e,
        };

        let mut pw_args = parse_pw_args(pw_raw, &ctx.execroot_dir);
        let (rustc_args, original_out_dir, relocated) =
            match prepare_rustc_args(rustc_and_after, &pw_args, &ctx.execroot_dir) {
                Ok(v) => v,
                Err(e) => return e,
            };
        pw_args.merge_relocated(relocated);
        let pw_args = super::pipeline::resolve_pw_args_for_request(
            pw_args, &request_context, &ctx.execroot_dir,
        );
        let env = match build_rustc_env(
            &pw_args.env_files,
            pw_args.stable_status_file.as_deref(),
            pw_args.volatile_status_file.as_deref(),
            &pw_args.subst,
        ) {
            Ok(env) => env,
            Err(e) => return (1, format!("pipelining: {e}")),
        };

        let rustc_args = rewrite_out_dir_in_expanded(rustc_args, &ctx.outputs_dir);
        let rustc_args = rewrite_emit_metadata_path(rustc_args, &ctx.outputs_dir);
        prepare_expanded_rustc_outputs(&rustc_args);
        append_pipeline_log(
            &ctx.root_dir,
            &format!(
                "metadata start request_id={} key={} sandbox_dir={:?}",
                self.request_id, key, self.sandbox_dir,
            ),
        );

        // Build and spawn rustc command.
        let mut cmd = Command::new(&rustc_args[0]);
        cmd.args(&rustc_args[1..]);
        cmd.env_clear()
            .envs(&env)
            .stdout(Stdio::null())
            .stderr(Stdio::piped())
            .current_dir(&ctx.execroot_dir);

        let child = match cmd.spawn() {
            Ok(c) => c,
            Err(e) => return (1, format!("pipelining: failed to spawn rustc: {e}")),
        };

        let dirs = InvocationDirs {
            pipeline_output_dir: ctx.outputs_dir.clone(),
            pipeline_root_dir: ctx.root_dir.clone(),
            original_out_dir,
        };

        // Get or create the invocation (already created by register_metadata).
        let invocation = self.invocation.as_ref().expect(
            "metadata request must have an invocation from register_metadata",
        );

        let monitor_handle = spawn_pipelined_monitor(
            invocation,
            child,
            dirs,
            pw_args.rustc_output_format.clone(),
        );
        lock_or_recover(registry).store_invocation(
            key.clone(),
            Arc::clone(invocation),
            monitor_handle,
        );

        // Wait for metadata readiness.
        match invocation.wait_for_metadata() {
            Ok(meta) => {
                // Copy rmeta to declared output location.
                // The rmeta file is in ctx.outputs_dir — find it and copy.
                let rmeta_copy_result = self.copy_rmeta_output(
                    &ctx, &key, &meta.diagnostics_before,
                );
                if let Err(e) = rmeta_copy_result {
                    return (1, e);
                }
                append_pipeline_log(&ctx.root_dir, &format!("metadata ready key={}", key));
                if let Some(ref path) = pw_args.output_file {
                    let _ = std::fs::write(path, &meta.diagnostics_before);
                }
                (0, meta.diagnostics_before)
            }
            Err(failure) => {
                maybe_cleanup_pipeline_dir(
                    &ctx.root_dir,
                    true,
                    "metadata rustc failed",
                );
                if let Some(ref path) = pw_args.output_file {
                    let _ = std::fs::write(path, &failure.diagnostics);
                }
                (failure.exit_code, failure.diagnostics)
            }
        }
    }

    /// Copy the .rmeta file from the pipeline output dir to the declared output.
    fn copy_rmeta_output(
        &self,
        ctx: &super::pipeline::PipelineContext,
        _key: &PipelineKey,
        _diagnostics: &str,
    ) -> Result<(), String> {
        // Find the .rmeta file in the pipeline output dir.
        let rmeta_file = std::fs::read_dir(&ctx.outputs_dir)
            .map_err(|e| format!("pipelining: failed to read output dir: {e}"))?
            .filter_map(|entry| entry.ok())
            .find(|entry| {
                entry.path().extension().map_or(false, |ext| ext == "rmeta")
            });

        let rmeta_entry = match rmeta_file {
            Some(e) => e,
            None => return Err("pipelining: no .rmeta file found in output dir".to_string()),
        };

        let rmeta_path = rmeta_entry.path();
        let rmeta_str = rmeta_path.display().to_string();

        match self.sandbox_dir.as_ref() {
            Some(dir) => {
                let original_out_dir = super::pipeline::find_out_dir_in_expanded(
                    &self.arguments,
                ).unwrap_or_default();
                copy_output_to_sandbox(&rmeta_str, dir.as_str(), &original_out_dir, "_pipeline")
                    .map_err(|e| format!("pipelining: rmeta materialization failed: {e}"))?;
            }
            None => {
                // Unsandboxed: copy rmeta to the original out-dir.
                // The monitor thread wrote it to pipeline_output_dir; we need
                // it in the original --out-dir location.
                super::pipeline::copy_rmeta_unsandboxed(
                    &rmeta_path,
                    &ctx.outputs_dir.display().to_string(),
                    &ctx.root_dir,
                )
                .map(|_| ())
                .ok_or_else(|| "pipelining: rmeta copy failed".to_string())?;
            }
        }
        Ok(())
    }
}
```

Note: This is a starting point. The exact rmeta copy logic will need to be reconciled with the current `handle_pipelining_metadata` which uses `extract_rmeta_path` on the stderr line. With the monitor thread, we need the rmeta path communicated back. This may require extending `MetadataResult` to include the rmeta path. Adjust during implementation.

- [ ] **Step 2: Extend `MetadataResult` to include rmeta path**

In `worker_invocation.rs`, update:

```rust
pub(super) struct MetadataResult {
    pub(super) diagnostics_before: String,
    pub(super) rmeta_path: Option<String>,
}
```

And in the monitor thread's rmeta detection, store the path:

```rust
if let Some(rmeta_path_str) = extract_rmeta_path(trimmed) {
    metadata_emitted = true;
    rmeta_path = Some(rmeta_path_str);
    // ... transition to MetadataReady with rmeta_path
}
```

Add `rmeta_path` to `InvocationState::MetadataReady` and propagate to `MetadataResult`.

- [ ] **Step 3: Run tests to verify compilation and existing tests still pass**

Run: `cd /var/mnt/dev/rules_rust && bazel test //util/process_wrapper:process_wrapper_test --nocache_test_results --test_output=errors 2>&1 | tail -20`

- [ ] **Step 4: Commit**

```bash
git add util/process_wrapper/worker_request.rs util/process_wrapper/worker_invocation.rs
git commit -m "feat: BazelRequest.execute_metadata using RustcInvocation"
```

---

### Task 8: Rewire `handle_pipelining_full` to Use `RustcInvocation`

**Files:**
- Modify: `util/process_wrapper/worker_request.rs` (add `execute_full`)

- [ ] **Step 1: Implement `execute_full` on `BazelRequest`**

```rust
impl BazelRequest {
    /// Execute a pipelined full request.
    ///
    /// Waits for the invocation to complete, copies outputs, returns diagnostics.
    /// Falls back to a full subprocess if no invocation exists.
    pub(super) fn execute_full(
        &self,
        full_args: Vec<String>,
        registry: &SharedRequestRegistry,
        self_path: &std::path::Path,
    ) -> (i32, String) {
        let key = match &self.kind {
            RequestKind::Full { key } => key.clone(),
            _ => return (1, "execute_full called for non-full request".to_string()),
        };

        let invocation = match &self.invocation {
            Some(inv) => Arc::clone(inv),
            None => {
                // No invocation exists — fallback to full subprocess.
                return self.execute_fallback(full_args, self_path, &key, registry);
            }
        };

        match invocation.wait_for_completion() {
            Ok(completion) => {
                if completion.exit_code == 0 {
                    // Copy outputs from pipeline dir to sandbox or original out-dir.
                    let copy_result = match self.sandbox_dir.as_ref() {
                        Some(dir) => copy_all_outputs_to_sandbox(
                            &completion.dirs.pipeline_output_dir,
                            dir.as_str(),
                            completion.dirs.original_out_dir.as_str(),
                        )
                        .map(|_| ())
                        .map_err(|e| format!("pipelining: output materialization failed: {e}")),
                        None => super::pipeline::copy_outputs_unsandboxed(
                            &completion.dirs.pipeline_output_dir,
                            completion.dirs.original_out_dir.as_path(),
                        ),
                    };
                    if let Err(e) = copy_result {
                        lock_or_recover(registry).remove_request(self.request_id);
                        return (1, format!("{}\n{e}", completion.diagnostics));
                    }
                }
                super::pipeline::maybe_cleanup_pipeline_dir(
                    &completion.dirs.pipeline_root_dir,
                    completion.exit_code != 0,
                    "full action failed",
                );
                lock_or_recover(registry).remove_request(self.request_id);
                lock_or_recover(registry).remove_invocation(&key);
                (completion.exit_code, completion.diagnostics)
            }
            Err(failure) => {
                // Invocation failed or was shut down — try fallback.
                self.execute_fallback(full_args, self_path, &key, registry)
            }
        }
    }

    fn execute_fallback(
        &self,
        args: Vec<String>,
        self_path: &std::path::Path,
        key: &PipelineKey,
        registry: &SharedRequestRegistry,
    ) -> (i32, String) {
        let filtered = strip_pipelining_flags(&args);
        let result = match self.sandbox_dir.as_ref() {
            Some(dir) => run_sandboxed_request(self_path, filtered, dir.as_str())
                .unwrap_or_else(|e| (1, format!("pipelining fallback error: {e}"))),
            None => {
                prepare_outputs(&filtered);
                run_request(self_path, filtered)
                    .unwrap_or_else(|e| (1, format!("pipelining fallback error: {e}")))
            }
        };
        lock_or_recover(registry).remove_request(self.request_id);
        lock_or_recover(registry).remove_invocation(key);
        result
    }
}
```

- [ ] **Step 2: Run tests to verify compilation**

Run: `cd /var/mnt/dev/rules_rust && bazel test //util/process_wrapper:process_wrapper_test --nocache_test_results --test_output=errors 2>&1 | tail -20`

- [ ] **Step 3: Commit**

```bash
git add util/process_wrapper/worker_request.rs
git commit -m "feat: BazelRequest.execute_full using RustcInvocation"
```

---

### Task 9: Rewire `run_non_pipelined_request` to Use `RustcInvocation`

**Files:**
- Modify: `util/process_wrapper/worker_request.rs` (add `execute_non_pipelined`)
- Modify: `util/process_wrapper/worker_sandbox.rs` (add `spawn_request`)

- [ ] **Step 1: Add `spawn_request` to `worker_sandbox.rs`**

Add to `util/process_wrapper/worker_sandbox.rs`:

```rust
/// Spawns a process_wrapper subprocess and returns the Child handle.
/// The caller is responsible for waiting on the child.
pub(super) fn spawn_request(
    self_path: &std::path::Path,
    arguments: Vec<String>,
    current_dir: Option<&str>,
    context: &str,
) -> Result<std::process::Child, ProcessWrapperError> {
    let mut command = Command::new(self_path);
    command
        .args(&arguments)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    if let Some(dir) = current_dir {
        command.current_dir(dir);
    }
    command
        .spawn()
        .map_err(|e| ProcessWrapperError(format!("failed to spawn {context}: {e}")))
}
```

- [ ] **Step 2: Implement `execute_non_pipelined` on `BazelRequest`**

Add to `util/process_wrapper/worker_request.rs`:

```rust
use super::invocation::spawn_non_pipelined_monitor;
use super::sandbox::spawn_request;

impl BazelRequest {
    pub(super) fn execute_non_pipelined(
        &self,
        full_args: Vec<String>,
        registry: &SharedRequestRegistry,
        self_path: &std::path::Path,
    ) -> (i32, String) {
        let sandbox_dir = self.sandbox_dir.as_ref().map(|d| d.as_str());
        let context = if sandbox_dir.is_some() { "sandboxed subprocess" } else { "subprocess" };

        if let Some(dir) = sandbox_dir {
            let _ = super::sandbox::seed_sandbox_cache_root(std::path::Path::new(dir));
        }

        let child = match spawn_request(self_path, full_args, sandbox_dir, context) {
            Ok(c) => c,
            Err(e) => return (1, format!("worker thread error: {e}")),
        };

        let invocation = Arc::new(RustcInvocation::new());
        let monitor = spawn_non_pipelined_monitor(&invocation, child);
        lock_or_recover(registry).store_monitor(monitor);

        match invocation.wait_for_completion() {
            Ok(completion) => {
                lock_or_recover(registry).remove_request(self.request_id);
                (completion.exit_code, completion.diagnostics)
            }
            Err(failure) => {
                lock_or_recover(registry).remove_request(self.request_id);
                (failure.exit_code, failure.diagnostics)
            }
        }
    }
}
```

- [ ] **Step 3: Run tests to verify compilation**

Run: `cd /var/mnt/dev/rules_rust && bazel test //util/process_wrapper:process_wrapper_test --nocache_test_results --test_output=errors 2>&1 | tail -20`

- [ ] **Step 4: Commit**

```bash
git add util/process_wrapper/worker_request.rs util/process_wrapper/worker_sandbox.rs
git commit -m "feat: BazelRequest.execute_non_pipelined with cancellable subprocess"
```

---

### Task 10: Rewire `worker_main` and `run_request_thread`

**Files:**
- Modify: `util/process_wrapper/worker.rs`

This task rewires the main worker loop and request thread to use `RequestRegistry` and `BazelRequest` instead of `PipelineState` and the ad-hoc cleanup functions.

- [ ] **Step 1: Update imports in `worker.rs`**

Replace the pipeline imports:

```rust
// Old:
use pipeline::{
    handle_pipelining_full, handle_pipelining_metadata, kill_pipelined_request, relocate_pw_flags,
    PipelineState, RequestKind, WorkerStateRoots,
};

// New:
use pipeline::{relocate_pw_flags, RequestKind, WorkerStateRoots};
use registry::{RequestRegistry, SharedRequestRegistry};
use request::BazelRequest;
use invocation::RustcInvocation;
```

- [ ] **Step 2: Update `worker_main` to use `RequestRegistry`**

Replace `PipelineState` with `RequestRegistry`:

```rust
// Old:
let pipeline_state: SharedPipelineState = Arc::new(Mutex::new(PipelineState::new()));

// New:
let registry: SharedRequestRegistry = Arc::new(Mutex::new(RequestRegistry::new()));
```

Update the cancel handler:

```rust
// Old:
if request.cancel {
    let _ = try_handle_cancel_request(&request, &stdout, &pipeline_state);
    continue;
}

// New:
if request.cancel {
    let flag = lock_or_recover(&registry).get_claim_flag(request.request_id);
    if let Some(flag) = flag {
        if !flag.swap(true, Ordering::SeqCst) {
            lock_or_recover(&registry).cancel(request.request_id);
            let response = build_cancel_response(request.request_id);
            let _ = write_worker_response(&stdout, &response);
        }
    }
    continue;
}
```

Update registration to get invocation:

```rust
// Old:
let claim_flag = register_request(&pipeline_state, request.request_id, &request_kind);

// New:
let (claim_flag, invocation) = {
    let mut reg = lock_or_recover(&registry);
    match &request_kind {
        RequestKind::Metadata { key } => {
            let (flag, inv) = reg.register_metadata(request.request_id, key.clone());
            (flag, Some(inv))
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
```

Update thread spawn to pass `BazelRequest`:

```rust
let bazel_request = BazelRequest::new(&request, request_kind.clone(), invocation);
let handle = std::thread::spawn({
    let self_path = self_path.clone();
    let startup_args = startup_args.clone();
    let stdout = Arc::clone(&stdout);
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
            registry,
            state_roots,
            claim_flag,
        )
    }
});
```

Update EOF shutdown:

```rust
// Old:
begin_worker_shutdown("stdin_eof");
for entry in lock_or_recover(&pipeline_state).drain_all() {
    entry.kill();
}
join_in_flight_threads(&in_flight);

// New:
begin_worker_shutdown("stdin_eof");
lock_or_recover(&registry).shutdown_all();
join_in_flight_threads(&in_flight);
```

- [ ] **Step 3: Implement `run_request_thread_v2`**

```rust
fn run_request_thread_v2(
    self_path: std::path::PathBuf,
    startup_args: Vec<String>,
    request: WorkRequestContext,
    bazel_request: BazelRequest,
    stdout: SharedStdout,
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
        lock_or_recover(&registry).remove_request(request.request_id);
        return;
    }

    let (exit_code, output) = match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let full_args = build_full_args(&startup_args, &request.arguments);
        if let Err(e) = prepare_request_outputs(&full_args, &request) {
            return (1, format!("worker thread error: {e}"));
        }

        if claim_flag.load(Ordering::SeqCst) {
            lock_or_recover(&registry).remove_request(request.request_id);
            return (0, String::new());
        }

        match &bazel_request.kind {
            RequestKind::Metadata { .. } => {
                bazel_request.execute_metadata(full_args, &state_roots, &registry)
            }
            RequestKind::Full { .. } => {
                bazel_request.execute_full(full_args, &registry, &self_path)
            }
            RequestKind::NonPipelined => {
                bazel_request.execute_non_pipelined(full_args, &registry, &self_path)
            }
        }
    })) {
        Ok(result) => result,
        Err(_) => {
            // Panic cleanup: shutdown the invocation if we have one.
            if let Some(inv) = &bazel_request.invocation {
                inv.request_shutdown();
            }
            lock_or_recover(&registry).remove_request(request.request_id);
            (1, "internal error: worker thread panicked".to_string())
        }
    };

    lock_or_recover(&registry).remove_request(request.request_id);
    if !claim_flag.swap(true, Ordering::SeqCst) {
        let response = build_response(exit_code, &output, request.request_id);
        let _ = write_worker_response(&stdout, &response);
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /var/mnt/dev/rules_rust && bazel test //util/process_wrapper:process_wrapper_test --nocache_test_results --test_output=errors 2>&1 | tail -20`

- [ ] **Step 5: Commit**

```bash
git add util/process_wrapper/worker.rs
git commit -m "feat: rewire worker_main to use RequestRegistry and BazelRequest"
```

---

### Task 11: Remove Old `PipelineState` Code

**Files:**
- Modify: `util/process_wrapper/worker_pipeline.rs`
- Modify: `util/process_wrapper/worker.rs`
- Modify: `util/process_wrapper/test/worker.rs`

- [ ] **Step 1: Remove from `worker_pipeline.rs`**

Delete the following:
- `PipelinePhase` enum (lines 110-128)
- `CancelledEntry` enum (lines 130-135) and its `kill()` impl (lines 149-174)
- `StoreBackgroundResult` enum (lines 137-141)
- `FullRequestAction` enum (lines 143-147)
- `BackgroundRustc` struct (lines 182-199)
- `PipelineState` struct and all its methods (lines 211-538)
- `handle_pipelining_metadata` function (lines 979-1191)
- `handle_pipelining_full` function (lines 1193-1295)
- `kill_pipelined_request` function (lines 1302-1317)

Keep the following (still used):
- `RequestKind` enum and its methods
- `PipelineContext` struct
- `WorkerStateRoots` struct and impl
- All utility functions: `scan_pipelining_flags`, `strip_pipelining_flags`, `relocate_pw_flags`, `parse_pw_args`, `prepare_rustc_args`, `build_rustc_env`, `expand_rustc_args`, `rewrite_out_dir_in_expanded`, `rewrite_emit_metadata_path`, `prepare_expanded_rustc_outputs`, `create_pipeline_context`, `copy_outputs_unsandboxed`, `copy_rmeta_unsandboxed`, `extract_rmeta_path`, `maybe_cleanup_pipeline_dir`, `append_pipeline_log`, `find_out_dir_in_expanded`, `apply_substs`, `resolve_pw_args_for_request`, `OutputMaterializationStats`

- [ ] **Step 2: Remove old functions from `worker.rs`**

Delete:
- `register_request` function
- `discard_pending_request` function
- `cleanup_after_panic` function
- `try_handle_cancel_request` function
- `run_non_pipelined_request` function
- `execute_request` function
- `run_request_thread` function (replaced by `run_request_thread_v2`)
- Old `SharedPipelineState` type alias

- [ ] **Step 3: Update test file — remove tests for deleted types**

Remove tests that reference `PipelineState`, `BackgroundRustc`, `CancelledEntry`, `FullRequestAction`, `StoreBackgroundResult`. These include:
- `test_pipeline_state_store_and_cancel_metadata_phase`
- `test_pipeline_state_take_for_full_then_cancel`
- `test_pipeline_state_cancel_nonexistent_request`
- `test_pipeline_state_pre_register_and_cancel`
- `test_pipeline_state_cleanup_removes_all_entries`
- `test_pipeline_state_register_claim_non_pipelined`
- `test_pipeline_state_get_claim_flag`
- `test_fallback_claim_rejects_late_metadata_store`
- `test_cleanup_key_fully_removes_late_metadata_mappings`
- `test_pid_only_cancel_respects_child_reaped_flag`
- `test_pipeline_state_take_for_full_empty`

Update imports to remove references to deleted types.

- [ ] **Step 4: Run tests to verify compilation and remaining tests pass**

Run: `cd /var/mnt/dev/rules_rust && bazel test //util/process_wrapper:process_wrapper_test --nocache_test_results --test_output=errors 2>&1 | tail -20`

- [ ] **Step 5: Commit**

```bash
git add util/process_wrapper/worker_pipeline.rs util/process_wrapper/worker.rs util/process_wrapper/test/worker.rs
git commit -m "refactor: remove PipelineState, BackgroundRustc, CancelledEntry"
```

---

### Task 12: Regression Tests

**Files:**
- Modify: `util/process_wrapper/test/worker.rs`

Write the regression tests from AGENT_TODO.md, now using the new types.

- [ ] **Step 1: Write regression test — metadata cleanup preserves invocation**

```rust
#[test]
fn test_metadata_cleanup_preserves_invocation() {
    // Regression: old cleanup(key, request_id) would delete the pipeline entry
    // even when the phase had moved on to FullWaiting.
    // New behavior: remove_request only removes request metadata, not the invocation.
    let mut reg = RequestRegistry::new();
    let key = PipelineKey("key1".to_string());
    let (_meta_flag, _inv) = reg.register_metadata(RequestId(42), key.clone());
    let (_full_flag, full_inv) = reg.register_full(RequestId(99), key.clone());
    assert!(full_inv.is_some(), "full should find the invocation");

    // Metadata request completes — remove its request metadata.
    reg.remove_request(RequestId(42));

    // Invocation must still exist for the full request.
    assert!(reg.has_invocation("key1"));
}

#[test]
fn test_metadata_skip_cleanup_preserves_invocation() {
    // Regression: skipped metadata request (claim flag swapped before execution)
    // would call discard_pending_request which could destroy the pipeline entry.
    let mut reg = RequestRegistry::new();
    let key = PipelineKey("key1".to_string());
    let (_flag, _inv) = reg.register_metadata(RequestId(42), key.clone());

    // Simulate skip: just remove the request.
    reg.remove_request(RequestId(42));

    // Invocation persists — it was created by register_metadata.
    assert!(reg.has_invocation("key1"));
}
```

- [ ] **Step 2: Write regression test — panic cleanup doesn't destroy full request**

```rust
#[test]
fn test_abort_metadata_panic_preserves_full_invocation() {
    // Regression: cleanup_after_panic called cleanup_key_fully for Metadata panics,
    // which would destroy a FullWaiting entry and orphan the rustc child.
    // New behavior: panic calls request_shutdown on the invocation, which the
    // monitor thread handles. The invocation + full request remain valid.
    let mut reg = RequestRegistry::new();
    let key = PipelineKey("key1".to_string());
    let (_meta_flag, inv) = reg.register_metadata(RequestId(42), key.clone());
    let (_full_flag, full_inv) = reg.register_full(RequestId(99), key.clone());
    assert!(full_inv.is_some());

    // Simulate metadata panic: shutdown invocation + remove request.
    inv.request_shutdown();
    reg.remove_request(RequestId(42));

    // Invocation still in registry (for full request to discover it's failed).
    assert!(reg.has_invocation("key1"));
    // Full request's claim flag still active.
    assert!(reg.get_claim_flag(RequestId(99)).is_some());
}
```

- [ ] **Step 3: Write regression test — graceful kill sends SIGTERM first**

```rust
#[test]
#[cfg(unix)]
fn test_graceful_kill_sigterm_then_sigkill() {
    use std::process::Command;
    use std::time::Instant;
    use super::invocation::graceful_kill;

    // Spawn a process that traps SIGTERM and exits cleanly.
    let mut child = Command::new("sh")
        .arg("-c")
        .arg("trap 'exit 0' TERM; sleep 60")
        .spawn()
        .unwrap();

    let start = Instant::now();
    graceful_kill(&mut child);
    let elapsed = start.elapsed();

    // Should have exited quickly via SIGTERM (not waited 500ms for SIGKILL).
    assert!(
        elapsed.as_millis() < 400,
        "graceful_kill should exit quickly when SIGTERM is handled: {}ms",
        elapsed.as_millis()
    );
}
```

- [ ] **Step 4: Run all tests**

Run: `cd /var/mnt/dev/rules_rust && bazel test //util/process_wrapper:process_wrapper_test --nocache_test_results --test_output=errors 2>&1 | tail -20`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add util/process_wrapper/test/worker.rs
git commit -m "test: regression tests for unified request lifecycle"
```

---

### Task 13: End-to-End Pipelined Compilation Tests

**Files:** (no code changes — just run existing integration tests)

- [ ] **Step 1: Run the process_wrapper unit tests**

Run: `cd /var/mnt/dev/rules_rust && bazel test //util/process_wrapper:process_wrapper_test --nocache_test_results --test_output=errors`
Expected: All tests pass.

- [ ] **Step 2: Run the pipelined compilation integration tests**

Run: `cd /var/mnt/dev/rules_rust && bazel test //test/unit/pipelined_compilation/... --nocache_test_results --test_output=errors`
Expected: All pipelined compilation tests pass (these test the full Bazel→worker→rustc pipeline).

- [ ] **Step 3: Run a broader build to check for regressions**

Run: `cd /var/mnt/dev/rules_rust && bazel build //... --config=pipelined 2>&1 | tail -30` (or equivalent build config that enables worker pipelining)
Expected: Clean build.

- [ ] **Step 4: Commit (if any test fixes were needed)**

```bash
git commit -m "fix: address integration test failures from lifecycle refactor"
```

---

## Implementation Notes

### Things to watch for during implementation:

1. **`resolve_pw_args_for_request` visibility**: Currently `fn` (private). The `BazelRequest::execute_metadata` method needs to call it. Change to `pub(super)`.

2. **`copy_rmeta_unsandboxed` return type**: Currently returns `Option<String>` (error message). May need adjustment for the new call pattern.

3. **Windows `#[cfg(windows)]` blocks in `handle_pipelining_metadata`**: The current function has Windows-specific response file and `-Ldependency` consolidation logic. This must be preserved in `BazelRequest::execute_metadata`. Don't skip the `#[cfg(windows)]` blocks during the port.

4. **`extract_rmeta_path` in monitor thread**: The monitor thread needs access to `extract_rmeta_path` to detect the rmeta artifact notification. Ensure it's `pub(super)` in `worker_pipeline.rs`.

5. **`libc` dependency for `SIGTERM`**: The `graceful_kill` function uses `libc::kill` and `libc::SIGTERM`. Check if `libc` is already in `Cargo.toml` for the process_wrapper crate. If not, use the existing FFI `extern "C" { fn kill(...) }` pattern with `SIGTERM = 15`.

6. **Double `remove_request` calls**: In `run_request_thread_v2`, `remove_request` is called both inside the execute methods and after the panic catch. Ensure idempotency (it already is — HashMap::remove on missing key is a no-op).

7. **`RustcStderrPolicy`**: The monitor thread needs this for stderr processing. Currently created in `handle_pipelining_metadata` from `pw_args.rustc_output_format`. Pass it as a parameter to `spawn_pipelined_monitor`.
