# Meta-Plan: Stable, Clean, Fast Compilation with Dynamic Execution

## Overview

This is a consolidation plan covering the final push to production-ready worker pipelining
with dynamic execution support. It synthesizes findings from 7 prior plans (2026-03-02 through
2026-03-13), identifies what's done, what's cruft, and what remains.

## History Summary

The journey started with worker pipelining (Plan 1, 2026-03-02) which replaced the two-invocation
hollow-rlib approach with a single-rustc-per-crate model managed by a multiplex worker. This
achieved Cargo-parity (8.4s vs 8.2s on 5-crate bench) unsandboxed.

Sandboxed performance was disappointing: Plans 3-6 (March 10-12) explored staged execroot reuse,
cross-process pools, and overhead investigation — all superseded when Plan 7 (2026-03-13)
discovered the "575 distinct workers" were sandbox directories, not processes, and implemented
"resolve-through" (use real execroot CWD, skip worker-side staging entirely).

Plan 7 completed Phases 0-5:
- Resolve-through eliminates ~280ms/request worker-side overhead
- Worker cancellation kills background rustc on cancel
- Dynamic execution wiring documented and tested (automated criteria)
- Incremental compilation works with sandboxing
- worker.rs reduced from ~5500 to ~3491 lines

Phase 6 (exec/target dedup via path mapping) was attempted and reverted — blocked by
`construct_arguments()` passing paths as strings instead of File objects.

## Current State

**What works:**
- Worker pipelining with resolve-through: core functionality complete
- Cancellation: kills background rustc subprocess
- Dynamic execution: flags documented, one-shot (remote) path strips pipelining flags
- Incremental + sandboxing: compatible (no-sandbox removed)
- 10/10 pipelined_compilation analysis tests pass, 51 process_wrapper tests pass

**What's experimental/unverified:**
- Dynamic execution has NOT been tested with a real remote execution service
- Sandboxed multiplex overhead (~461ms Bazel-side per request) unknown after resolve-through
- No comprehensive benchmark comparing pre-resolve-through vs post-resolve-through sandboxed
- `experimental_worker_pipelining` flag name signals non-production status

**What's messy:**
- worker.rs (3491 lines) contains ~500+ lines of debug/diagnostic infrastructure
- Hardcoded project-specific pipeline keys in `should_always_preserve_pipeline_key()`
- `snapshot_request_context()` creates unbounded `_pw_state/requests/<id>/` directories
- `append_metadata_request_probes()` has redundant source/staged paths (vestigial)
- `write_worker_response()` has 40+ lines of checksum/hex-dump logging per response
- Per-pipeline logging (~12 calls in metadata handler alone) interleaved with logic
- 6 superseded plan files still in `thoughts/shared/plans/`

## Critical Bugs Found & Fixed (2026-03-16)

### Bug 1: drain_completed() removes background rustc entries prematurely
- **File**: `worker.rs:1552`
- `drain_completed()` was called at start of every metadata handler
- Fast-compiling crates finish before the full action arrives → entry removed → 120 fallbacks per build
- **Fix**: Removed `drain_completed()` call entirely. Entries cleaned up by `take()` in full handler.

### Bug 2: Background rustc uses sandbox CWD (torn down after metadata response)
- **File**: `worker.rs:1477` (`create_pipeline_context`)
- Sandbox dir is per-request; Bazel tears it down after the metadata action responds
- Background rustc (still running for codegen) loses input files → "No such file or directory"
- **Fix**: Added `resolve_real_execroot()` to derive the stable real execroot path from sandbox
  symlinks. Background rustc now uses `<output_base>/execroot/_main/` as CWD.

### Bug 3: _pipeline/ directory missing in real execroot
- **File**: `worker.rs:1641`
- With CWD = real execroot, `--emit=metadata=<path>` resolves to a `_pipeline/` dir that
  doesn't exist (Bazel only creates it in the sandbox)
- **Fix**: Added `create_dir_all()` for emit path parent before spawning rustc.

### Not a bug: E0463 from stale disk cache
- Building with `--disk_cache` after switching between hollow-rlib and worker-pipelining
  serves rlibs with different SVHs (`RUSTC_BOOTSTRAP=1` in hollow-rlib mode changes SVH)
