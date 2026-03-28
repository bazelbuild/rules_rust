# Cleanup Tracker: Unified Request Lifecycle

## Phase 2: Migrate handler internals to RustcInvocation — COMPLETE

- [x] **execute_metadata**: Uses `spawn_pipelined_monitor` + `invocation.wait_for_metadata()`. Done in `ee42958dc`.
- [x] **execute_full**: Uses `invocation.wait_for_completion()` + output copy. Done in `ee42958dc`.
- [x] **execute_non_pipelined**: Uses `spawn_non_pipelined_monitor` + `invocation.wait_for_completion()`. Done in `5df7aa7fa`.

## Phase 3: Remove old code — COMPLETE

All items removed in `20eb1df6d`:
- [x] `PipelineState`, `PipelinePhase`, `BackgroundRustc`, `CancelledEntry`, `StoreBackgroundResult`, `FullRequestAction`
- [x] `handle_pipelining_metadata`, `handle_pipelining_full`, `kill_pipelined_request`
- [x] Old worker.rs functions: `register_request`, `discard_pending_request`, `cleanup_after_panic`, `try_handle_cancel_request`, `run_non_pipelined_request`, `execute_request`, `run_request_thread`
- [x] `SharedPipelineState` type alias
- [x] Old `PipelineState` tests + `make_test_bg` helper
- [x] Unused imports cleaned up in `worker_pipeline.rs` and `worker.rs`

## Phase 4: Structural cleanup — REMAINING

- [ ] Consider renaming `worker_pipeline.rs` to `worker_utils.rs` — it's now just utility functions (arg parsing, env building, output copying, pipeline context)
- [ ] Consider whether `PipelineContext` and `WorkerStateRoots` should move to `worker_request.rs` or a new module
- [ ] Remove blank lines left by deletions in `worker_pipeline.rs` (cosmetic)

## Deferred design decisions — REMAINING

- [ ] `RustcStderrPolicy` in monitor thread: diagnostics processing now happens in the monitor thread instead of the request thread. Verify diagnostics output format matches the old behavior for Bazel consumers.
- [ ] Windows `#[cfg(windows)]` blocks: preserved in `execute_metadata`. Should be tested on Windows.
- [ ] `extract_rmeta_path` timing: monitor thread detects rmeta and transitions state; request thread wakes and copies the file. Small window where rmeta exists in pipeline dir but not in declared output. Verify this doesn't cause issues with Bazel's output checking.
