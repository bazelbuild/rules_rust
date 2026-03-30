# Cleanup Tracker: Unified Request Lifecycle

## Phase 2: Migrate handler internals to RustcInvocation — COMPLETE

- [x] **execute_metadata**: `spawn_pipelined_monitor` + `invocation.wait_for_metadata()`.
- [x] **execute_full**: `invocation.wait_for_completion()` + output copy.
- [x] **execute_non_pipelined**: `spawn_non_pipelined_monitor` + `invocation.wait_for_completion()`.

## Phase 3: Remove old code — COMPLETE

- [x] All old types, handlers, and cleanup functions removed.
- [x] Old tests removed, unused imports cleaned.

## Phase 4: Structural cleanup — COMPLETE

- [x] Moved `extract_rmeta_path` from `worker_pipeline.rs` to `worker_invocation.rs` (its sole runtime consumer).
- [x] Removed `tinyjson` dependency from `worker_pipeline.rs`.
- [x] Cleaned up blank lines.
- [x] Kept `worker_pipeline.rs` name — it still handles pipelining-specific concerns (pipeline context, flags, arg rewriting).

## Deferred design decisions

- [ ] `RustcStderrPolicy` in monitor thread: diagnostics processing now happens in the monitor thread instead of the request thread. Verify diagnostics output format matches the old behavior for Bazel consumers.
- [ ] Windows `#[cfg(windows)]` blocks: preserved in `execute_metadata`. Should be tested on Windows.
- [ ] `extract_rmeta_path` timing: monitor thread detects rmeta and transitions state; request thread wakes and copies the file. Small window where rmeta exists in pipeline dir but not in declared output. Verify this doesn't cause issues with Bazel's output checking.