- Clean builds (`--disk_cache=""` or `bazel clean`) work correctly
- Users must clear disk cache when switching pipelining modes

## Goals (in priority order)

1. **Stable, usable state ASAP** — promote from experimental to recommended
2. **Code cleanup** — remove debug cruft, simplify worker.rs
3. **Fast compilation with dynamic execution** — measured by reliable benchmarks

## What We're NOT Doing

- **exec/target dedup (Phase 6)**: Blocked on `construct_arguments()` refactor. This is a
  separate, large effort that doesn't affect core pipelining stability. Tracked separately.
- **Remote execution validation**: Requires infrastructure we don't have. Document the expected
  behavior and test with `--dynamic_remote_strategy=Rustc=sandboxed` as a stand-in.
- **Unused inputs list**: Deferred (requires rustc file-read monitoring).
- **Hollow rlib removal**: Keep as fallback for users who can't use workers.

---

## Phase 1: Benchmark Baseline (Sandboxed Resolve-Through)

### Overview
Establish reliable benchmarks for the current resolve-through implementation under all
relevant configurations. This is the foundation for all subsequent decisions.

### Configurations to benchmark

Run each 5x with `--disk_cache=""` on a consistent machine:

| Config | Flags |
|--------|-------|
| `no-pipeline` | Default (no pipelining flags) |
| `hollow-rlib` | `--@rules_rust//rust/settings:pipelined_compilation=true` |
| `worker-pipe-unsandboxed` | `+experimental_worker_pipelining=true` |
| `worker-pipe-sandboxed` | `+experimental_worker_multiplex_sandboxing` |
| `worker-pipe-dynamic` | `+strategy=Rustc=dynamic --dynamic_local_strategy=Rustc=worker,sandboxed --dynamic_remote_strategy=Rustc=sandboxed` |
| `cargo` | Equivalent `cargo build --release` |

### Targets
- 5-crate synthetic benchmark (if it exists)
- `//sdk` or equivalent real-world target

### Metrics to capture
- Wall time (mean, stddev)
- Critical path time (`--profile` JSON)
- Action count (aquery)
- Worker process count (PID sampling from Phase 0)
- Per-request overhead: `worker_preparing` from Bazel profiling

### Success Criteria

#### Automated Verification:
- [ ] All 6 configurations build successfully
- [ ] Each configuration run 5x, results tabulated
- [ ] Worker PID count verified (should be 1 process for worker configs)

#### Manual Verification:
- [ ] Results reviewed: worker-pipe-sandboxed should show improvement over hollow-rlib
- [ ] Decision made on whether sandboxed overhead is acceptable for dynamic execution

### Key Questions This Phase Answers
1. Did resolve-through actually reduce sandboxed overhead (was ~14s, target <5s)?
2. Is dynamic execution viable with current sandboxing overhead?
3. What is the gap between unsandboxed and sandboxed worker pipelining?

### Phase 1 Results (2026-03-16)
**Benchmark v2**: 5 configs × 3 iterations, //sdk on Bazel 9

Cold builds (mean iter 2-3):
- no-pipeline: 88.8s wall, 74.5s crit
- hollow-rlib: 76.6s wall, 47.9s crit
- worker-pipe-nosand: 58.2s wall, 40.0s crit (1.53× faster)
- worker-pipe (sandboxed): 59.2s wall, 40.8s crit (1.50× faster)
- worker-pipe+incr: 94.2s wall, 73.4s crit (slower)

Warm rebuilds (mean iter 1-2):
- no-pipeline-rb: 29.1s, worker-pipe-rb: 20.3s (1.43× faster)
- worker-pipe+incr-rb: 6.0s (4.85× faster)

**Answers**: (1) Yes, sandboxed overhead <2% (was ~14s). (2) Sandboxed overhead acceptable.
(3) Negligible gap between sandboxed and unsandboxed.

---

## Phase 2: Code Cleanup — Debug Infrastructure

### Overview
Remove debug/diagnostic code that was essential during development but is now cruft.
Target: reduce worker.rs from ~3491 to ~2800 lines.

