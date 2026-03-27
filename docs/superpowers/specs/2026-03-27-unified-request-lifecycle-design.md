# Unified Request Lifecycle for Process Wrapper Worker

**Date:** 2026-03-27
**Status:** Approved
**Scope:** `util/process_wrapper/worker.rs`, `util/process_wrapper/worker_pipeline.rs`, `util/process_wrapper/worker_sandbox.rs`

## Problem

Request lifecycle state is split across three structures (`entries`, `request_index`, `claim_flags`) in `PipelineState`, with multiple ad-hoc cleanup paths that can step on each other:

1. **Stale-phase deletion:** `cleanup(key, request_id)` removes the pipeline entry by key regardless of which request currently owns the phase. If the metadata request cleans up after the full request has moved the key to `FullWaiting` or `FallbackRunning`, it destroys the full request's state.

2. **Non-cancellable non-pipelined requests:** `run_non_pipelined_request` uses `Command::output()`, so the worker never holds the `Child` handle and cannot kill the subprocess on cancel or shutdown.

3. **Panic cleanup destroys wrong state:** `cleanup_after_panic` calls `cleanup_key_fully(key)` for both metadata and full panics. A metadata panic after the key has moved to `FullWaiting` destroys the full request's entry and can orphan the rustc child.

The root cause is conflating "what rustc is doing" with "what Bazel asked for." Fixing individual bugs leaves the split-state architecture intact, making future edge cases inevitable.

## Design

Three components with clear separation of concerns:

### 1. `RustcInvocation` — Rustc Process Lifecycle

A shared state machine (`Arc<Mutex<InvocationState>>` + `Condvar`) tracking a single rustc process through its lifecycle. One invocation per pipeline key for pipelined requests; one per request for non-pipelined.

**State machine:**

```
Pending → Running → MetadataReady → Completed
                  ↘                ↗
                    Failed
                  ↗
ShuttingDown ← (any non-terminal state)
```

```rust
pub(super) struct RustcInvocation {
    state: Arc<(Mutex<InvocationState>, Condvar)>,
}

enum InvocationState {
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

struct InvocationDirs {
    pipeline_output_dir: PathBuf,
    pipeline_root_dir: PathBuf,
    original_out_dir: OutputDir,
}
```

**Key properties:**

- The `Child` handle lives exclusively on the monitor thread's stack. No other thread touches it.
- State transitions are atomic (mutex-protected swap + condvar notify).
- Request threads interact only by waiting on the condvar and reading terminal state.
- `ShuttingDown` is reachable from any non-terminal state. The monitor thread responds by killing the child.
- Non-pipelined requests use the same invocation pattern: `Pending → Running → Completed/Failed`.
  The `MetadataReady` state is simply never entered.

**Methods (called by request threads):**

- `wait_for_metadata() -> Result<MetadataResult, FailureResult>` — blocks until `MetadataReady` or terminal.
- `wait_for_completion() -> Result<CompletionResult, FailureResult>` — blocks until `Completed` or terminal.
- `shutdown()` — transitions to `ShuttingDown`, signals condvar.

**Drop:** If the last `Arc` is dropped while in a non-terminal state, Drop transitions to `ShuttingDown` and signals the condvar. The monitor thread (which holds its own `Arc` clone) sees the transition and cleans up.

### 2. `RequestRegistry` — Central Ownership

Single owner of all invocations and request metadata. Replaces `PipelineState`.

```rust
pub(crate) struct RequestRegistry {
    /// Pipeline key → shared invocation. Sole registry-side ownership.
    invocations: HashMap<PipelineKey, Arc<RustcInvocation>>,
    /// Monitor thread handles for join during shutdown.
    monitors: Vec<JoinHandle<()>>,
    /// request_id → pipeline key (pipelined requests, for O(1) cancel lookup).
    request_index: HashMap<RequestId, PipelineKey>,
    /// Claim flags for ALL in-flight requests (cancel/completion race prevention).
    claim_flags: HashMap<RequestId, Arc<AtomicBool>>,
}
```

