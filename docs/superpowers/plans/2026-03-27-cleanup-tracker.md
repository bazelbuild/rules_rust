# Cleanup Tracker: Unified Request Lifecycle

Items to address after the delegation layer is wired and tests pass.

## Phase 2: Migrate handler internals to RustcInvocation

- [x] **execute_metadata**: Uses `spawn_pipelined_monitor` + `invocation.wait_for_metadata()`. Done in `ee42958dc`.
- [x] **execute_full**: Uses `invocation.wait_for_completion()` + output copy. Done in `ee42958dc`.
- [ ] **execute_non_pipelined**: Replace `run_non_pipelined_request` with `spawn_non_pipelined_monitor` + `invocation.wait_for_completion()`. Remove `Command::output()` blocking pattern.

## Phase 3: Remove old code

- [ ] Remove `PipelineState` struct and all methods (`cleanup`, `cleanup_key_fully`, `cancel_by_request_id`, `drain_all`, `store_metadata`, `claim_for_full`, etc.)
- [ ] Remove `PipelinePhase` enum
- [ ] Remove `BackgroundRustc` struct
- [ ] Remove `CancelledEntry` enum and `kill()` impl
- [ ] Remove `StoreBackgroundResult` and `FullRequestAction` enums
- [ ] Remove `handle_pipelining_metadata` function (replaced by `execute_metadata`)
- [ ] Remove `handle_pipelining_full` function (replaced by `execute_full`)
- [ ] Remove `kill_pipelined_request` function (replaced by `registry.cancel()`)
- [ ] Remove old `worker.rs` functions: `register_request`, `discard_pending_request`, `cleanup_after_panic`, `try_handle_cancel_request`, `run_non_pipelined_request`, `execute_request`, `run_request_thread`
- [ ] Remove `SharedPipelineState` type alias
- [ ] Remove old `PipelineState` tests from `test/worker.rs`

## Phase 4: Structural cleanup

- [ ] Make utility functions in `worker_pipeline.rs` `pub(super)` as needed (currently some are called only by the old handlers)
- [ ] Consider renaming `worker_pipeline.rs` to `worker_utils.rs` or similar — once handlers are removed, it's just utility functions
- [ ] Remove unused imports from `worker_pipeline.rs` (`HashMap`, `BufRead`, `BufReader`, `AtomicBool`, etc.)
- [ ] Remove `#[cfg(unix)] extern "C" { fn kill(...) }` from `worker_pipeline.rs` (now in `worker_invocation.rs`)
- [ ] Consider whether `PipelineContext` and `WorkerStateRoots` should move to a more appropriate module

## Deferred design decisions

- [ ] `RustcStderrPolicy` in monitor thread: currently passed as `Option<String>` (format name). Once execute_metadata uses the monitor, verify diagnostics output matches old behavior exactly.
- [ ] Windows `#[cfg(windows)]` blocks: response file writing and `-Ldependency` consolidation from `handle_pipelining_metadata` need to be preserved in execute_metadata.
- [ ] `extract_rmeta_path` in monitor thread vs request thread: currently the monitor thread detects rmeta. The old code detected rmeta in the request thread and copied it immediately. Verify the rmeta copy timing is correct with the new flow.