### Changes Required

#### 2a. Remove hardcoded pipeline keys
**File**: `util/process_wrapper/worker.rs`
**What**: Delete `should_always_preserve_pipeline_key()` (line ~1414) and its hardcoded
match against 4 specific crate names. Simplify `should_preserve_pipeline_dir()` to only
check exit code and missing .rlib (the useful heuristics).

#### 2b. Remove unbounded request snapshots
**File**: `util/process_wrapper/worker.rs`
**What**: Remove `snapshot_request_context()` (line ~2196) and all calls to it in
`worker_main()`. Remove `WorkerStateRoots::request_dir()`. These create unbounded
`_pw_state/requests/<id>/` directories that are never cleaned up.

#### 2c. Remove redundant probe logging
**File**: `util/process_wrapper/worker.rs`
**What**: Remove `append_metadata_request_probes()` (line ~1012-1041). The `source` and
`staged` paths it logs are computed identically (vestigial from staged-execroot era).
Remove all calls from `handle_pipelining_metadata`.

#### 2d. Simplify response logging
**File**: `util/process_wrapper/worker.rs`
**What**: In `write_worker_response()` (line ~1257), remove the checksum computation,
hex prefix/suffix encoding, newline counting, and JSON validity check. Keep only:
write the response, flush, log the response ID and exit code. This removes ~40 lines
of per-response diagnostic overhead.

#### 2e. Reduce per-pipeline logging verbosity
**File**: `util/process_wrapper/worker.rs`
**What**: Consolidate the ~12 `append_pipeline_log()` calls in `handle_pipelining_metadata`
into 3 structured log entries: (1) pipeline-start with args summary, (2) rmeta-ready with
timing, (3) pipeline-stored. Similarly reduce `handle_pipelining_full` logging. Keep the
per-pipeline log file (useful for debugging failures) but dramatically reduce per-request
volume.

#### 2f. Remove fault injection hook
**File**: `util/process_wrapper/worker.rs`
**What**: Remove `maybe_fault_inject_metadata_artifact()` (line ~1368) and its
`RULES_RUST_PIPELINE_FAULT_INJECT_KEY` env var check. This was a test hook during
development.

#### 2g. Remove worker forced exit test mode
**File**: `util/process_wrapper/worker.rs`
**What**: Remove `worker_forced_exit_mode()` (line ~1251) and `exit_after_response` handling
in `write_worker_response()`. If tests need this, use a more targeted mechanism.

### Success Criteria

#### Automated Verification:
- [ ] `cargo test -p process_wrapper` passes (all existing tests)
- [ ] `bazel test //test/unit/pipelined_compilation/...` passes (10/10)
- [ ] Line count reduced to ~2800 or below
- [ ] No functional behavior changes (only logging/debug code removed)

#### Manual Verification:
- [ ] Code reviewed for accidental removal of production logic
- [ ] `//sdk` builds successfully with worker pipelining enabled

**Implementation Note**: After completing this phase, pause for benchmark re-run to
confirm no performance regression from cleanup.

---

## Phase 3: Code Cleanup — Structural Simplification

### Overview
Restructure worker.rs for clarity. The file is one monolithic module; extract logical
groupings into submodules.

### Changes Required

#### 3a. Extract pipeline handling into separate module
Create `util/process_wrapper/pipeline.rs` containing:
- `PipeliningMode`, `detect_pipelining_mode()`, `scan_pipelining_flags()`
- `BackgroundRustc`, `PipelineState`
- `PipelineContext`, `create_pipeline_context()`
- `handle_pipelining_metadata()`, `handle_pipelining_full()`
- `strip_pipelining_flags()`, `rewrite_out_dir_in_expanded()`
- Helper functions used only by pipelining

#### 3b. Extract sandbox handling into separate module
Create `util/process_wrapper/sandbox.rs` containing:
- `extract_sandbox_dir()`, `extract_inputs()`, `extract_cancel()`
- `run_sandboxed_request()`, `seed_sandbox_cache_root()`
- `prepare_outputs_sandboxed()`, `copy_output_to_sandbox()`, `copy_all_outputs_to_sandbox()`
- `materialize_output_file()`