**Methods:**

- `register_metadata(request_id, key) -> (Arc<AtomicBool>, Arc<RustcInvocation>)` — creates invocation if not exists, returns claim flag + invocation reference.
- `register_full(request_id, key) -> (Arc<AtomicBool>, Option<Arc<RustcInvocation>>)` — returns existing invocation or None (fallback case).
- `register_non_pipelined(request_id) -> Arc<AtomicBool>` — returns claim flag only. Invocation created later by the request thread and stored via `store_invocation`.
- `store_invocation(key, invocation, monitor)` — stores invocation + monitor handle.
- `cancel(request_id)` — looks up invocation via request_index, calls `shutdown()` on it, swaps claim flag.
- `shutdown_all()` — transitions all invocations to `ShuttingDown`, joins all monitor threads.
- `remove_invocation(key)` — removes registry entry after request completes. The `Arc` may still be held by request threads.
- `remove_request(request_id)` — removes request_index and claim_flags entries.

### 3. `BazelRequest` — Thread-Local Request Context

Lives on the request thread's stack. Holds request context and an optional reference to the invocation. Not stored in the registry.

```rust
struct BazelRequest {
    request_id: RequestId,
    arguments: Vec<String>,
    sandbox_dir: Option<SandboxDir>,
    kind: RequestKind,
    invocation: Option<Arc<RustcInvocation>>,
}
```

**Methods:**

- `execute_metadata(registry) -> (i32, String)`:
  1. Parse args, prepare environment, rewrite out-dir.
  2. Spawn rustc + monitor thread. Monitor thread owns `Child`, drains stderr, drives state transitions.
  3. Register invocation in registry via `store_invocation`.
  4. Call `invocation.wait_for_metadata()`.
  5. On success: copy rmeta to declared output, return diagnostics.
  6. On failure: return error.

- `execute_full(registry) -> (i32, String)`:
  1. Call `invocation.wait_for_completion()`.
  2. On success: copy outputs from `dirs` to sandbox/out-dir, return diagnostics.
  3. On failure/shutdown: return error. If no invocation (None), run fallback (full subprocess).

- `execute_non_pipelined(registry) -> (i32, String)`:
  1. Spawn nested process_wrapper subprocess + monitor thread.
  2. Register invocation in registry.
  3. Call `invocation.wait_for_completion()`.
  4. Return output.

### Monitor Thread

One per rustc invocation. Spawned by the metadata or non-pipelined request handler. Responsibilities:

1. Read rustc stderr line-by-line.
2. On rmeta artifact notification: transition `Running → MetadataReady`, signal condvar. Continue reading.
3. On stderr EOF: call `child.wait()`, transition to `Completed` or `Failed`, signal condvar.
4. On `ShuttingDown` detected: send SIGTERM, wait 500ms, send SIGKILL if still alive, call `child.wait()`, transition to `Failed`.
5. Exit.

The monitor thread holds:
- The `Child` handle (sole owner).
- A clone of `Arc<(Mutex<InvocationState>, Condvar)>`.

For non-pipelined invocations, the monitor thread reads stdout+stderr (combined) and transitions `Running → Completed/Failed` directly (no `MetadataReady` step).

### Graceful Kill Protocol

When transitioning to `ShuttingDown`:

1. Send `SIGTERM` to the child process.
2. Poll `child.try_wait()` in a loop for up to 500ms.
3. If still alive after 500ms, send `SIGKILL`.
4. Call `child.wait()` to reap.

This applies to both pipelined rustc and non-pipelined subprocess kills. The nested process_wrapper subprocess handles SIGTERM via the OS default handler, which terminates the process and allows Drop-based cleanup.

### Cancel Flow

1. Main thread receives cancel request for `request_id`.
2. Registry looks up `request_id → pipeline_key → Arc<RustcInvocation>`.
3. Swaps claim flag (prevents request thread from sending response).
4. Calls `invocation.shutdown()` → transitions to `ShuttingDown`, signals condvar.
5. Monitor thread kills child, transitions to `Failed`.
6. Request thread (if blocked on condvar) wakes, sees terminal state, returns. Claim flag already swapped, so no response sent.
7. Main thread sends cancel response.

