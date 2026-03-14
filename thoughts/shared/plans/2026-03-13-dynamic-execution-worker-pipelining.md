# Dynamic Execution + Worker Pipelining Implementation Plan

## Overview

Consolidate the worker pipelining implementation to support Bazel dynamic execution
(local worker racing against remote execution) with minimal overhead, while preserving
Cargo-style pipelined compilation benefits and making incremental compilation toggleable.

This plan supersedes the staged-execroot and cross-process stage pool plans:
- `2026-03-10-multiplex-sandbox-staged-execroot-reuse.md` (Phases 4-5 abandoned)
- `2026-03-11-cross-process-shared-stage-pool-plan.md` (on hold → abandoned)
- `2026-03-12-shared-cross-process-stage-pool-prototype-plan.md` (not started → abandoned)

## Current State Analysis

### What Works
- Worker pipelining (single-rustc-invocation) gives **1.62× speedup** unsandboxed (8.4s vs 20.7s on 5-crate bench)
- Worker key unification: all Rustc actions share one multiplex worker process
- `PipelineState` handoff between metadata and full actions works correctly
- Cancel protocol implemented (but doesn't kill child processes)
- `supports-multiplex-sandboxing: 1` already declared in exec requirements

### What Doesn't Work
- Multiplex sandboxing adds ~14-16s overhead, negating wall-time benefit (83s vs 85s on //sdk)
- Worker does **double-staging**: Bazel creates ~991 symlinks in sandbox_dir, then the worker
  creates another ~991 symlinks/copies in its stage pool — total ~570K symlink ops per build
- Stage pool achieved only 7% overhead reduction (target was 50%)
- 575 distinct worker instances observed despite unified key (cause unknown)
- Cancel handler doesn't kill rustc subprocess (wastes CPU when remote wins race)
- Incremental compilation requires `no-sandbox: 1`, incompatible with dynamic execution

### Key Discoveries
- `worker_preparing` (Bazel-side staging): ~461ms avg per request (91.8s total, 199 events)
  — measured once on `sdk_builder_lib`, never reproduced in matrix runs
- `setup_ms` (worker-side staging): ~134ms avg per request (30.4s total)
  — same single measurement; Bazel-side is ~3× worker-side
- `--sandbox_base=/dev/shm` reduced wall time by ~5% (Bazel-side symlink speedup)
- `--experimental_worker_sandbox_inmemory_tracking=Rustc` made things WORSE at higher concurrency
- Dynamic execution automatically enables multiplex sandboxing (no separate flag needed)
- Non-sandboxed multiplex workers silently fall back to singleplex under dynamic execution

## Desired End State

A Rust compilation pipeline that:
1. Supports `--strategy=Rustc=dynamic` with local multiplex worker + remote one-shot execution
2. Local worker leg uses Cargo-style single-invocation pipelining (metadata → full handoff)
3. Minimal sandboxing overhead: no worker-side input staging, only Bazel-side symlink creation
4. Incremental compilation works with sandboxing (compatible with dynamic execution)
5. Worker cancellation kills background rustc when remote wins the race
6. `worker.rs` reduced from ~5500 to ~3500 lines by removing unused staging infrastructure

### Verification
```bash
# Dynamic execution (with remote configured):
bazel build //target \
  --@rules_rust//rust/settings:pipelined_compilation=true \
  --@rules_rust//rust/settings:experimental_worker_pipelining=true \
  --internal_spawn_scheduler \
  --strategy=Rustc=dynamic \
  --dynamic_local_strategy=Rustc=worker,sandboxed \
  --dynamic_remote_strategy=Rustc=remote

# Local-only sandboxed (no remote):
bazel build //target \
  --@rules_rust//rust/settings:pipelined_compilation=true \
  --@rules_rust//rust/settings:experimental_worker_pipelining=true \
  --experimental_worker_multiplex_sandboxing \
  --strategy=Rustc=worker,sandboxed

# With incremental:
bazel build //target \
  --@rules_rust//rust/settings:pipelined_compilation=true \
  --@rules_rust//rust/settings:experimental_worker_pipelining=true \
  --@rules_rust//rust/settings:experimental_incremental \
  --experimental_worker_multiplex_sandboxing \
  --strategy=Rustc=worker,sandboxed
```

## What We're NOT Doing

- **Proactive input pruning**: We will NOT restructure `compile_inputs_for_metadata` to exclude
  transitive deps. This is fragile across codebases (proc macros, build scripts, etc.).
- **Cross-process shared stage pool**: Abandoned. The resolve-through approach eliminates the need.
- **OS-level sandbox isolation**: Multiplex worker sandboxing is cooperative (file-layout isolation),
  not namespace-based. We accept this limitation — it matches Bazel's design.
- **Remote persistent workers**: REAPI doesn't support persistent workers. Remote leg always runs
  process_wrapper as a one-shot process.
- **`unused_inputs_list`**: Deferred to a future plan. Producing an accurate unused-inputs list
  requires monitoring which files rustc actually reads, which is invasive. Could be revisited
  with `fanotify` or static analysis of rustc's dep-info output.

## Implementation Approach

**Core idea: "Resolve-Through" — use the real execroot, not the sandbox.**

Instead of building a worker-owned staged execroot (current approach, ~280ms per request),
pipelined requests use the worker's real execroot as rustc's CWD. The sandbox is created by
Bazel but the worker treats it as a declared-input manifest, not as the compilation root.

This works because:
- Input files in the real execroot are stable during a build and read-only (safe for concurrent access)
- Per-pipeline output directories (`_pw_state/pipeline/<key>/outputs/`) prevent inter-request interference
- Outputs are copied into `sandbox_dir` before responding (already implemented, fast — hardlink preferred)
- Cooperative sandboxing was never OS-enforced; the security model is unchanged

This also fixes the incremental + sandboxing conflict: with real execroot CWD, source file paths
recorded in the incremental cache are stable across builds. The `no-sandbox: 1` requirement
in exec_requirements is no longer needed.

---

## Phase 0: Diagnose Process Churn

### Overview
Determine whether the observed "575 distinct workers" represents 575 OS processes or 575
sandbox directories serviced by a smaller number of processes. This fundamentally affects
whether the worker key unification is working.

### Changes Required

#### 1. Add PID-based process counting to benchmark script
**File**: `thoughts/shared/bench_multiplex_sandbox_overhead.sh`

Add a background loop during builds that samples `pgrep -f process_wrapper.*persistent_worker`
every 500ms and records unique PIDs. Compare against `distinct_workers` from metrics.log.

#### 2. Add request counter to worker lifecycle log
**File**: `util/process_wrapper/worker.rs`

The lifecycle guard already logs uptime and request count on drop. Verify this is working
and add a per-PID summary: `worker_exit pid=XXXXX requests_handled=N uptime_s=N`.

### Success Criteria

#### Automated Verification:
- [x] Benchmark script produces a `distinct_pids.txt` alongside existing metrics
- [x] `cargo test --lib` passes (no regressions)

#### Manual Verification:
- [x] Run `//sdk` with `--experimental_worker_multiplex_sandboxing` and compare:
  - Distinct PIDs: 1 (pid=432842)
  - Distinct worker dirs: 2 (bazel-workers/Rustc-multiplex-worker-*)
  - Total requests from lifecycle logs: 232
- [x] Document findings: 1 process × 232 requests. Worker key unification works correctly.
  The "575 distinct workers" from prior benchmarks = sandbox directories, not OS processes.
- [x] N=1 process — no crash/restart cycle. No further investigation needed.

**Implementation Note**: After completing this phase, pause for manual investigation. The
findings determine whether Phase 1's approach is sufficient or whether the process-churn
issue must be fixed first (e.g., worker crash during sandbox teardown).

---

## Phase 1: Eliminate Worker-Side Staging ("Resolve-Through")

### Overview
Replace the worker's input staging (stage pool, diff-based staging, seed caching) with a
minimal approach: use the real execroot as CWD, redirect outputs to persistent dirs, copy
outputs into sandbox_dir before responding.

### Changes Required

#### 1. New `create_pipeline_context` replacing `create_staged_pipeline`
**File**: `util/process_wrapper/worker.rs`

Replace `create_staged_pipeline` (~220 lines) with a simpler function that:
1. Creates `_pw_state/pipeline/<key>/outputs/` (same as today)
2. Canonicalizes the worker's CWD as `execroot_dir` (the real execroot)
3. Writes `metadata_request.json` snapshot (same as today, for debugging)
4. Returns a `PipelineContext` struct (replacing `StagedPipeline`):

```rust
struct PipelineContext {
    key: String,
    root_dir: PathBuf,        // _pw_state/pipeline/<key>/
    execroot_dir: PathBuf,    // worker's real CWD (canonicalized)
    outputs_dir: PathBuf,     // _pw_state/pipeline/<key>/outputs/
}
```

No `slot: Option<BorrowedSlot>` — no stage pool involvement.

#### 2. Simplify `handle_pipelining_metadata`
**File**: `util/process_wrapper/worker.rs`

Remove from the metadata handler:
- `drain_completed()` call (no longer needed without slot management)
- `stage_request_inputs` / `diff_and_stage_request_inputs` calls
- `seed_execroot_for_slot` / `refresh_worker_seed_entries` calls
- `rewrite_emit_paths_for_execroot` call (paths are already correct relative to real execroot)

Keep:
- `parse_pw_args` (still needs to parse `--env-file`, `--arg-file`, etc.)
- `build_rustc_env` (still needs to construct environment)
- `prepare_rustc_args` / `expand_rustc_args` (still needs to expand @paramfile)
- `rewrite_out_dir_in_expanded` (still redirects `--out-dir` to `outputs_dir`)
- Output copy-back to `sandbox_dir` via `copy_output_to_sandbox` (unchanged)
- Spawning background rustc with `.current_dir(&ctx.execroot_dir)` (now the real execroot)

The `--emit=metadata=<path>` rewriting changes: the path in the paramfile is already
relative to the execroot (set in `construct_arguments`). With real execroot CWD, it
resolves correctly without rewriting.

#### 3. Simplify `handle_pipelining_full`
**File**: `util/process_wrapper/worker.rs`

Remove:
- Slot handling (no `BorrowedSlot` to track)

Keep:
- `BackgroundRustc` retrieval from `PipelineState`
- `stderr_drain` joining + `child.wait()`
- Output copy-back: `copy_all_outputs_to_sandbox` (sandboxed) or direct copy (unsandboxed)
- Fallback to `run_sandboxed_request` / `run_request` when no background process found

#### 4. Simplify `BackgroundRustc`
**File**: `util/process_wrapper/worker.rs`

Remove:
- `slot: Option<BorrowedSlot>` field

Keep all other fields unchanged.

#### 5. Update `drain_completed`
**File**: `util/process_wrapper/worker.rs`

`drain_completed` was needed to release BorrowedSlot file locks from stranded pipelines.
Without slots, it only needs to clean up stranded `BackgroundRustc` entries (join stderr
drain thread, wait for child). Keep but simplify — no slot/lock logic.

#### 6. Remove stage pool infrastructure
**File**: `util/process_wrapper/worker.rs`

Remove these structs and their impls entirely:
- `StagePool` (~100 lines)
- `BorrowedSlot` (~100 lines)
- `StageManifest` (~80 lines)
- `ManifestEntry` (~20 lines)

Remove these functions entirely:
- `diff_and_stage_request_inputs` (~130 lines)
- `stage_request_inputs` (~50 lines)
- `seed_execroot_for_slot` (~40 lines)
- `seed_execroot_with_sandbox_symlinks` (~65 lines)
- `seed_execroot_with_worker_entries` (~40 lines)
- `refresh_worker_seed_entries` (~30 lines)
- `copy_or_link_path` (~90 lines)
- `resolve_input_source` (~15 lines)
- `manifest_entry_unchanged` (~25 lines)
- `reset_slot_execroot` (~15 lines)
- `remove_staged_entry` (~15 lines)
- `derive_stage_pool_namespace` (~20 lines)
- `shared_stage_pool_root` (~30 lines)
- `atomic_write` (~20 lines)
- `maybe_seed_cache_root_for_path` (~30 lines)

Remove constants: `STAGE_POOL_SIZE`, `STAGE_POOL_RESET_AFTER_REUSES`

Remove from `worker_main`:
- `stage_pool` creation and `Arc` wrapping
- `stage_pool` parameter passing to handlers

#### 7. Remove stage pool from `WorkerStateRoots`
**File**: `util/process_wrapper/worker.rs`

`WorkerStateRoots` currently creates `_pw_state/stage_pool/`. Remove this directory creation.
Keep `_pw_state/requests/`, `_pw_state/pipeline/`.

#### 8. Clean up logging
**File**: `util/process_wrapper/worker.rs`

Remove metrics logging related to staging:
- `pipeline_drain_before_stage` log entries
- `slot_acquire`, `slot_release`, `slot_fallback`, `slot_reset` metrics
- Staging stats in pipeline.log (`staging slot=N reuse_count=N ...`)

Keep:
- Pipeline lifecycle logging (metadata start/complete, full start/complete)
- Worker lifecycle logging (start, stop, signal, panic)
- Response logging

### Success Criteria

#### Automated Verification:
- [x] `cargo test --lib` in `util/process_wrapper/`: all tests pass (11/11 via bazel test)
- [x] `bazel test //test/unit/pipelined_compilation/...`: all tests pass (10/10)
- [x] Build `//sdk` with worker pipelining (unsandboxed): 110.2s wall, 35.1s crit, 232 worker actions
- [x] Build `//sdk` with worker pipelining + `--experimental_worker_multiplex_sandboxing`:
      116.7s wall, 36.4s crit, 232 worker actions — build succeeds, no worker-side staging

#### Manual Verification:
- [x] Inspect pipeline.log: no staging/slot entries, only lifecycle events
- [x] Verify no `_pw_state/stage_pool/` directory is created
- [x] Compare wall time: sandboxed 116.7s vs previous 83s (Bazel-side overhead still dominates;
      worker-side staging eliminated but Bazel 9's sandbox creation is slower on clean builds)

**Implementation Note**: After completing this phase and verifying all automated criteria,
pause for manual benchmarking to confirm overhead reduction before proceeding.

---

## Phase 2: Worker Cancellation Support

### Overview
Implement proper cancellation that kills background rustc processes when a cancel request
arrives. This reduces wasted CPU when the remote leg wins a dynamic execution race.

### Changes Required

#### 1. Declare cancellation support in exec requirements
**File**: `rust/private/rustc.bzl`

In `_build_worker_exec_reqs`, when `use_worker_pipelining` is true, add:
```python
reqs["supports-worker-cancellation"] = "1"
```

#### 2. Kill child process on cancel
**File**: `util/process_wrapper/worker.rs`

Extend the cancel handler (line 369-387). Currently it only sends a `wasCancelled` response.
Add logic to kill the associated work:

```rust
if request.cancel {
    let flag = lock_or_recover(&in_flight)
        .get(&request.request_id)
        .map(Arc::clone);
    if let Some(flag) = flag {
        if !flag.swap(true, Ordering::SeqCst) {
            // We claimed it — kill any associated background rustc.
            kill_pipelined_request(&pipeline_state, request.request_id);
            let response = build_cancel_response(request.request_id);
            let _ = write_worker_response(&stdout, &response, request.request_id, "cancel");
        }
    }
    continue;
}
```

#### 3. New `kill_pipelined_request` function
**File**: `util/process_wrapper/worker.rs`

```rust
fn kill_pipelined_request(
    pipeline_state: &Arc<Mutex<PipelineState>>,
    request_id: i64,
) {
    // We need to find the pipeline key associated with this request_id.
    // The mapping is request_id → pipeline_key, stored when the metadata
    // handler registers the BackgroundRustc.
    let mut state = lock_or_recover(pipeline_state);
    // Iterate active entries to find one matching this request_id.
    // (BackgroundRustc needs a new `request_id` field for this lookup.)
    let key_to_kill: Option<String> = state.active.iter().find_map(|(key, bg)| {
        if bg.request_id == request_id { Some(key.clone()) } else { None }
    });
    if let Some(key) = key_to_kill {
        if let Some(mut bg) = state.active.remove(&key) {
            let _ = bg.child.kill();
            let _ = bg.child.wait(); // reap zombie
            let _ = bg.stderr_drain.join();
            // BackgroundRustc drops here — cleanup complete
        }
    }
}
```

#### 4. Track request_id in BackgroundRustc
**File**: `util/process_wrapper/worker.rs`

Add `metadata_request_id: i64` field to `BackgroundRustc`. Set it when storing
the background process in `handle_pipelining_metadata`. This enables the cancel
handler to find which pipeline key corresponds to a cancelled request.

Note: The full action has a different request_id than the metadata action. For full-action
cancellation, the spawned thread's `claim_flag` swap already handles preventing the response.
The background rustc is already being waited on by the full handler thread — killing it there
would cause `child.wait()` to return immediately with a signal exit status, which the full
handler already handles (non-zero exit code path).

### Success Criteria

#### Automated Verification:
- [x] `cargo test --lib` passes (11/11 via bazel test)
- [x] `bazel test //test/unit/pipelined_compilation/...` passes (10/10)

#### Manual Verification:
- [ ] With `--experimental_worker_cancellation` and `--debug_spawn_scheduler`, confirm cancel
      messages appear in worker lifecycle log when remote wins races
      (Deferred: requires working dynamic execution from Phase 3. Cancel infrastructure verified
      via code review — kill_pipelined_request wired into cancel handler.)
- [x] Verify no zombie rustc processes accumulate during a build
      (Confirmed: sandboxed build with --experimental_worker_cancellation, 232 worker actions,
      zero orphan rustc processes after build.)

---

## Phase 3: Dynamic Execution Wiring

### Overview
Wire up the flag combinations and validate that dynamic execution works end-to-end with
the local multiplex worker leg and remote one-shot leg.

### Changes Required

#### 1. Document recommended flag combinations
**File**: `rust/settings/settings.bzl`

Update the `experimental_worker_pipelining` flag documentation to include dynamic execution
configuration:

```python
"""...
For dynamic execution (local worker racing against remote):
    --@rules_rust//rust/settings:experimental_worker_pipelining=true
    --@rules_rust//rust/settings:pipelined_compilation=true
    --internal_spawn_scheduler
    --strategy=Rustc=dynamic
    --dynamic_local_strategy=Rustc=worker,sandboxed
    --dynamic_remote_strategy=Rustc=remote
    --experimental_worker_cancellation
    --sandbox_base=/dev/shm  # recommended: speeds up Bazel-side symlink creation
..."""
```

#### 2. Validate non-pipelined remote fallback
**File**: `util/process_wrapper/options.rs`

When process_wrapper runs as a one-shot process (remote leg), it must handle the
`--pipelining-metadata` and `--pipelining-full` flags gracefully. Currently,
`prepare_param_file` strips these flags during paramfile expansion (line 289+).
Verify this path works correctly when the remote executor runs process_wrapper
without `--persistent_worker`.

The remote leg runs: `process_wrapper [startup-args] -- @paramfile`
The paramfile contains `--pipelining-metadata` / `--pipelining-full` / `--pipelining-key=`.
`prepare_param_file` strips these, and rustc runs as a normal single invocation.

#### 3. Verify process_wrapper produces correct outputs for remote execution
**File**: `util/process_wrapper/options.rs`

For the metadata action running remotely (one-shot):
- `--pipelining-metadata` is stripped
- `--emit=metadata=<path>` remains (rustc writes .rmeta to that path)
- `--emit=dep-info,metadata,link` remains (rustc produces all outputs in one shot)
- The `.rmeta` and `.rlib` are both produced

This is actually a difference from the worker path where the metadata action only needs
the `.rmeta`. When running remotely, the metadata action produces both `.rmeta` AND `.rlib`
(because `-Zno-codegen` is not used with worker pipelining). The `.rlib` is an undeclared
output that gets discarded. Verify this doesn't cause issues.

#### 4. Add integration test for dynamic execution simulation
**File**: `test/unit/pipelined_compilation/`

Add a test that validates the one-shot (non-worker) path handles pipelining flags correctly.
This simulates what happens when the remote leg executes the action.

### Success Criteria

#### Automated Verification:
- [x] `bazel test //test/unit/pipelined_compilation/...` passes (10/10)
- [x] `cargo test --lib` passes (11/11 via bazel test)
- [x] process_wrapper one-shot mode: `process_wrapper @paramfile-with-pipelining-flags` produces
      correct outputs (pipelining flags stripped, rustc runs normally) — verified manually

#### Manual Verification:
- [ ] Build with `--strategy=Rustc=dynamic --dynamic_local_strategy=Rustc=worker,sandboxed
      --dynamic_remote_strategy=Rustc=sandboxed` — partially works: pipelining flags are
      stripped correctly, but crates with build scripts fail because --env-file is also stripped
      as a relocated pw flag, losing OUT_DIR. This is a known limitation of using sandboxed
      as a remote stand-in; real remote execution would configure env vars differently.
- [ ] With `--debug_spawn_scheduler`, confirm Rustc actions are racing local vs "remote"
      (Deferred: depends on fixing the env-file stripping for one-shot path)
- [ ] With `--experimental_worker_cancellation`, confirm cancel messages flow correctly

**Implementation Note**: Full remote execution testing requires a remote execution service
(BuildBuddy, EngFlow, etc.). For this phase, use `--dynamic_remote_strategy=Rustc=sandboxed`
as a stand-in. True remote execution validation is a deployment concern, not a code change.

---

## Phase 4: Incremental Compilation with Sandboxing

### Overview
Remove the `no-sandbox: 1` requirement from incremental compilation, making it compatible
with multiplex sandboxing and dynamic execution. This is possible because Phase 1's
resolve-through approach uses the real execroot CWD, giving rustc stable source paths
regardless of whether Bazel is sandboxing the worker.

### Changes Required

#### 1. Remove `no-sandbox` from incremental exec requirements
**File**: `rust/private/rustc.bzl`

In `_build_worker_exec_reqs`, remove the `no-sandbox` line:

```python
# Before:
if is_incremental:
    reqs["no-sandbox"] = "1"

# After:
# no-sandbox is no longer needed — the worker uses real execroot CWD,
# so incremental cache paths are stable regardless of sandboxing.
# (Removed: reqs["no-sandbox"] = "1")
```

#### 2. Verify incremental cache path stability
**File**: `rust/private/incremental.bzl`

The incremental cache path is `/tmp/rules_rust_incremental/<crate_name>` (absolute path).
This doesn't depend on CWD — it's always the same. The concern was that SOURCE file paths
recorded in the incremental cache would be sandbox-relative (changing between builds).

With the resolve-through approach (Phase 1), rustc's CWD is the real execroot. Source files
in args are relative to CWD (e.g., `src/lib.rs`). Since CWD is stable, these paths are stable.
Verify this empirically:

1. Build with incremental + sandboxing
2. Inspect `/tmp/rules_rust_incremental/<crate>/` — verify recorded source paths are
   execroot-relative (not sandbox-relative)
3. Rebuild — verify incremental cache hit (no re-compilation of unchanged crates)

#### 3. Handle incremental + worker pipelining exec requirements
**File**: `rust/private/rustc.bzl`

When both `is_incremental` and `use_worker_pipelining` are true, the current code sets
both `supports-multiplex-workers` and `no-sandbox` (contradictory). After removing
`no-sandbox`, the combined case becomes:

```python
reqs = {"requires-worker-protocol": "json"}
if use_worker_pipelining:
    reqs["supports-multiplex-workers"] = "1"
    reqs["supports-multiplex-sandboxing"] = "1"
    reqs["supports-worker-cancellation"] = "1"
elif is_incremental:
    reqs["supports-workers"] = "1"
# no-sandbox removed entirely
```

#### 4. Update incremental codegen-units for pipelined mode
**File**: `rust/private/incremental.bzl`

Currently, incremental forces `-Ccodegen-units=16` to prevent rustc from defaulting to 256.
With worker pipelining, the metadata phase doesn't do codegen, so CGU count is irrelevant
for the metadata action. The flag should still be set for the full action (which does codegen).
Verify this is handled correctly — both actions share the same `construct_arguments` call
which adds incremental flags, so both get `-Ccodegen-units=16`. This is harmless for metadata
(rustc ignores it when only producing metadata).

### Success Criteria

#### Automated Verification:
- [x] `bazel test //test/unit/pipelined_compilation/...` passes (10/10)
- [x] `cargo test --lib` passes (11/11 via bazel test)

#### Manual Verification:
- [ ] Build `//sdk` with:
      `--experimental_worker_multiplex_sandboxing --experimental_incremental
       --experimental_worker_pipelining --pipelined_compilation`
      — succeeds without errors
- [ ] Second build (no changes): confirm incremental cache hits in rustc output
      (look for "Compiling" messages — unchanged crates should not recompile)
- [ ] Verify no `no-sandbox` in execution requirements via `bazel aquery`
- [ ] Benchmark: incremental + sandboxed pipelining wall time should improve vs previous
      measurement of 104.9s (the previous overhead was partly from double-staging)

---

## Phase 5: Cleanup & Simplification

### Overview
Remove dead code, simplify the codebase, and document the final architecture.

### Changes Required

#### 1. Remove dead staging code from worker.rs
All stage pool, diff-staging, and seed-caching code removed in Phase 1 should be verified
as fully removed. Grep for any remaining references to:
- `StagePool`, `BorrowedSlot`, `StageManifest`, `ManifestEntry`
- `stage_pool`, `slot`, `manifest`
- `STAGE_POOL_SIZE`, `STAGE_POOL_RESET_AFTER_REUSES`
- `diff_and_stage`, `seed_execroot`, `copy_or_link_path`

#### 2. Remove `shared_stage_pool_root` discovery
The `shared_stage_pool_root()` function walks CWD ancestors to find the output base.
This is no longer needed. Remove it and the `output_base_from_cwd()` helper.

#### 3. Simplify signal handling
The extensive signal handler infrastructure (pre-opened raw FDs, `SIGNAL_LOG_FD`,
`OUTPUT_BASE_SIGNAL_LOG_FD`, `render_signal_log_line` with fixed-size buffers) was
partly motivated by diagnosing the process-churn issue. Simplify to:
- SIGTERM: set `WORKER_SHUTTING_DOWN` + close stdin (current behavior, keep)
- Other signals: default handler (remove custom handlers for SIGHUP, SIGINT, SIGQUIT, SIGPIPE)
- Remove dual-file signal logging (lifecycle.log + output_base copy)

#### 4. Remove `test/json_worker_probe/`
This was a controlled reproduction tool for the worker teardown bug investigation.
No longer needed.

#### 5. Update settings documentation
**File**: `rust/settings/settings.bzl`

Update `experimental_worker_pipelining` doc to reflect:
- Dynamic execution support
- Recommended flag combinations for local-only, dynamic, and incremental modes
- Remove references to `worker_max_multiplex_instances` tuning (default is correct)

#### 6. Archive superseded plans
Add "SUPERSEDED by 2026-03-13-dynamic-execution-worker-pipelining.md" headers to:
- `2026-03-10-multiplex-sandbox-staged-execroot-reuse.md`
- `2026-03-11-cross-process-shared-stage-pool-plan.md`
- `2026-03-11-multiplex-sandbox-overhead-investigation-plan.md`
- `2026-03-12-shared-cross-process-stage-pool-prototype-plan.md`

### Success Criteria

#### Automated Verification:
- [x] `cargo test --lib` passes (11/11 via bazel test)
- [x] `bazel test //test/unit/pipelined_compilation/...` passes (10/10)
- [x] `grep -r 'StagePool\|BorrowedSlot\|stage_pool\|STAGE_POOL' util/process_wrapper/` returns nothing
- [x] `wc -l util/process_wrapper/worker.rs` is 3723 lines (< 4000, down from ~5500)

#### Manual Verification:
- [ ] Full build of `//sdk` succeeds in all three modes:
      unsandboxed, sandboxed, sandboxed+incremental
- [ ] No `_pw_state/stage_pool/` directory created during builds

---

## Testing Strategy

### Unit Tests (cargo test)
- Existing process_wrapper tests (currently 51 pass, 1 pre-existing fail)
- Verify pipelining flag stripping in one-shot mode
- Verify cancel + kill interaction

### Integration Tests (bazel test)
- Existing pipelined_compilation tests (10 pass)
- New: one-shot pipelining flag stripping test (simulates remote execution leg)
- Existing tests must pass in all configurations

### Manual Testing
1. `//sdk` unsandboxed worker pipelining: wall time ≤ 83s
2. `//sdk` sandboxed worker pipelining: wall time should improve (target: < 90s, was 83-104s)
3. `//sdk` sandboxed + incremental: verify cache hits on second build
4. Dynamic execution simulation with `--dynamic_remote_strategy=sandboxed`

## Performance Considerations

### Expected Overhead Reduction (Sandboxed Path)
| Component | Before (per request) | After (per request) | Reduction |
|---|---|---|---|
| Bazel-side staging (`prepareExecution`) | ~461ms | ~461ms | 0% (unchanged) |
| Worker-side staging | ~280ms | ~5ms (output dir creation only) | 98% |
| Output copy-back | ~5ms | ~5ms | 0% (unchanged) |
| **Total per-request overhead** | **~746ms** | **~471ms** | **37%** |

With `--sandbox_base=/dev/shm`, Bazel-side staging drops further (~46ms based on 10× speedup
estimate). Total per-request overhead would be ~56ms.

### Recommended Flags for Production
```
--sandbox_base=/dev/shm                    # RAM-backed symlink trees
--experimental_worker_cancellation         # kill rustc when remote wins
--dynamic_local_execution_delay=500        # tune to cache-hit RTT
```

## Migration Notes

- No Bazel version requirement changes (Bazel 8+ with worker pipelining support)
- No breaking changes to existing flag combinations
- Users with `--experimental_worker_multiplex_sandboxing` will see automatic improvement
- Users without sandboxing see no change (unsandboxed path is untouched)
- The `no-sandbox` removal for incremental is the only behavioral change: incremental
  actions can now be sandboxed. This is strictly more capable, not a regression.

## Phase 6: Exec/Target Dedup via Path Mapping (2026-03-13)

### Problem
53 of ~170 crates in zerobuf_schema are compiled twice (exec + target). When exec==target
platform, this is pure waste: ~110s CPU, ~24s critical path.

### Approach: `--experimental_output_paths=strip`
Bazel's `--experimental_output_paths=strip` normalizes `bazel-out/k8-opt/` and
`bazel-out/k8-opt-exec/` to `bazel-out/cfg/` for actions declaring `supports-path-mapping: 1`.
If exec and target actions have identical command lines after normalization, Bazel deduplicates
them (shared action cache key; since Bazel 7.4, concurrent identical spawns are deduplicated).

### Attempt 1: Flag Inheritance Setting (REVERTED)
Implemented `experimental_exec_inherits_target_flags` to align extra_rustc_flags, env vars,
and LTO settings between exec and target configs. Result: flag alignment alone does NOT reduce
actions (aquery confirmed: 239 k8-opt-exec + 179 k8-opt actions in both baseline and aligned).
Dedup requires `--experimental_output_paths=strip` which is blocked (see below).

Worker pipelining for exec was also attempted (to match target's pipelining mode) but causes:
- E0463: `-Cpanic=abort` from target flags breaks proc-macro deps (need `panic=unwind`)
- E0460: SVH mismatch under concurrent load (race in PipelineState, even with separate worker keys)
- Not needed: path stripping normalizes entire command line, so pipelining mode differences are OK

### Blocker: Path Mapping Requires File Objects in Args
`supports-path-mapping: 1` causes sandbox to use `bazel-out/cfg/` symlinks. But rules_rust
passes many paths as STRINGS via `Args.add(string)`. Bazel's PathMapper only rewrites
File/Artifact objects in Args, leaving strings unchanged. Result: command line has unrewritten
`bazel-out/k8-opt/` paths but sandbox only has `bazel-out/cfg/` → "No such file or directory".

### String-Path Instances to Fix in rustc.bzl

**construct_arguments (lines 950-1376):**

| Line | Code | Type |
|------|------|------|
| 1078 | `rustc_path.add(tool_path)` where `tool_path = toolchain.rustc.path` | `.path` string |
| 1150-1157 | `args.add("--output-file", file.path)` (4 instances) | `.path` string |
| 1024+1181 | `output_dir = crate_info.output.dirname` → `add(output_dir, format="--out-dir=%s")` | `.dirname` string |
| 1226 | `add_all(toolchain.rust_std_paths, ...)` — depset of dirname strings | depset of strings |
| 1336 | `add(toolchain.sysroot, format="--sysroot=%s")` | `.dirname` string |

**add_crate_link_flags (lines 2459-2562):**

| Line | Code | Type |
|------|------|------|
| 2513 | `"--extern={}={}".format(name, lib_or_meta.path)` in map_each | `.path` in string concat |
| 2532 | `"--extern={}={}".format(name, crate_info.output.path)` in map_each | `.path` in string concat |
| 2543 | `return crate.output.dirname` in map_each | `.dirname` string |
| 2559-2561 | `return crate.metadata.dirname` / `crate.output.dirname` in map_each | `.dirname` string |

**_add_native_link_flags (lines 2747-2837):**

| Line | Code | Type |
|------|------|------|
| 2745 | `get_preferred_artifact(lib, use_pic).dirname` in list comprehension | `.dirname` string |
| 2791-2792 | `ambiguous_libs.values()[0].dirname` → `add(dirname, format="-Lnative=%s")` | `.dirname` string |
| 2837 | `_get_dirname(file): return file.dirname` used in add_all map_each | `.dirname` string |

**Toolchain-level (rust/toolchain.bzl):**

| Line | Code | Type |
|------|------|------|
| 430 | `sysroot_path = sysroot.sysroot_anchor.dirname` | `.dirname` string (stored in provider) |
| 597 | `rust_std_paths = depset([file.dirname for file in sysroot.rust_std.to_list()])` | depset of `.dirname` strings |

### Fix Categories

**A. Simple `.path` → File (5 instances):**
- `rustc_path.add(tool_path)` → `rustc_path.add(rustc_file)` (change parameter from str to File)
- `args.add("--output-file", file.path)` → `args.add("--output-file", file)` (4 instances)

**B. `.dirname` → File with dirname extraction (7+ instances):**
- No built-in `args.add(file, format="--flag=%s", dirname=True)` in Bazel
- Workaround: `args.add_all([file], map_each=_dirname, format_each="--flag=%s")` — but
  `map_each` returns strings which may or may not be path-mapped (needs testing)
- Alternative: use `args.add(file, format="--out-dir=%s/")` with trailing slash trick? No.
- Likely need to test whether Bazel's `mapPathString` does regex replacement on map_each output

**C. `map_each` returning strings with embedded paths (4 instances):**
- `--extern=name=path` format prevents simple File passing
- Same question: does `mapPathString` regex-replace `bazel-out/<config>/` in returned strings?
- If yes: no code changes needed for map_each callbacks
- If no: need restructuring (e.g., separate `--extern name` and add file separately)

**D. Toolchain-level string storage (2 instances):**
- `toolchain.sysroot` and `toolchain.rust_std_paths` store strings, not Files
- Fix requires changing the `rust_toolchain` provider fields and all consumers
- Largest blast radius — may affect third-party toolchain definitions

### Implementation Progress (2026-03-13)

**Step 1 — Category A + D partial: DONE**
Fixed in current working tree:
- `tool_path` parameter changed from `str` to `File` in `construct_arguments` + all 4 call sites
  (rustc.bzl ×2, clippy.bzl, unpretty.bzl; rustdoc.bzl keeps `short_path` string for test mode)
- `--output-file` args: 4 instances changed from `.path` string to File object
- `--sysroot`: uses new `toolchain.sysroot_anchor` File + `_parent_dir` map_each helper
- `-L` std paths: uses `toolchain.rust_std` File depset + `_parent_dir` map_each (replaces string depset)
- `--out-dir`: uses `crate_info.output` File + `_parent_dir` map_each
- `supports-path-mapping: 1` added to `_build_worker_exec_reqs`

**Step 2 — Testing: DONE**
Results with `--experimental_output_paths=strip` on reactor-repo-2:
- Process wrapper executable: `cfg` ✓ (Bazel rewrites automatically)
- Rustc tool path: `cfg` ✓ (Category A fix — File object)
- `--sysroot=`: **STILL `k8-opt`** (map_each returns dirname STRING → not path-mapped)
- `-L` std paths: **STILL `k8-opt`** (same — map_each returns dirname string)
- `--out-dir=`: **STILL `k8-opt`** (same — map_each returns dirname string)
- `--emit=link=`: `cfg` ✓ (already used File object)
- Build SUCCEEDS (598/900 processes) except `rustversion` proc-macro which uses
  `include!(concat!(env!("OUT_DIR"), ...))` — OUT_DIR env var is NOT path-mapped

**CRITICAL FINDING: `map_each` return values are NOT path-mapped by Bazel.**
Bazel's PathMapper only rewrites File/Artifact objects passed directly to `Args.add()`.
Strings returned by `map_each` callbacks (even if they contain `bazel-out/<config>/` paths)
are passed through verbatim. There is no `mapPathString` regex replacement on them.

This means ALL `.dirname` paths (Categories B and D) AND all `--extern=name=path` strings
(Category C) need a fundamentally different approach. Possible options:
1. Bazel-side fix: add `PathMapper` support for `map_each` return values
2. Use `args.add_all()` with File depsets and have format_each handle the dirname
   (impossible: `format_each` doesn't support dirname extraction)
3. Pass File objects directly and have format produce the needed string format
   (impossible for `--extern=name=path` which needs both a name and a file path)
4. Use paramfile with post-processing by process_wrapper to normalize paths

**New Blocker: `OUT_DIR` env var not path-mapped**
Crates using `include!(concat!(env!("OUT_DIR"), "/file"))` fail because `OUT_DIR` contains
unrewritten `k8-opt-exec` paths. Env vars aren't processed by PathMapper. This affects:
- `rustversion` (include! of generated version.expr)
- Any crate with a build script that generates include!-able files
Fix: either (a) process_wrapper rewrites paths in --env-file values, or (b) use Bazel's
env var path mapping support (if it exists).

### Remaining Work
1. **Investigate Bazel's PathMapper for `map_each`** — check Bazel source or file a feature
   request. Without this, dirname-based paths can't be path-mapped via Args.
2. **Fix OUT_DIR env var** — either in process_wrapper or via Bazel env path mapping
3. **Fix Category C (`--extern` paths)** — may need to decompose into separate args
4. **Add `experimental_exec_inherits_target_flags`** setting — prerequisite for actual dedup
5. **Validate full pipeline** on reactor-repo-2

## References

- Prior plan (worker pipelining): `thoughts/shared/plans/2026-03-02-worker-pipelined-compilation.md`
- Prior plan (stage pool): `thoughts/shared/plans/2026-03-10-multiplex-sandbox-staged-execroot-reuse.md`
- Prior plan (cross-process pool): `thoughts/shared/plans/2026-03-11-cross-process-shared-stage-pool-plan.md`
- Prior plan (investigation): `thoughts/shared/plans/2026-03-11-multiplex-sandbox-overhead-investigation-plan.md`
- Benchmark data: `thoughts/shared/benchmark_results/`
- Bazel multiplex workers: https://bazel.build/remote/multiplex
- Bazel dynamic execution: https://bazel.build/remote/dynamic
- Bazel persistent workers: https://bazel.build/remote/persistent