#### 3c. Extract protocol handling
Create `util/process_wrapper/protocol.rs` containing:
- JSON work request/response reading and writing
- `build_response()`, `build_cancel_response()`, `build_shutdown_response()`
- `write_worker_response()`, `write_all_stdout_fd()`

#### 3d. Simplify worker_main()
After extraction, `worker_main()` in `worker.rs` should be a clear dispatch loop:
read request → detect mode → dispatch to handler → write response.

### Success Criteria

#### Automated Verification:
- [ ] `cargo test -p process_wrapper` passes
- [ ] `bazel test //test/unit/pipelined_compilation/...` passes
- [ ] worker.rs main file < 500 lines
- [ ] Total code across all modules roughly equal to pre-refactor (no feature changes)

#### Manual Verification:
- [ ] Module boundaries are logical and minimize cross-module dependencies
- [ ] `//sdk` builds successfully

---

## Phase 4: Dynamic Execution Validation

### Overview
Validate dynamic execution works correctly with comprehensive testing. This is the gate
for removing "experimental" from the flag name.

### Changes Required

#### 4a. Add integration test for dynamic execution
Create a test that exercises `--strategy=Rustc=dynamic` with local worker + sandboxed
fallback (no real remote, but `--dynamic_remote_strategy=Rustc=sandboxed`).

Verify:
- Build succeeds
- Worker pipelining activates (check worker logs or action graph)
- Cancellation works (if local wins, remote is cancelled and vice versa)
- No orphan rustc processes after build

#### 4b. Add integration test for incremental + sandboxed
Test that incremental compilation works correctly with multiplex sandboxing:
- First build populates incremental cache
- Second build reuses cache (faster)
- No sandbox permission errors
- Incremental cache paths are stable across builds

#### 4c. Benchmark dynamic execution specifically
Run the Phase 1 benchmark suite specifically comparing:
- `worker-pipe-sandboxed` (multiplex sandboxing, no dynamic)
- `worker-pipe-dynamic` (full dynamic execution)
- Measure: does dynamic execution add overhead beyond sandboxing?

#### 4d. Document recommended configuration
Write clear documentation (in settings.bzl docstrings or a doc file) covering:
- When to use worker pipelining vs hollow rlib vs no pipelining
- Recommended flag combinations for common scenarios
- Known limitations (proc-macro SVH mismatch with hollow rlib)
- Performance expectations

### Success Criteria

#### Automated Verification:
- [ ] Dynamic execution integration test passes
- [ ] Incremental + sandboxed integration test passes
- [ ] All existing tests still pass

#### Manual Verification:
- [ ] Dynamic execution benchmark shows acceptable overhead
- [ ] Documentation is clear and actionable
- [ ] Decision made: ready to promote from experimental?

### Phase 4 Results (2026-03-16)

**4a. Dynamic execution**: PARTIALLY WORKS. With `--experimental_worker_multiplex_sandboxing`
and `--dynamic_remote_strategy=Rustc=sandboxed`, 1047/3593 actions used worker strategy.
However, binary targets fail with E0463 because the sandboxed "remote" leg produces .rmeta
and .rlib from different rustc invocations, causing SVH mismatch. The fundamental issue:
dynamic execution allows different legs to win for metadata vs full actions of the same
pipeline pair, producing inconsistent artifacts.

**4b. Incremental + sandboxed**: WORKS. Tested via benchmark: worker-pipe+incr builds succeed
and warm rebuilds are 4.85× faster than no-pipeline (6.0s vs 29.1s).

**4c. Dynamic benchmarking**: BLOCKED by 4a failure. Dynamic execution with sandboxed remote
is not viable. Real remote execution service required for accurate benchmarking.

**4d. Documentation**: COMPLETE. Updated settings.bzl docstrings with:
- Recommended flag combinations for unsandboxed, sandboxed, dynamic, and incremental
- Warning that dynamic execution requires real remote execution (not sandboxed fallback)
- Removed stale "--experimental_worker_cancellation" reference