**Cancel only shuts down the invocation.** If Bazel cancels the metadata request, the full request will either also be cancelled or will find the invocation in `Failed` state and trigger fallback.

### Shutdown Flow

1. Main thread calls `registry.shutdown_all()`.
2. Each invocation transitions to `ShuttingDown`, condvar signalled.
3. Monitor threads kill children (SIGTERM → SIGKILL), transition to `Failed`, exit.
4. Request threads wake from condvar waits, see terminal state, return error responses.
5. Main thread joins in-flight request threads (bounded wait — now reliable because children are killed promptly).
6. Main thread joins all monitor threads via `registry.monitors`.

### Drop Safety

`RustcInvocation::drop()`: If state is not terminal (`Completed`/`Failed`), transitions to `ShuttingDown` and signals condvar. The monitor thread (holding its own `Arc` clone) sees the transition, kills the child, and exits. This handles the case where the registry removes an invocation and all request threads exit, but the monitor thread is still alive.

Note: Drop cannot join the monitor thread (risk of deadlock). The monitor thread is self-cleaning — it exits after reaching a terminal state. Monitor `JoinHandle`s are stored in the registry for explicit join during `shutdown_all()`.

## What Gets Deleted

- `BackgroundRustc` struct → replaced by `RustcInvocation`
- `PipelineState` → replaced by `RequestRegistry`
- `PipelinePhase` enum → replaced by `InvocationState`
- `CancelledEntry` enum → removed; cancel calls `invocation.shutdown()` directly
- `cleanup()`, `cleanup_key_fully()`, `cleanup_after_panic()`, `discard_pending_request()` → replaced by invocation state transitions + `registry.remove_request()`/`registry.remove_invocation()`
- `kill_pipelined_request()` → replaced by `registry.cancel()`
- `join_in_flight_threads` fake 10-second timeout → reliable join after `shutdown_all()` kills all children

## Testing Strategy

Tests live in `util/process_wrapper/test/worker.rs`.

### Unit tests for `InvocationState` transitions:
- `test_invocation_pending_to_running` — spawn transitions state
- `test_invocation_running_to_metadata_ready` — rmeta signal transitions
- `test_invocation_metadata_ready_to_completed` — rustc exit after rmeta
- `test_invocation_running_to_failed` — rustc exits before rmeta
- `test_invocation_shutdown_from_running` — shutdown kills child
- `test_invocation_shutdown_from_metadata_ready` — shutdown after rmeta

### Unit tests for `RequestRegistry`:
- `test_registry_metadata_creates_invocation` — register_metadata creates entry
- `test_registry_full_finds_invocation` — register_full returns existing invocation
- `test_registry_cancel_shuts_down_invocation` — cancel transitions to ShuttingDown
- `test_registry_shutdown_all` — all invocations transition to ShuttingDown
- `test_registry_remove_invocation_after_complete` — cleanup after success

### Regression tests (from AGENT_TODO.md):
- `test_metadata_cleanup_preserves_full_waiting` — metadata completing does NOT destroy a FullWaiting/Completed invocation (the stale-phase bug)
- `test_metadata_skip_cleanup_preserves_invocation` — skipped metadata request doesn't affect invocation
- `test_abort_metadata_panic_preserves_full` — metadata panic doesn't destroy the full request's invocation state
- `test_cancel_non_pipelined_kills_child` — non-pipelined cancel sends SIGTERM then SIGKILL
- `test_shutdown_kills_non_pipelined_child` — EOF shutdown kills non-pipelined subprocess
- `test_graceful_kill_sigterm_then_sigkill` — SIGTERM first, SIGKILL after 500ms timeout

### Integration test:
- One end-to-end worker test: start worker, send a long-running non-pipelined multiplex request, send cancel, assert prompt exit.