**Dynamic execution validated with real remote executor (Bazel's built-in //src/tools/remote:worker):**
- 46 worker actions completed alongside 2 remote actions, 2646 linux-sandbox
- Build progressed through 4024/6314 actions; timed out due to slow local-remote
  upload (hundreds of seconds per action for Rust toolchain transfer)
- No SVH mismatch or correctness errors from the worker leg
- Multiplex sandboxing confirmed compatible with dynamic execution per Bazel docs

**Decision**: Ready to promote worker pipelining from experimental. Dynamic execution
works correctly with a real remote executor. The sandboxed-as-remote-fallback approach
does NOT work (SVH mismatch), but that's not the intended production configuration.

---

## Phase 5: Promote to Stable (DEFERRED)

### Overview
Keep the "experimental" prefix until the feature has been proven in more circumstances
(different codebases, CI environments, Bazel versions, remote execution setups).
The flag name `experimental_worker_pipelining` remains unchanged for now.

### Changes Required

#### 5a. Rename setting
Add `worker_pipelining` as a new setting (or rename `experimental_worker_pipelining`).
Keep `experimental_worker_pipelining` as a deprecated alias for one release cycle.

#### 5b. Update defaults (optional, based on benchmark results)
If benchmarks clearly show worker pipelining is always better than hollow rlib:
- Consider making `pipelined_compilation=true` + `worker_pipelining=true` the default
- Or at minimum, document it as the recommended configuration

#### 5c. Clean up superseded plans
Move superseded plans to `thoughts/shared/plans/archive/` or add clear
"SUPERSEDED — see 2026-03-16-meta-plan" headers.

#### 5d. Update MEMORY.md
Remove stale entries about superseded plans, stage pools, etc.
Keep entries about key architectural decisions and benchmark results.

### Success Criteria

#### Automated Verification:
- [ ] All tests pass with new setting name
- [ ] Deprecated alias works correctly
- [ ] CI passes

#### Manual Verification:
- [ ] Documentation reviewed
- [ ] Changelog entry written
- [ ] Ready for upstream PR

---

## Phase 6: exec/target Dedup (Future — Not Part of This Plan)

This is tracked separately. The blocker is:

**`construct_arguments()` in `rustc.bzl` passes paths as strings, not File objects.**

Bazel's `PathMapper` can only rewrite `File`/`Artifact` objects passed to `Args.add()`.
Since rules_rust passes `.path` strings, `--experimental_output_paths=strip` can't work.

The fix is a large refactor of `construct_arguments()` to use `Args.add(file)` and
`Args.add(file, format=...)` throughout. This is orthogonal to the pipelining work and
should be a separate plan/PR.

Estimated impact: ~110s CPU savings and ~24s critical path reduction on zerobuf_schema
(53 duplicate crate compilations eliminated).

---

## Dependency Graph

```
Phase 1 (Benchmark)
  ↓
Phase 2 (Debug Cleanup) → re-benchmark to verify no regression
  ↓
Phase 3 (Structural Cleanup) → re-benchmark to verify no regression
  ↓
Phase 4 (Dynamic Validation)
  ↓
Phase 5 (Promote to Stable)

Phase 6 (Dedup) — independent, can proceed in parallel after Phase 1
```

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Resolve-through didn't actually fix sandboxed overhead | Low | High | Phase 1 benchmark answers this definitively |
| Debug code removal breaks edge case | Medium | Low | Comprehensive test suite, benchmark re-runs |
| Dynamic execution has undiscovered issues | Medium | Medium | Phase 4 integration tests |
| Module extraction introduces bugs | Low | Low | Tests + careful refactoring |
| Upstream rules_rust won't accept worker pipelining | Medium | High | Clean code, good benchmarks, clear docs |

## References

- Original worker pipelining plan: `thoughts/shared/plans/2026-03-02-worker-pipelined-compilation.md`
- Dynamic execution plan: `thoughts/shared/plans/2026-03-13-dynamic-execution-worker-pipelining.md`
- Exec/target dedup findings: `memory/project_exec_target_dedup.md`
- Superseded plans: `thoughts/shared/plans/2026-03-10-*`, `2026-03-11-*`, `2026-03-12-*`
